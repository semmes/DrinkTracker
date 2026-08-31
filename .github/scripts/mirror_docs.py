#!/usr/bin/env python3
"""Render and verify the published copies of the documents Tallyist must host.

`docs/privacy-policy.md` and `docs/support.md` in this repository are canonical
(ADR-0024). The public copies in `semmes/Tallyist` are those same bodies with
Jekyll front matter prepended — nothing else differs, which is what makes the
mirror checkable rather than merely intended.

  render <doc> <out>   write the published form of <doc> to <out>
  check                compare every published copy against this repository's
"""

import os
import pathlib
import sys
import urllib.error
import urllib.request

# The contents API rather than raw.githubusercontent: the raw host serves
# through a CDN that can hand back a copy minutes old, which turns a check meant
# to detect drift into one that reports drift that was already repaired. Asked
# for as raw, this returns the file body directly.
API = ("https://api.github.com/repos/semmes/Tallyist/contents/{name}"
       "?ref=main")

# The front matter each published copy carries. Keep in step with the layout in
# semmes/Tallyist; a permalink change here is an App Store Connect change too.
DOCS = {
    "privacy-policy.md": {
        "title": "Privacy Policy",
        "description": "Tallyist does not collect your data. Nothing you log leaves your control.",
        "permalink": "/privacy/",
    },
    "support.md": {
        "title": "Support",
        "description": "Help, common questions, and how to reach the developer of Tallyist.",
        "permalink": "/support/",
    },
}


def published_form(repo_root: pathlib.Path, name: str) -> str:
    meta = DOCS[name]
    body = (repo_root / "docs" / name).read_text(encoding="utf-8")
    front = (
        "---\n"
        "layout: default\n"
        f"title: {meta['title']}\n"
        f"description: {meta['description']}\n"
        f"permalink: {meta['permalink']}\n"
        "---\n\n"
    )
    return front + body


def check(repo_root: pathlib.Path) -> int:
    failures = []
    for name in DOCS:
        expected = published_form(repo_root, name)
        req = urllib.request.Request(
            API.format(name=name),
            headers={
                "Accept": "application/vnd.github.raw",
                "User-Agent": "tallyist-mirror-check",
                # Anonymous requests are rate limited to 60/hour per IP, which a
                # shared runner can exhaust. Actions provides a token; it needs
                # no permissions here, since the repository is public.
                **({"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"}
                   if os.environ.get("GITHUB_TOKEN") else {}),
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                actual = r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            failures.append(f"{name}: could not fetch published copy (HTTP {e.code})")
            continue
        if actual != expected:
            failures.append(
                f"{name}: the published copy in semmes/Tallyist does not match "
                f"docs/{name} in this repository"
            )

    if failures:
        print("Published documents are out of step with this repository:\n")
        for f in failures:
            print(f"  - {f}")
        print(
            "\nThe copy at semmes.github.io is what App Review and users read, so "
            "this is a real divergence, not a formatting nit.\n"
            "Re-run the 'Mirror published documents' workflow, or push the "
            "rendered files to semmes/Tallyist by hand."
        )
        return 1

    print("Published documents match this repository.")
    return 0


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[2]
    if len(sys.argv) >= 2 and sys.argv[1] == "check":
        return check(root)
    if len(sys.argv) == 4 and sys.argv[1] == "render":
        name, out = sys.argv[2], pathlib.Path(sys.argv[3])
        if name not in DOCS:
            print(f"unknown document: {name}", file=sys.stderr)
            return 2
        out.write_text(published_form(root, name), encoding="utf-8")
        print(f"rendered {name} -> {out}")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
