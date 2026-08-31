#!/usr/bin/env python3
"""Warn before TALLYIST_SYNC_TOKEN expires, and fail once expiry is imminent.

The mirror's failure mode when this token lapses is quiet in the way that
matters: `sync` starts failing on merges nobody is watching, and the published
policy simply stops tracking the app. Nothing about the published page looks
wrong — it looks exactly as it did the day the token died.

The expiry is read from the token rather than written down here. GitHub returns
`github-authentication-token-expiration` on any request authenticated with a
personal access token that has one, so this stays correct across a rotation
without anyone remembering to edit a date.
"""

# Deferred annotation evaluation: the runner has a modern Python but this script
# should also run on whatever is already on a developer's Mac (3.9 at the time of
# writing), where `dt.datetime | None` is a TypeError at import.
from __future__ import annotations

import datetime as dt
import os
import sys
import urllib.error
import urllib.request

REPO = "semmes/Tallyist"
WARN_WITHIN_DAYS = 30
FAIL_WITHIN_DAYS = 7

HEADER = "github-authentication-token-expiration"


def annotate(level: str, title: str, message: str) -> None:
    # One line for the Actions annotation, one for anyone reading the log.
    print(f"::{level} title={title}::{message}")
    print(f"{title}: {message}")


def parse_expiry(raw: str) -> dt.datetime | None:
    value = raw.strip()
    # Observed as "2026-11-29 20:24:50 UTC"; ISO-8601 is accepted too, since the
    # header's exact shape is not something to depend on.
    for fmt in ("%Y-%m-%d %H:%M:%S %Z", "%Y-%m-%d %H:%M:%S UTC",
                "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S %z"):
        try:
            return dt.datetime.strptime(value, fmt).replace(tzinfo=dt.timezone.utc)
        except ValueError:
            continue
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def main() -> int:
    token = os.environ.get("TALLYIST_SYNC_TOKEN", "").strip()
    if not token:
        annotate("notice", "Mirror token not configured",
                 "TALLYIST_SYNC_TOKEN is not set, so there is no expiry to track.")
        return 0

    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}",
        headers={"Authorization": f"Bearer {token}",
                 "Accept": "application/vnd.github+json",
                 "User-Agent": "tallyist-token-expiry-check"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.headers.get(HEADER)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            annotate("error", "Mirror token rejected",
                     "TALLYIST_SYNC_TOKEN is no longer valid — it has expired or "
                     "been revoked. The published documents will stop tracking "
                     "this repository until it is replaced.")
            return 1
        annotate("warning", "Could not check the mirror token",
                 f"GitHub returned HTTP {e.code}; expiry not verified this run.")
        return 0

    if not raw:
        annotate("notice", "Mirror token has no expiry",
                 "GitHub reported no expiration for this token. Nothing to warn "
                 "about, but a non-expiring token is worth a second thought.")
        return 0

    expires = parse_expiry(raw)
    if expires is None:
        annotate("warning", "Could not read the mirror token's expiry",
                 f"Unrecognised expiry format from GitHub: {raw!r}.")
        return 0

    days = (expires - dt.datetime.now(dt.timezone.utc)).days
    when = expires.strftime("%a, %d %b %Y")

    if days < 0:
        annotate("error", "Mirror token has expired",
                 f"TALLYIST_SYNC_TOKEN expired on {when}. Rotate it and update "
                 f"the secret in this repository.")
        return 1
    if days <= FAIL_WITHIN_DAYS:
        annotate("error", "Mirror token expires within a week",
                 f"TALLYIST_SYNC_TOKEN expires {when} ({days} days). Rotate it "
                 f"now: https://github.com/settings/personal-access-tokens")
        return 1
    if days <= WARN_WITHIN_DAYS:
        annotate("warning", "Mirror token expires soon",
                 f"TALLYIST_SYNC_TOKEN expires {when} ({days} days). Rotate it at "
                 f"https://github.com/settings/personal-access-tokens, then update "
                 f"the secret with fine-grained access to {REPO} (Contents: write).")
        return 0

    print(f"Mirror token valid until {when} ({days} days).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
