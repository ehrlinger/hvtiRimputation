# Claude Code specifics

@AGENTS.md

[`AGENTS.md`](https://ehrlinger.github.io/hvtiRimputation/AGENTS.md),
imported above, is the operational contract and applies in full. It is
written to be tool neutral so that Codex and other agents read the same
rules. Only the Claude Code affordances live here.

## Before you touch code

`AGENTS.md` says to orient before editing. In Claude Code the way to do
that is the codemap: it lives in the Obsidian vault under
`Claude/repomaps/` and is read via the `read-codemap` skill
(`/codemap hvtiRimputation`). If the codemap looks stale, say so and
offer to refresh it (`/regenerate-codemap`) rather than working from a
guess.

⚠️ **There is no codemap for this repo yet** — it was created on
2026-09-08 and the indexer has not seen it. Offer to generate one
(`/regenerate-codemap`) rather than reporting the absence as staleness.

If the vault is not available, say so rather than staying quiet about
it, then orient from the repo itself. Start with the `@details` block in
`R/hvtiRimputation-package.R` and the validation-file comment at the top
of `R/validate.R` — between them they explain more of this package’s
design than any other file.

## Reading the SAS side

Several rules here only make sense against the SAS they port.
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
ports `PROC STANDARD ... REPLACE`, which the `imputsub` macro wraps.

⚠️ **No local copy of `imputsub` has been located.** A `find` over
`/Volumes/qhsstudies` to depth 6 returned nothing, so the SAS semantics
encoded here come from the corpus scan at
`hvtiRdatabuild/dev/specs/artifacts/imputation-method-scan.R`, which
separates plain `REPLACE` (fills with the mean), `REPLACE` with
`MEAN=`/`STD=` (standardises *and* fills) and `PROC STANDARD` without
`REPLACE` (not imputation). If a question is “does this match SAS”, read
that scan and — better — find the macro. Remember the parity scope: the
arithmetic is matched, the defaults are deliberately not.

## Prose

`AGENTS.md` points at the house voice. In Claude Code, apply the
`ehrlinger-writing` skill: it carries the same voice, reader persona and
project context, kept in sync from the vault sources. For documentation
*structure*, the `r-package-style` skill is the companion.
