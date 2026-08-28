# 0021 — The privacy policy stays in English, and says so

**Status:** accepted · **Date:** 2026-08-28 · **Supersedes / superseded by:** —

## Context

Localization prep made the privacy policy extractable, and not on purpose. Typing
`SectionLabel` as a `LocalizedStringKey` — the fix that recovered ten section
headings for the catalog — forced `policySection(_:_:)` to follow, so the policy's
headings and body paragraphs became catalog keys like any other string. Fourteen
of them, including one of 1,088 characters.

That is a decision arriving by side effect, which is the wrong way for this
particular text to be decided. So it was made deliberately instead.

The case for translating it is real and should not be dismissed. A policy the
reader cannot read is not doing its job. An app translated into French whose
privacy screen is English looks half-finished, and "explain what happens to your
data" is exactly the kind of information a person is entitled to in their own
language. Most apps translate their policies.

The case against is narrower but heavier. This project's rule is that the policy's
claims are *written to be checkable* against the privacy manifest, the
entitlements, and the absence of networking code — anyone can read
`PrivacyInfo.xcprivacy` and confirm that "no third-party services" is true. That
checkability is a property of the English sentences. Nobody on this project can
perform the same check on a French translation, and translation here is entirely
deferred: there is no budget and no reviewer, so the realistic translator is a
machine or a freelancer with no access to the entitlements.

And the failure mode is not the usual one. Everywhere else in the app a bad string
is a bug — "1 standard drinks" is embarrassing. In this text a bad string is a
false statement about what happens to someone's data.

Two facts settled the balance. The hosted copy at the App Store listing's privacy
URL — the one App Review actually reads — stays English regardless, so translating
the in-app copy creates a *second*, unverifiable statement of the same claims
rather than replacing anything. And the app already ships worldwide with an
English policy today, so keeping it English is the status quo held steady, not a
regression introduced by this decision.

## Decision

The fourteen policy strings are marked `"shouldTranslate": false` in
`DrinkTracker/Localizable.xcstrings`. They never reach a translator and stay
identical to the hosted copy.

`Privacy Policy` and `Read this policy online` stay translatable: they are
navigation and an affordance, not claims, and `Privacy Policy` is shared with the
Settings row and the Support link, which would otherwise go English as collateral.

The hosted copy now states this rather than leaving it implied. It previously said
"The same text ships inside the app"; it now names itself the authoritative
version and says the in-app copy stays English even where the interface is
translated, and why.

## Consequences

A reader whose device is in another language gets the interface translated and the
privacy screen in English. That is the cost, it is real, and it is the reason this
needed to be a decision rather than a default.

What it buys: every claim in the policy stays checkable by anyone against
artefacts in this repository, in the only language the check was written for. The
two copies cannot drift by language. And a translator handed the catalog is not
silently made responsible for a legal representation they have no way to verify.

`shouldTranslate` survives `xcrun xcstringstool sync`, which is how the catalogs
are populated here — verified before relying on it, since a marking that a routine
re-sync quietly dropped would be worse than no marking at all.

Left undone deliberately: the 1,088-character key covering iCloud, Health, the
widget, and export is a poor translation unit — four topics a translator would
have to take atomically, invalidated whole by an edit to any one sentence. Nothing
translates it, so nothing is gained by splitting it now. It is the first thing to
fix if this is reopened.

Also left undone: no line was added telling the reader the policy is in English.
There is no second language yet, so such a line would currently be a note about
nothing. It belongs with the first translation.

## How to reopen

Someone who can check a translated policy against the entitlements and the privacy
manifest — a reviewer with the context, not just a translator. That is the whole
condition; the objection is not to translation but to shipping unverifiable claims
about someone's data.

If it is reopened: split the 1,088-character key by topic first, add comments on
each key naming the claims that must stay literally true, and gate the language's
release on that check rather than on the translation being finished.

A change in obligation would also force it — a jurisdiction requiring the policy
in the user's language would make this decision moot, and the answer then is to
translate *and* fund the review, not to translate without it.
