#!/usr/bin/env python3
"""Check the published documents as GitHub Pages' Jekyll built them.

`docs/support.md` chooses some answers with Liquid by the site's platform state
(`platform_state` in the website's `_config.yml`: 1 while only the iPhone app is
live, 2 once the watch app is, 3 once Android is), and the privacy policy's
published form carries its web-only lines (ADR-0024). CI builds both published
forms with GitHub's own Jekyll, once per state, and this reads the output:

  check_published_build.py <site dir> <state>

It fails if Liquid survived into a page, if a question lost its answer, or if a
page says what its state should not. The sentences it looks for are the ones
that change between states, so an edit to them belongs here too.
"""

import html
import pathlib
import re
import sys

# Every state shows every question; only some answers change.
QUESTIONS = 22

# (state predicate, text that must appear, text that must not)
SUPPORT_BY_STATE = {
    1: (
        [
            "It is coming with Tallyist 1.4.",
            "Not yet. It is coming, with the same rules.",
            "From version 1.4, the watch app logs a drink",
            "From version 1.4, Trends can show four figures",
        ],
        [
            "It installs with the iPhone app.",
            "deleting the watch app removes",
            "Google Play",
            "On Android",
        ],
    ),
    2: (
        [
            "It installs with the iPhone app.",
            "deleting the watch app removes",
            "The watch app logs a drink",
            "Not yet. It is coming, with the same rules.",
        ],
        [
            "It is coming with Tallyist 1.4.",
            "From version 1.4",
            "Google Play",
            "On Android",
        ],
    ),
    3: (
        [
            "It installs with the iPhone app.",
            "Yes, on Google Play.",
            "Tallyist asks for no sign-in, and has no permission to use the internet.",
            "On Android, your log is stored on the device",
        ],
        [
            "It is coming with Tallyist 1.4.",
            "From version 1.4",
            "Not yet.",
        ],
    ),
}

PRIVACY_MUST = [
    "This policy is kept under version control",
    "mailto:tallyist@gmail.com",
]
PRIVACY_MUST_NOT = [
    "github.com/semmes",
    "issue tracker",
]


def read(site: pathlib.Path, path: str, failures: list) -> str:
    page = site / path
    if not page.is_file():
        failures.append(f"{path}: not built")
        return ""
    return page.read_text(encoding="utf-8")


def unrendered(name: str, raw: str, failures: list) -> None:
    for token in ("{%", "%}", "{{", "}}"):
        if token in raw:
            failures.append(f"{name}: Liquid left in the page ({token!r})")


def main() -> int:
    if len(sys.argv) != 3 or int(sys.argv[2]) not in SUPPORT_BY_STATE:
        print(__doc__, file=sys.stderr)
        return 2
    site, state = pathlib.Path(sys.argv[1]), int(sys.argv[2])
    failures: list = []

    raw = read(site, "support/index.html", failures)
    if raw:
        unrendered("support", raw, failures)
        # kramdown writes a mailto link as character references; compare text.
        text = html.unescape(raw)
        # kramdown may indent the raw HTML it passes through, so count loosely.
        opened = len(re.findall(r"<details>", text))
        closed = len(re.findall(r"</details>", text))
        answered = len(re.findall(r"</summary>\s*<p>\S", text))
        if not (opened == closed == answered == QUESTIONS):
            failures.append(
                f"support: {QUESTIONS} answered questions expected, found "
                f"{opened} opened, {closed} closed, {answered} answered"
            )
        must, must_not = SUPPORT_BY_STATE[state]
        failures += [f"support (state {state}): missing {s!r}" for s in must if s not in text]
        failures += [f"support (state {state}): should not say {s!r}" for s in must_not if s in text]
        if not re.search(r'href="/privacy/"', text):
            failures.append("support: the privacy policy link is not /privacy/")

    raw = read(site, "privacy/index.html", failures)
    if raw:
        unrendered("privacy", raw, failures)
        text = html.unescape(raw)
        failures += [f"privacy: missing {s!r}" for s in PRIVACY_MUST if s not in text]
        failures += [f"privacy: should not say {s!r}" for s in PRIVACY_MUST_NOT if s in text]

    if failures:
        print(f"The published documents did not build as expected in state {state}:\n")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"State {state}: both published documents built as expected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
