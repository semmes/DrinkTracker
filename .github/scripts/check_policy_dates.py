#!/usr/bin/env python3
"""Fail if the privacy policy's three copies disagree on their date.

The policy exists in three places (ADR-0024): `docs/privacy-policy.md` here,
`PrivacyPolicyView.swift` here, and the published copy in `semmes/Tallyist`.
The published one is generated from the first, so it cannot drift on its own —
the pair that a human can get out of step is the canonical file and the Swift.

A stale date is the failure worth catching early: it is invisible on screen,
survives review, and quietly tells a reader that a policy they are looking at
has not changed since a date on which it did.
"""

import pathlib
import re
import sys

MONTHS = ("January February March April May June July August September "
          "October November December").split()
DATE = rf"(?:{'|'.join(MONTHS)})\s+\d{{1,2}},\s+\d{{4}}"

SOURCES = [
    ("docs/privacy-policy.md", rf"\*\*Last updated:\s+({DATE})\*\*"),
    ("DrinkTracker/Features/Settings/PrivacyPolicyView.swift",
     rf'Text\("Last updated\s+({DATE})\."\)'),
]


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[2]
    found = {}
    for rel, pattern in SOURCES:
        text = (root / rel).read_text(encoding="utf-8")
        matches = re.findall(pattern, text)
        if len(matches) != 1:
            print(f"{rel}: expected exactly one 'Last updated' date, found "
                  f"{len(matches)}. The pattern in this script and the copy have "
                  f"diverged — fix whichever is wrong.")
            return 1
        found[rel] = matches[0]

    if len(set(found.values())) != 1:
        print("The privacy policy's copies disagree on their date:\n")
        for rel, date in found.items():
            print(f"  {date:22} {rel}")
        print("\nBoth copies change together, date included (CLAUDE.md, ADR-0024).")
        return 1

    print(f"Privacy policy copies agree: {next(iter(found.values()))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
