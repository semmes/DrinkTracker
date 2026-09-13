#!/usr/bin/env python3
"""Checks that the watch targets are wired so watchOS ships with the iOS app.

Dependency-free, like every other script in this repo. Run it from the repo
root, in the clone or in a worktree:

    python3 scripts/verify-watch-setup.py

Three questions, in order, matching the three the owner asked before any of
this existed:

  1. Do the worktrees behave, and is the sync LaunchAgent free to run?
  2. Is the project file consistent across all targets?
  3. Would the watch app actually ship inside the iOS app?

Before Phase 0 has been done in Xcode, the watch checks report PENDING rather
than failing. That is the expected state of a fresh clone and is not an error.

Exit codes: 0 all pass (pending allowed), 1 at least one FAIL.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBXPROJ = os.path.join(ROOT, "DrinkTracker.xcodeproj", "project.pbxproj")
SCHEMES = os.path.join(ROOT, "DrinkTracker.xcodeproj", "xcshareddata", "xcschemes")

PASS, FAIL, PEND, INFO = "PASS", "FAIL", "PENDING", "  ·"
results = []


def record(status, title, detail=""):
    results.append((status, title, detail))


def git(*args):
    try:
        out = subprocess.run(
            ["git", "-C", ROOT, *args],
            capture_output=True, text=True, timeout=30,
        )
        return out.stdout.strip() if out.returncode == 0 else None
    except Exception:
        return None


# ---------------------------------------------------------------- pbxproj ---

def build_configs(text):
    """Every XCBuildConfiguration's buildSettings, as dicts.

    Deliberately does not chase buildConfigurationList references. Grouping by
    PRODUCT_BUNDLE_IDENTIFIER identifies a target well enough for every check
    here, and ref-chasing a pbxproj by regex is where this kind of script
    usually starts lying.
    """
    configs = []
    for block in re.findall(r"buildSettings = \{(.*?)\n\t*\};", text, re.S):
        settings = {}
        for key, value in re.findall(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?);\s*$',
                                    block, re.M):
            settings[key] = value.strip().strip('"')
        if settings:
            configs.append(settings)
    return configs


def native_targets(text):
    """Target name -> the raw text of its PBXNativeTarget block."""
    targets = {}
    for block in re.findall(r"isa = PBXNativeTarget;(.*?)\n\t\t\};", text, re.S):
        name = re.search(r"^\s*name = (.+?);", block, re.M)
        if name:
            targets[name.group(1).strip().strip('"')] = block
    return targets


def check_project():
    if not os.path.exists(PBXPROJ):
        record(FAIL, "project.pbxproj found", PBXPROJ)
        return
    text = open(PBXPROJ, encoding="utf-8").read()
    configs = build_configs(text)
    targets = native_targets(text)

    record(INFO, "Targets in the project", ", ".join(sorted(targets)) or "none")

    # --- versions agree across every target -------------------------------
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        values = {c[key] for c in configs if key in c}
        if not values:
            record(FAIL, f"{key} set", "not found in any build configuration")
        elif len(values) == 1:
            record(PASS, f"{key} agrees across targets", values.pop())
        else:
            record(FAIL, f"{key} agrees across targets",
                   "differs: " + ", ".join(sorted(values))
                   + " — App Store validation rejects an embedded target whose "
                     "version disagrees with its host")

    # --- bundle identifiers nest correctly --------------------------------
    ids = {c["PRODUCT_BUNDLE_IDENTIFIER"] for c in configs
           if "PRODUCT_BUNDLE_IDENTIFIER" in c}
    ids = {i for i in ids if "Tests" not in i}
    app = next((i for i in ids if i.endswith(".DrinkTracker")), None)
    if not app:
        record(FAIL, "App bundle identifier found", "expected one ending .DrinkTracker")
        return
    record(PASS, "App bundle identifier", app)

    expected = {
        "iOS widget": app + ".Widget",
        "watch app": app + ".watchkitapp",
        "watch widget": app + ".watchkitapp.Widget",
    }
    watch_present = expected["watch app"] in ids
    for label, wanted in expected.items():
        if wanted in ids:
            record(PASS, f"{label} bundle id nests correctly", wanted)
        elif label == "iOS widget":
            record(FAIL, f"{label} bundle id nests correctly", f"expected {wanted}")
        else:
            record(PEND, f"{label} bundle id", f"expected {wanted} once Phase 0 is done")

    # --- literals that should be derived ----------------------------------
    literal = [i for i in ids if not i.startswith("$(BUNDLE_ID_PREFIX)")]
    if literal:
        record(FAIL, "Bundle ids derive from BUNDLE_ID_PREFIX",
               "hardcoded: " + ", ".join(sorted(literal))
               + " — invariant 4")
    else:
        record(PASS, "Bundle ids derive from BUNDLE_ID_PREFIX", "no literals")

    if not watch_present:
        record(PEND, "Watch target checks", "Phase 0 has not been done yet; "
                                            "everything below this line is skipped")
        return

    # --- watch-only settings ----------------------------------------------
    watch_cfgs = [c for c in configs
                  if c.get("PRODUCT_BUNDLE_IDENTIFIER") == expected["watch app"]]
    for key, want in (("SDKROOT", "watchos"),
                      ("TARGETED_DEVICE_FAMILY", "4"),
                      ("WATCHOS_DEPLOYMENT_TARGET", "26.0")):
        values = {c.get(key) for c in watch_cfgs}
        if values == {want}:
            record(PASS, f"Watch app {key}", want)
        else:
            record(FAIL, f"Watch app {key}",
                   f"expected {want}, found {sorted(v for v in values if v)}")

    companion = {c.get("INFOPLIST_KEY_WKCompanionAppBundleIdentifier")
                 for c in watch_cfgs}
    if companion == {app}:
        record(PASS, "WKCompanionAppBundleIdentifier points at the iOS app", app)
    else:
        record(FAIL, "WKCompanionAppBundleIdentifier points at the iOS app",
               f"found {sorted(c for c in companion if c)} — a standalone-capable "
               "watch app is decision 6's opposite")

    # --- the embed phase, which is what makes it one submission -----------
    if re.search(r"Embed Watch Content", text):
        record(PASS, "iOS app embeds the watch app", "Embed Watch Content phase present")
    elif re.search(r"dstSubfolderSpec = 16;", text):
        record(PASS, "iOS app embeds the watch app", "copy phase to $(CONTENTS_FOLDER_PATH)/Watch")
    else:
        record(FAIL, "iOS app embeds the watch app",
               "no Embed Watch Content phase — the watch app would not ship "
               "inside the iOS app")

    # --- ComponentsKit must not reach the watch ---------------------------
    for name, block in targets.items():
        if "Watch" not in name:
            continue
        if "ComponentsKit" in block:
            record(FAIL, f"{name} does not link ComponentsKit",
                   "the watch target should depend on DrinkTrackerCore only")
        else:
            record(PASS, f"{name} does not link ComponentsKit", "")

    # --- Shared/ reaches every target that needs it -----------------------
    shared = ["AppGroup.swift", "AppSettings.swift", "DrinkEntry.swift",
              "DrinkRepository.swift", "LogDrinkIntent.swift", "SchemaVersions.swift"]
    watch_target_count = sum(1 for n in targets if "Watch" in n)
    for filename in shared:
        ref = re.search(r"([0-9A-F]{24}) /\* " + re.escape(filename) + r" \*/ = \{isa = PBXFileReference",
                        text)
        if not ref:
            record(FAIL, f"Shared/{filename} referenced", "no PBXFileReference")
            continue
        uses = len(re.findall(r"/\* " + re.escape(filename) + r" in Sources \*/", text))
        # app + iOS widget + test bundle already, plus the watch targets.
        if uses >= 3 + watch_target_count:
            record(PASS, f"Shared/{filename} compiled into {uses} targets", "")
        else:
            record(FAIL, f"Shared/{filename} compiled into {uses} targets",
                   f"expected at least {3 + watch_target_count} — add it to the "
                   "watch targets' Sources phase")


# ---------------------------------------------------------------- files -----

def check_files():
    pkg = os.path.join(ROOT, "DrinkTrackerCore", "Package.swift")
    if os.path.exists(pkg):
        body = open(pkg, encoding="utf-8").read()
        if ".watchOS(" in body:
            record(PASS, "DrinkTrackerCore declares a watchOS platform", "")
        else:
            record(PEND, "DrinkTrackerCore declares a watchOS platform", "Phase 1")

    if os.path.isdir(SCHEMES):
        schemes = sorted(f[:-9] for f in os.listdir(SCHEMES) if f.endswith(".xcscheme"))
        record(INFO, "Shared schemes", ", ".join(schemes))
        if any("Watch" in s for s in schemes):
            record(PASS, "A watch scheme is shared", "CI can see it")
        else:
            record(PEND, "A watch scheme is shared",
                   "tick Shared on the new scheme, or CI cannot build it")

    for target in ("DrinkTrackerWatch", "DrinkTrackerWatchWidget"):
        path = os.path.join(ROOT, target, target + ".entitlements")
        if not os.path.exists(path):
            record(PEND, f"{target} entitlements", "copy from docs/watch-scaffold/")
            continue
        body = open(path, encoding="utf-8").read()
        missing = [k for k in ("com.apple.security.application-groups",
                               "com.apple.developer.icloud-container-identifiers",
                               "aps-environment") if k not in body]
        if missing:
            record(FAIL, f"{target} entitlements complete", "missing: " + ", ".join(missing))
        elif "$(BUNDLE_ID_PREFIX)" not in body:
            record(FAIL, f"{target} entitlements derive from BUNDLE_ID_PREFIX",
                   "hardcoded identifier — invariant 4")
        elif "healthkit" in body.lower():
            record(FAIL, f"{target} has no HealthKit entitlement",
                   "the watch writes no Health data by design")
        else:
            record(PASS, f"{target} entitlements", "group + iCloud + aps, all derived")

    ci = os.path.join(ROOT, ".github", "workflows", "ci.yml")
    if os.path.exists(ci):
        body = open(ci, encoding="utf-8").read()
        if "watchOS Simulator" in body:
            record(PASS, "CI builds the watch", "")
        else:
            record(PEND, "CI builds the watch", "add the build-watch job, Phase 1")

    claude_md = os.path.join(ROOT, "DrinkTrackerWatch", "CLAUDE.md")
    if os.path.exists(claude_md):
        record(PASS, "Watch target has a scoped CLAUDE.md", "")
    elif os.path.isdir(os.path.join(ROOT, "DrinkTrackerWatch")):
        record(FAIL, "Watch target has a scoped CLAUDE.md",
               "copy docs/watch-scaffold/DrinkTrackerWatch-CLAUDE.md")


# ------------------------------------------------------------- worktrees ----

def check_git():
    inside = git("rev-parse", "--is-inside-work-tree")
    if inside != "true":
        record(FAIL, "Inside a git work tree", "")
        return

    common = git("rev-parse", "--git-common-dir") or ""
    gitdir = git("rev-parse", "--git-dir") or ""
    is_worktree = os.path.abspath(common) != os.path.abspath(gitdir)
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    record(INFO, "This checkout",
           ("linked worktree" if is_worktree else "main clone") + f", on '{branch}'")

    listing = git("worktree", "list") or ""
    for line in listing.splitlines():
        record(INFO, "worktree", line)
    stale = []
    for line in listing.splitlines():
        if not line.strip():
            continue
        path = line.split()[0]
        if "prunable" in line:
            stale.append(f"{path} (prunable)")
        elif "locked" in line:
            stale.append(f"{path} (locked)")
        elif not os.path.isdir(path):
            stale.append(f"{path} (missing)")
    if stale:
        record(FAIL, "No stale worktrees",
               "; ".join(stale) + " — a locked or missing entry keeps its branch "
               "checked out and blocks reuse. Fix: git worktree remove -f -f <path> "
               "then git worktree prune")
    else:
        record(PASS, "No stale worktrees", "")

    # A worktree inside the repo confuses Xcode's indexer and git status alike.
    for line in listing.splitlines():
        path = line.split()[0]
        if is_worktree or not path:
            continue
        if path != ROOT and os.path.abspath(path).startswith(os.path.abspath(ROOT) + os.sep):
            record(FAIL, "Worktrees live outside the repo", path)

    if os.path.exists(os.path.join(common, "..", ".gitmodules")) or \
       os.path.exists(os.path.join(ROOT, ".gitmodules")):
        contract = os.path.join(ROOT, "contract")
        if os.path.isdir(contract) and os.listdir(contract):
            record(PASS, "Submodules initialised in this checkout", "")
        else:
            record(FAIL, "Submodules initialised in this checkout",
                   "run: git submodule update --init --recursive "
                   "(a new worktree does not inherit them)")

    # --- what the sync LaunchAgent will do next ---------------------------
    dirty = git("status", "--porcelain") or ""
    if is_worktree:
        record(INFO, "Sync agent", "watches the main clone, not this worktree")
    elif branch != "main":
        record(PEND, "Sync agent is free to run",
               f"main clone is on '{branch}', so sync-main.sh will leave it alone")
    elif dirty:
        n = len(dirty.splitlines())
        record(FAIL, "Sync agent is free to run",
               f"{n} uncommitted change(s) in the main clone — sync-main.sh is "
               "paused until they are committed, moved to a branch, or stashed")
        for line in dirty.splitlines()[:10]:
            record(INFO, "uncommitted", line)
    else:
        record(PASS, "Sync agent is free to run", "main clone clean and on main")


# ------------------------------------------------------------------ main ----

def main():
    check_git()
    check_project()
    check_files()

    width = max(len(t) for _, t, _ in results) + 2
    print()
    for status, title, detail in results:
        if status == INFO:
            print(f"    {title}: {detail}" if detail else f"    {title}")
            continue
        print(f"[{status:>7}] {title.ljust(width)} {detail}".rstrip())
    failures = sum(1 for s, _, _ in results if s == FAIL)
    pending = sum(1 for s, _, _ in results if s == PEND)
    print()
    print(f"{failures} failing, {pending} pending.")
    print()
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
