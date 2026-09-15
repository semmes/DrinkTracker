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

Before Phase 0 has been done, the watch checks report PENDING rather than
failing. That is the expected state of a fresh clone and is not an error.
After Phase 0 (2026-09-14) the only PENDING items are Phase 1's.

This reads the project file as a graph of objects — targets, their build
phases, the build files in those phases, the file references behind them, and
each target's own configurations — rather than counting strings. The earlier
version counted "in Sources" occurrences against a threshold, and the pbxproj
writes that comment twice per membership, so the check could not fail for five
of the six shared files and only bit the sixth after a second watch target
existed. Membership is now read from the phase that carries it.

Exit codes: 0 all pass (pending allowed), 1 at least one FAIL.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBXPROJ = os.path.join(ROOT, "DrinkTracker.xcodeproj", "project.pbxproj")
SCHEMES = os.path.join(ROOT, "DrinkTracker.xcodeproj", "xcshareddata", "xcschemes")
SYNC_AGENT_PLIST = os.path.expanduser(
    "~/Library/LaunchAgents/com.shawnsemmes.tallyist.sync.plist")

SHARED_FILES = ["AppGroup.swift", "AppSettings.swift", "DrinkEntry.swift",
                "DrinkRepository.swift", "LogDrinkIntent.swift", "SchemaVersions.swift"]

# The rest of Shared/, and which targets each file belongs to. These are not
# "all four" like the six above: a file added to Shared/ for one surface and
# silently left off another is a compile error at best and a drifted rule at
# worst (the legend's words, the session's dots and the ramp are each read by
# more than one target). Every .swift in Shared/ must appear here or above,
# so a new shared file cannot be forgotten.
SHARED_EXTRAS = {
    "IntensityPalette.swift": ("DrinkTracker", "DrinkTrackerWidgetExtension",
                               "DrinkTrackerWatch", "DrinkTrackerWatchWidget"),
    "CloudKitStatusProbe.swift": ("DrinkTracker", "DrinkTrackerWatch"),
    "DayIntensity+Legend.swift": ("DrinkTracker", "DrinkTrackerWatch"),
    "SessionDots.swift": ("DrinkTrackerWatch", "DrinkTrackerWatchWidget"),
}

# Settings that change what one source file *means* when it is compiled into
# more than one target. Shared/ is compiled into all four, so these must agree
# — present everywhere with one value, or absent everywhere. Xcode 26's new-
# target template turns three of them on, which is how the first watch target
# arrived with main-actor default isolation the other three targets do not have.
MEANING_SETTINGS = ("SWIFT_VERSION", "SWIFT_DEFAULT_ACTOR_ISOLATION",
                    "SWIFT_APPROACHABLE_CONCURRENCY", "SWIFT_STRICT_CONCURRENCY",
                    "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY",
                    "STRING_CATALOG_GENERATE_SYMBOLS")

WATCH_APP = "DrinkTrackerWatch"
WATCH_WIDGET = "DrinkTrackerWatchWidget"

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

class Project:
    """The objects of a project.pbxproj, by id, with the few fields these checks
    read. Multi-line objects are `\\t\\tID /* comment */ = {` … `\\t\\t};`; the
    one-line ones (PBXBuildFile, PBXFileReference) close on the same line."""

    def __init__(self, text):
        self.text = text
        self.objects = {}
        block = re.compile(r"^\t\t([0-9A-F]{24})(?: /\* (.*?) \*/)? = \{\n(.*?)^\t\t\};",
                           re.M | re.S)
        for oid, comment, body in block.findall(text):
            self.objects[oid] = {"comment": comment, "body": body,
                                 "isa": self._field(body, "isa")}
        line = re.compile(r"^\t\t([0-9A-F]{24}) /\* (.*?) \*/ = \{(isa = .*?)\};$", re.M)
        for oid, comment, body in line.findall(text):
            self.objects[oid] = {"comment": comment, "body": body,
                                 "isa": self._field(body, "isa")}

    @staticmethod
    def _field(body, key):
        """A scalar field's value, without its trailing `/* comment */` or quotes."""
        m = re.search(r"(?:^|\s|;)" + re.escape(key) + r" = (.+?);", body, re.M | re.S)
        if not m:
            return None
        value = re.sub(r"\s*/\*.*?\*/\s*$", "", m.group(1).strip(), flags=re.S)
        return value.strip().strip('"')

    @staticmethod
    def _ids(body, key):
        m = re.search(re.escape(key) + r" = \((.*?)\);", body, re.S)
        return re.findall(r"([0-9A-F]{24})", m.group(1)) if m else []

    def by_isa(self, isa):
        return {oid: o for oid, o in self.objects.items() if o["isa"] == isa}

    def field(self, oid, key):
        return self._field(self.objects[oid]["body"], key) if oid in self.objects else None

    def ids(self, oid, key):
        return self._ids(self.objects[oid]["body"], key) if oid in self.objects else []

    # --- targets ---------------------------------------------------------
    def targets(self):
        """name -> id, for every PBXNativeTarget."""
        return {self.field(oid, "name"): oid for oid in self.by_isa("PBXNativeTarget")}

    def settings(self, target_id):
        """Every configuration's buildSettings for a target, as dicts."""
        out = []
        config_list = self.field(target_id, "buildConfigurationList")
        for cfg in self.ids(config_list, "buildConfigurations") if config_list else []:
            m = re.search(r"buildSettings = \{(.*?)\n\t\t\t\};", self.objects[cfg]["body"], re.S)
            settings = {}
            for key, value in re.findall(r"^\t\t\t\t([A-Za-z_][A-Za-z0-9_]*) = (.+?);$",
                                         m.group(1) if m else "", re.M):
                settings[key] = value.strip().strip('"')
            out.append((self.field(cfg, "name"), settings))
        return out

    def source_files(self, target_id):
        """Filenames compiled by a target's Sources phase."""
        names = set()
        for phase in self.ids(target_id, "buildPhases"):
            if self.field(phase, "isa") != "PBXSourcesBuildPhase":
                continue
            for build_file in self.ids(phase, "files"):
                ref = self.field(build_file, "fileRef")
                path = self.field(ref, "path") if ref else None
                if path:
                    names.add(os.path.basename(path))
        return names

    def embedded_products(self, target_id, subfolder_spec):
        """Product paths a target's copy phase with this dstSubfolderSpec embeds
        (13 = PlugIns, the extension slot; 16 = the Watch folder)."""
        paths = set()
        for phase in self.ids(target_id, "buildPhases"):
            if self.field(phase, "isa") != "PBXCopyFilesBuildPhase":
                continue
            if self.field(phase, "dstSubfolderSpec") != str(subfolder_spec):
                continue
            for build_file in self.ids(phase, "files"):
                ref = self.field(build_file, "fileRef")
                path = self.field(ref, "path") if ref else None
                if path:
                    paths.add(path)
        return paths

    def dependencies(self, target_id):
        """Names of the targets a target depends on."""
        names = set()
        for dep in self.ids(target_id, "dependencies"):
            target = self.field(dep, "target")
            if target:
                names.add(self.field(target, "name"))
        return names

    def package_products(self, target_id):
        return {self.field(p, "productName")
                for p in self.ids(target_id, "packageProductDependencies")}


def check_project():
    if not os.path.exists(PBXPROJ):
        record(FAIL, "project.pbxproj found", PBXPROJ)
        return
    project = Project(open(PBXPROJ, encoding="utf-8").read())
    targets = project.targets()
    record(INFO, "Targets in the project", ", ".join(sorted(t for t in targets if t)) or "none")

    settings = {name: project.settings(tid) for name, tid in targets.items()}
    app_targets = {n: s for n, s in settings.items() if "Tests" not in n}

    def values(name, key):
        return {cfg.get(key) for _, cfg in settings.get(name, [])}

    # --- versions agree across every target -------------------------------
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        seen = {v for name in settings for v in values(name, key)}
        if seen == {None}:
            record(FAIL, f"{key} set", "not found in any build configuration")
        elif len(seen) == 1:
            record(PASS, f"{key} agrees across targets", seen.pop())
        else:
            record(FAIL, f"{key} agrees across targets",
                   "differs: " + ", ".join(sorted(str(v) for v in seen))
                   + " — App Store validation rejects an embedded target whose "
                     "version disagrees with its host")

    # --- the settings that change what Shared/ means ----------------------
    for key in MEANING_SETTINGS:
        per_target = {name: values(name, key) for name in settings}
        distinct = {frozenset(v) for v in per_target.values()}
        if len(distinct) == 1:
            value = next(iter(next(iter(distinct))))
            record(PASS, f"{key} agrees across targets", value or "inherited everywhere")
        else:
            odd = {n: sorted(str(v) for v in vs) for n, vs in per_target.items()}
            record(FAIL, f"{key} agrees across targets",
                   "Shared/ would compile differently per target: " + str(odd))

    # --- bundle identifiers nest correctly --------------------------------
    ids = {name: values(name, "PRODUCT_BUNDLE_IDENTIFIER") for name in app_targets}
    flat = {v for vs in ids.values() for v in vs if v}
    app = next((i for i in flat if i.endswith(".DrinkTracker")), None)
    if not app:
        record(FAIL, "App bundle identifier found", "expected one ending .DrinkTracker")
        return
    record(PASS, "App bundle identifier", app)

    expected = {
        "iOS widget": app + ".Widget",
        "watch app": app + ".watchkitapp",
        "watch widget": app + ".watchkitapp.Widget",
    }
    watch_present = WATCH_APP in targets
    for label, wanted in expected.items():
        if wanted in flat:
            record(PASS, f"{label} bundle id nests correctly", wanted)
        elif label == "iOS widget":
            record(FAIL, f"{label} bundle id nests correctly", f"expected {wanted}")
        else:
            record(PEND, f"{label} bundle id", f"expected {wanted} once Phase 0 is done")

    # --- literals that should be derived ----------------------------------
    literal = [i for i in flat if not i.startswith("$(BUNDLE_ID_PREFIX)")]
    if literal:
        record(FAIL, "Bundle ids derive from BUNDLE_ID_PREFIX",
               "hardcoded: " + ", ".join(sorted(literal)) + " — invariant 4")
    else:
        record(PASS, "Bundle ids derive from BUNDLE_ID_PREFIX", "no literals")

    if not watch_present:
        record(PEND, "Watch target checks", "Phase 0 has not been done yet; "
                                            "everything below this line is skipped")
        return

    # --- the two watch targets' own settings --------------------------------
    for name in (WATCH_APP, WATCH_WIDGET):
        if name not in targets:
            record(FAIL, f"{name} target exists", "Phase 0 creates it")
            continue
        for key, want in (("SDKROOT", "watchos"),
                          ("TARGETED_DEVICE_FAMILY", "4"),
                          ("WATCHOS_DEPLOYMENT_TARGET", "26.0"),
                          ("SKIP_INSTALL", "YES")):
            seen = values(name, key)
            if seen == {want}:
                record(PASS, f"{name} {key}", want)
            else:
                record(FAIL, f"{name} {key}",
                       f"expected {want}, found {sorted(str(v) for v in seen)}")
        ents = values(name, "CODE_SIGN_ENTITLEMENTS")
        if len(ents) == 1 and next(iter(ents)) and \
                os.path.exists(os.path.join(ROOT, next(iter(ents)))):
            record(PASS, f"{name} CODE_SIGN_ENTITLEMENTS", next(iter(ents)))
        else:
            record(FAIL, f"{name} CODE_SIGN_ENTITLEMENTS",
                   f"unset or missing on disk: {sorted(str(v) for v in ents)}")
        if project.package_products(targets[name]) & {"ComponentsKit"}:
            record(FAIL, f"{name} does not link ComponentsKit",
                   "the watch targets depend on DrinkTrackerCore only")
        else:
            record(PASS, f"{name} does not link ComponentsKit", "")

    if WATCH_APP in targets:
        companion = values(WATCH_APP, "INFOPLIST_KEY_WKCompanionAppBundleIdentifier")
        if companion == {app}:
            record(PASS, "WKCompanionAppBundleIdentifier points at the iOS app", app)
        else:
            record(FAIL, "WKCompanionAppBundleIdentifier points at the iOS app",
                   f"found {sorted(str(c) for c in companion)} — a standalone-capable "
                   "watch app is decision 6's opposite")
        name = values(WATCH_APP, "INFOPLIST_KEY_CFBundleDisplayName")
        if name == {"Tallyist"}:
            record(PASS, "Watch app display name", "Tallyist")
        else:
            record(FAIL, "Watch app display name",
                   f"expected Tallyist (the listing's name), found {sorted(str(n) for n in name)}")
        if "INFOPLIST_KEY_UIBackgroundModes" in project.text:
            record(FAIL, "No INFOPLIST_KEY_UIBackgroundModes in the project",
                   "Xcode injects no such key (none of its specs name it), so the "
                   "setting is inert — the mode belongs in the target's Info.plist")
        if "WKWatchOnly" in project.text:
            record(FAIL, "Watch app is companion-required", "WKWatchOnly must not appear")
        else:
            record(PASS, "Watch app is companion-required", "no WKWatchOnly")

    # The remote-notification background mode is what lets CloudKit's silent
    # pushes wake a process to import; without it a store mirrors only while
    # its app is in the foreground. It reaches a built Info.plist only from a
    # file (merged with the generated keys), never from a build setting.
    for name in ("DrinkTracker", WATCH_APP):
        if name not in targets:
            continue
        plist = values(name, "INFOPLIST_FILE")
        path = os.path.join(ROOT, next(iter(plist)) or "") if len(plist) == 1 else ""
        body = open(path, encoding="utf-8").read() if path and os.path.isfile(path) else ""
        if "UIBackgroundModes" in body and "remote-notification" in body:
            record(PASS, f"{name} Info.plist carries remote-notification", os.path.relpath(path, ROOT))
        else:
            record(FAIL, f"{name} Info.plist carries remote-notification",
                   f"INFOPLIST_FILE {sorted(str(p) for p in plist)} — CloudKit cannot wake "
                   "the app to import without it")

    if WATCH_WIDGET in targets:
        plist = values(WATCH_WIDGET, "INFOPLIST_FILE")
        path = os.path.join(ROOT, next(iter(plist)) or "") if len(plist) == 1 else ""
        if path and os.path.isfile(path) and \
                "com.apple.widgetkit-extension" in open(path, encoding="utf-8").read():
            record(PASS, "Watch widget declares the WidgetKit extension point", os.path.relpath(path, ROOT))
        else:
            record(FAIL, "Watch widget declares the WidgetKit extension point",
                   f"INFOPLIST_FILE {sorted(str(p) for p in plist)} must carry NSExtensionPointIdentifier")

    # --- the embed phases, which are what make it one submission -----------
    if "DrinkTracker" in targets:
        watch_embeds = project.embedded_products(targets["DrinkTracker"], 16)
        if f"{WATCH_APP}.app" in watch_embeds and WATCH_APP in project.dependencies(targets["DrinkTracker"]):
            record(PASS, "iOS app embeds the watch app", "Embed Watch Content + target dependency")
        else:
            record(FAIL, "iOS app embeds the watch app",
                   f"Embed Watch Content carries {sorted(watch_embeds)}; dependencies "
                   f"{sorted(project.dependencies(targets['DrinkTracker']))} — the watch "
                   "app would not ship inside the iOS app")
    if WATCH_APP in targets:
        appex = project.embedded_products(targets[WATCH_APP], 13)
        if f"{WATCH_WIDGET}.appex" in appex and WATCH_WIDGET in project.dependencies(targets[WATCH_APP]):
            record(PASS, "Watch app embeds the complication", "Embed Foundation Extensions + target dependency")
        else:
            record(FAIL, "Watch app embeds the complication",
                   f"PlugIns copy phase carries {sorted(appex)}; dependencies "
                   f"{sorted(project.dependencies(targets[WATCH_APP]))}")

    # --- Shared/ reaches every target that needs it -----------------------
    for name in (WATCH_APP, WATCH_WIDGET):
        if name not in targets:
            continue
        have = project.source_files(targets[name]) & set(SHARED_FILES)
        missing = [f for f in SHARED_FILES if f not in have]
        core = "DrinkTrackerCore" in project.package_products(targets[name])
        if not have and not core:
            record(PEND, f"Shared/ compiled into {name}",
                   "Phase 1: link DrinkTrackerCore and tick the six files")
        elif not missing and core:
            record(PASS, f"Shared/ compiled into {name}", "all six files, DrinkTrackerCore linked")
        else:
            record(FAIL, f"Shared/ compiled into {name}",
                   f"missing {missing or 'nothing'}; DrinkTrackerCore linked: {core} — four of "
                   "the six files import the package, so both halves must land together")

    # --- and the rest of Shared/ reaches exactly the targets that read it --
    on_disk = sorted(f for f in os.listdir(os.path.join(ROOT, "Shared"))
                     if f.endswith(".swift"))
    unlisted = [f for f in on_disk if f not in SHARED_FILES and f not in SHARED_EXTRAS]
    if unlisted:
        record(FAIL, "Every Shared/ file has an expected membership",
               f"not named in this script: {unlisted} — add it to SHARED_EXTRAS "
               "with the targets that compile it")
    else:
        record(PASS, "Every Shared/ file has an expected membership",
               f"{len(on_disk)} files")

    for filename, expected in sorted(SHARED_EXTRAS.items()):
        if filename not in on_disk:
            record(FAIL, f"Shared/{filename}", "named here but not on disk")
            continue
        actual = tuple(name for name in expected
                       if name in targets and filename in project.source_files(targets[name]))
        if actual == expected:
            record(PASS, f"Shared/{filename}", ", ".join(expected))
        else:
            record(FAIL, f"Shared/{filename}",
                   f"expected {list(expected)}, compiled into {list(actual)}")


# ---------------------------------------------------------------- files -----

def check_files():
    pkg = os.path.join(ROOT, "DrinkTrackerCore", "Package.swift")
    if os.path.exists(pkg):
        body = open(pkg, encoding="utf-8").read()
        if ".watchOS(" in body:
            record(PASS, "DrinkTrackerCore declares a watchOS platform", "")
        else:
            record(PEND, "DrinkTrackerCore declares a watchOS platform",
                   'Phase 1: .watchOS("26.0") — .v26 needs a newer tools-version')

    if os.path.isdir(SCHEMES):
        schemes = sorted(f[:-9] for f in os.listdir(SCHEMES) if f.endswith(".xcscheme"))
        record(INFO, "Shared schemes", ", ".join(schemes))
        if WATCH_APP in schemes:
            record(PASS, "A watch scheme is shared", "CI can see it")
        else:
            record(PEND, "A watch scheme is shared",
                   "share the DrinkTrackerWatch scheme, or CI cannot build it")

    for target in (WATCH_APP, WATCH_WIDGET):
        path = os.path.join(ROOT, target, target + ".entitlements")
        if not os.path.exists(path):
            record(PEND, f"{target} entitlements", "Phase 0 writes it")
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

        catalog = os.path.join(ROOT, target, "Localizable.xcstrings")
        if os.path.isdir(os.path.join(ROOT, target)):
            if os.path.exists(catalog):
                record(PASS, f"{target} has a string catalog", "")
            else:
                record(FAIL, f"{target} has a string catalog",
                       "SWIFT_EMIT_LOC_STRINGS is on; without a catalog nothing is written back")

    ci = os.path.join(ROOT, ".github", "workflows", "ci.yml")
    if os.path.exists(ci):
        body = open(ci, encoding="utf-8").read()
        if "watchOS Simulator" in body:
            record(PASS, "CI builds the watch", "")
        else:
            record(PEND, "CI builds the watch", "add the build-watch job, Phase 1")

    claude_md = os.path.join(ROOT, WATCH_APP, "CLAUDE.md")
    if os.path.exists(claude_md):
        record(PASS, "Watch target has a scoped CLAUDE.md", "")
    elif os.path.isdir(os.path.join(ROOT, WATCH_APP)):
        record(FAIL, "Watch target has a scoped CLAUDE.md", "missing")


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
    installed = os.path.exists(SYNC_AGENT_PLIST)
    record(INFO, "Sync agent",
           ("installed" if installed else "not installed (scripts/install-sync-agent.sh)")
           + ("; watches the main clone, not this worktree" if is_worktree else ""))
    dirty = git("status", "--porcelain") or ""
    if is_worktree or not installed:
        pass
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
