#!/usr/bin/env python3
"""Warn before this repository's access tokens expire, and fail once imminent.

Two tokens, two different failure modes, both worth machinery:

TALLYIST_SYNC_TOKEN — the mirror's failure when it lapses is quiet in the way
that matters: `sync` starts failing on merges nobody is watching, and the
published policy simply stops tracking the app. Nothing about the published page
looks wrong — it looks exactly as it did the day the token died.

TALLYIST_CONTRACT_TOKEN — `contract/` is a submodule of the private
semmes/tallyist-product, and ci.yml's five checkouts fetch it with this token.
That failure is loud rather than quiet, but it is loud in the wrong place: every
job fails at its checkout step, which reads as a CI outage rather than as an
expired credential. Thirty days' warning is the difference.

The expiry is read from each token rather than written down here. GitHub returns
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
import urllib.error
import urllib.request

# Each token is probed against the repository it is scoped to: the expiry header
# comes back on any authenticated request, and using that repo means a token that
# has lost its grant shows up as a 404 here rather than as a broken job later.
TOKENS = (
    {
        "env": "TALLYIST_SYNC_TOKEN",
        "repo": "semmes/Tallyist",
        "label": "Mirror token",
        "grant": "Contents: write",
        "consequence": "The published documents will stop tracking this "
                       "repository until it is replaced.",
    },
    {
        "env": "TALLYIST_CONTRACT_TOKEN",
        "repo": "semmes/tallyist-product",
        "label": "Contract token",
        "grant": "Contents: read, on semmes/tallyist-product and "
                 "semmes/DrinkTracker",
        "consequence": "Every CI job fails at its checkout step, because the "
                       "contract/ submodule cannot be fetched.",
    },
)

WARN_WITHIN_DAYS = 30
FAIL_WITHIN_DAYS = 7

HEADER = "github-authentication-token-expiration"
ROTATE = "https://github.com/settings/personal-access-tokens"


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


def check(spec: dict) -> int:
    """0 if this token is fine or simply absent, 1 if it needs attention now."""
    label, repo, env = spec["label"], spec["repo"], spec["env"]
    token = os.environ.get(env, "").strip()
    if not token:
        annotate("notice", f"{label} not configured",
                 f"{env} is not set, so there is no expiry to track.")
        return 0

    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}",
        headers={"Authorization": f"Bearer {token}",
                 "Accept": "application/vnd.github+json",
                 "User-Agent": "tallyist-token-expiry-check"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.headers.get(HEADER)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            annotate("error", f"{label} rejected",
                     f"{env} is no longer valid — it has expired or been "
                     f"revoked. {spec['consequence']}")
            return 1
        if e.code == 404:
            # A fine-grained token that has not been granted a repository gets a
            # 404 rather than a 403, so this is the shape a mis-scoped rotation
            # takes: the token works, it just cannot see what it is for.
            annotate("error", f"{label} cannot see {repo}",
                     f"{env} authenticated, but GitHub reports no such "
                     f"repository — which is what a fine-grained token missing "
                     f"its grant looks like. Re-scope it at {ROTATE} with "
                     f"{spec['grant']}. {spec['consequence']}")
            return 1
        annotate("warning", f"Could not check the {label.lower()}",
                 f"GitHub returned HTTP {e.code}; expiry not verified this run.")
        return 0

    if not raw:
        annotate("notice", f"{label} has no expiry",
                 "GitHub reported no expiration for this token. Nothing to warn "
                 "about, but a non-expiring token is worth a second thought.")
        return 0

    expires = parse_expiry(raw)
    if expires is None:
        annotate("warning", f"Could not read the {label.lower()}'s expiry",
                 f"Unrecognised expiry format from GitHub: {raw!r}.")
        return 0

    days = (expires - dt.datetime.now(dt.timezone.utc)).days
    when = expires.strftime("%a, %d %b %Y")

    if days < 0:
        annotate("error", f"{label} has expired",
                 f"{env} expired on {when}. Rotate it and update the secret in "
                 f"this repository. {spec['consequence']}")
        return 1
    if days <= FAIL_WITHIN_DAYS:
        annotate("error", f"{label} expires within a week",
                 f"{env} expires {when} ({days} days). Rotate it now: {ROTATE}")
        return 1
    if days <= WARN_WITHIN_DAYS:
        annotate("warning", f"{label} expires soon",
                 f"{env} expires {when} ({days} days). Rotate it at {ROTATE}, "
                 f"then update the secret with fine-grained access to {repo} "
                 f"({spec['grant']}).")
        return 0

    print(f"{label} valid until {when} ({days} days).")
    return 0


def main() -> int:
    # Every token is checked before anything fails, so one expired credential
    # does not hide a second one behind it.
    return 1 if sum(check(spec) for spec in TOKENS) else 0


if __name__ == "__main__":
    raise SystemExit(main())
