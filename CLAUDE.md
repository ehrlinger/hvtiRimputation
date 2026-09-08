@AGENTS.md

# Claude Code specifics

[`AGENTS.md`](AGENTS.md), imported above, is the operational contract and applies in full. It is written
to be tool neutral so that Codex and other agents read the same rules. Only the Claude Code
affordances live here.

## Before you touch code

`AGENTS.md` says to orient before editing. In Claude Code the way to do that is the codemap:
it lives in the Obsidian vault under `Claude/repomaps/` and is read via the `read-codemap`
skill (`/codemap hvtiRimputation`). If the codemap looks stale, say so and offer to refresh it
(`/regenerate-codemap`) rather than working from a guess.

✅ **The codemap exists** — `Claude/repomaps/hvtiRimputation.md` in the vault, first written
2026-09-08. It arrived without being asked for: `code_index.py` walks `~/Documents/GitHub`
and reads the house-style registry, so a repo becomes mapped by existing on disk and being
registered, not by anyone running the indexer. The launchd agent refreshes every 15 minutes;
`/regenerate-codemap` forces it.

If the vault is not available, say so rather than staying quiet about it, then orient from the
repo itself. Start with the `@details` block in `R/hvtiRimputation-package.R` and the
validation-file comment at the top of `R/validate.R` — between them they explain more of this
package's design than any other file.

## Reading the SAS side

Several rules here only make sense against the SAS they port. `impute_mean()` ports
`PROC STANDARD ... REPLACE`, which the `imputsub` macro wraps.

⚠️ **No local copy of `imputsub` has been located.** A `find` over `/Volumes/qhsstudies` to
depth 6 returned nothing, so the SAS semantics encoded here come from the corpus scan at
`hvtiRdatabuild/dev/specs/artifacts/imputation-method-scan.R`, which separates plain
`REPLACE` (fills with the mean), `REPLACE` with `MEAN=`/`STD=` (standardises *and* fills)
and `PROC STANDARD` without `REPLACE` (not imputation). If a question is "does this match
SAS", read that scan and — better — find the macro. Remember the parity scope: the
arithmetic is matched, the defaults are deliberately not.

## Prose

`AGENTS.md` points at the house voice. In Claude Code, apply the `ehrlinger-writing` skill:
it carries the same voice, reader persona and project context, kept in sync from the vault
sources. For documentation *structure*, the `r-package-style` skill is the companion.
