#!/usr/bin/env python3
"""Render and verify the published copies of the documents Tallyist must host.

`docs/privacy-policy.md` and `docs/support.md` in this repository are canonical
(ADR-0024). The public copies in `semmes/Tallyist` are those same bodies with
Jekyll front matter prepended, and with the few web-only lines in WEB_ONLY put
in place of the canonical ones. Nothing else differs, which is what makes the
mirror checkable rather than merely intended: every web-only line is replaced
by exact text that must occur exactly once, so an edit that moves one fails
here, in CI, before a merge could publish a policy nobody decided on.

  render <doc> <out>   write the published form of <doc> to <out>
  render-all           render every published form to nowhere; fails if a
                       web-only line no longer matches the canonical text
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

# Lines the website publishes in place of the canonical text, by the owner's
# decision (ADR-0024, amended 2026-09-24): the website names an email address
# for questions and does not send its readers to the repository. The canonical
# policy here keeps both lines, and the app's copy, which has no Contact
# section, keeps the repository sentence. Each pair is (canonical text,
# published text), matched exactly and exactly once. Keep this list short:
# every line here is a sentence the copies say differently, and the daily
# verify job holds the website to exactly these.
WEB_ONLY = {
    "privacy-policy.md": [
        (
            "This policy is published in a public repository at\n"
            "<https://github.com/semmes/Tallyist>; every change to it, and its date, is\n"
            "visible in that repository's history.",
            "This policy is kept under version control; every change to it, and its\n"
            "date, is recorded.",
        ),
        (
            "Questions about this policy can be raised as an issue on the app's public\n"
            "issue tracker: <https://github.com/semmes/Tallyist/issues>.",
            "Questions about this policy can be sent to\n"
            "[tallyist@gmail.com](mailto:tallyist@gmail.com).",
        ),
    ],
}


class WebOnlyLineMissing(Exception):
    """A web-only line no longer matches the canonical text exactly once."""


def web_body(name: str, body: str) -> str:
    for canonical, published in WEB_ONLY.get(name, []):
        found = body.count(canonical)
        if found != 1:
            first = canonical.splitlines()[0]
            raise WebOnlyLineMissing(
                f"docs/{name}: a web-only line matches {found} times, not once:\n"
                f"    {first}\n"
                "The canonical text it replaces has changed. Decide what the website "
                "should say now and update WEB_ONLY in .github/scripts/mirror_docs.py "
                "in the same change (ADR-0024)."
            )
        body = body.replace(canonical, published)
    return body


def published_form(repo_root: pathlib.Path, name: str) -> str:
    meta = DOCS[name]
    body = web_body(name, (repo_root / "docs" / name).read_text(encoding="utf-8"))
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
        try:
            expected = published_form(repo_root, name)
        except WebOnlyLineMissing as e:
            failures.append(str(e))
            continue
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
            "\nThe copy at tallyist.co (semmes.github.io/Tallyist redirects there) is "
            "what App Review and users read, so this is a real divergence, not a "
            "formatting nit.\n"
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
    if len(sys.argv) == 2 and sys.argv[1] == "render-all":
        try:
            for name in DOCS:
                published_form(root, name)
        except WebOnlyLineMissing as e:
            print(e, file=sys.stderr)
            return 1
        print("Every published form renders, and every web-only line matches once.")
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == "render":
        name, out = sys.argv[2], pathlib.Path(sys.argv[3])
        if name not in DOCS:
            print(f"unknown document: {name}", file=sys.stderr)
            return 2
        try:
            text = published_form(root, name)
        except WebOnlyLineMissing as e:
            print(e, file=sys.stderr)
            return 1
        out.write_text(text, encoding="utf-8")
        print(f"rendered {name} -> {out}")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
