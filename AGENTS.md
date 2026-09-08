# hvtiRimputation

Fill missing values in a data frame by a stated method, and return the filled
data together with a record of exactly what was changed. The R port of the CORR
macro library's `imputsub` (`PROC STANDARD ... REPLACE`) and, later,
`mult_imput` (`PROC MI`).

**v0.1.0 implements single mean imputation only.** `impute_mean()` is the one
method; the record around it is `imputed_matrix()`, `imputed_any()`,
`complete_case_pass()`, `imputation_indicators()` and
`imputation_provenance()`, with `print()` and `summary()` methods.
`impute_multiple()` is designed and not built.

**The scope boundary is load-bearing.** A data frame in, a data frame and a
record out. This package knows nothing about the warehouse, the build, or any
study, and it takes **no dependency on `hvtiRdatabuild` in either direction** --
a method package that took a build-layer dependency would drag the warehouse
credential ladder, the manifest and the snapshot machinery into every analysis
job that wanted to fill a column. Any study, manifest or provenance context
belongs to the caller.

**The parity scope is narrow and deliberate.** `impute_mean()` matches the
macro's *arithmetic* -- the fill value is the mean over non-missing values, and
observed values are untouched. It deliberately does **not** inherit the macro's
*defaults*: `vars` is required where `PROC STANDARD` would process every
numeric column, and `impute_multiple()` will require `m`. There is no "the SAS
default" to inherit -- five macro names exist in copies declaring different
`NIMPUTE` defaults, three of them straddling 1. Know which side of that line a
change falls on before claiming it matches SAS.

This file is the operational contract and applies in full. It is tool neutral, so Codex and
any other agent read the same rules. Claude Code affordances live in `CLAUDE.md`, which
imports this file.

## Definition of done

- `devtools::test()` passes. The runner is `tests/testthat.R`.
- `devtools::check()` is **0 errors, 0 warnings, 0 notes**.
- `devtools::document()` has been run and `man/` and `NAMESPACE` are committed with the
  source change.
- Any divergence from the macro is in the roxygen, under **Divergences from SAS**, and
  says *why* -- not just that it differs.

## The automated gates

Six workflows, now level with the rest of the family: the PDF-manual and pkgdown
gates arrived in 0.1.1.

| workflow | fails on |
|---|---|
| `R-CMD-check.yaml` | `R CMD check` across platforms |
| `check-manual.yaml` | `R CMD check --as-cran` **with the manual built** |
| `pkgdown.yaml` | the site build, including any exported topic missing from `_pkgdown.yml`'s reference index |
| `lint.yaml` | `lintr::lint_package()` |
| `house-style.yaml` | the composed house style |
| `test-coverage.yaml` | coverage upload |

Two things worth knowing about the pkgdown gate, both learned the hard way:

- **A new export fails the build until it is in the reference index.** That is the
  gate working, not an obstacle — an undocumented export is the thing it exists to
  catch. Add it to `_pkgdown.yml` in the same PR.
- **The site builds into `pkgdown-site/`, not `docs/`.** `docs/` holds this project's
  plans and specs, and pkgdown rightly refuses to build over a directory it did not
  create — with the deploy step's settings it would have published the plans as the
  package site. `build_site_github_pages()` takes `dest_dir = "docs"` as an explicit
  default that **overrides** `destination:` in `_pkgdown.yml`, so the workflow passes
  it directly.

## Rules for this repo

**R1. Two functions, never one `impute()`.** 223 studies call single mean
imputation, 326 call multiple, 18 call both. A single `impute()` that quietly
does one when the caller expected the other is a worse failure than no package
at all, and a `method=` argument with a default is exactly that failure wearing
an argument name. Adding one is not an API convenience; it is the defect.

**R2. No default is inherited from SAS, and every default this package has says
it is ours.** Documenting a default as "matches SAS" would be false: SAS did
more than one thing. If a default is chosen because a plurality of call sites
used it, the documentation says exactly that, and says it is a choice.

**R3. `m` is never given a plurality default.** Three of the five divergent
macro names straddle `NIMPUTE=1`, so a default of 5 would silently convert a
single-imputation call site into multiple imputation. That is a change of
method under an unchanged call, not a conservative error in either direction.
This follows Migration Principle #5 (union of behaviours, exposed as
arguments), which forbids picking one copy as canonical.

**R4. The record is a per-cell matrix, and a count never replaces it.** A
summary saying "12 values imputed" cannot answer *was this patient's value
imputed?*. `summary()` is a view of the matrix; anything that would make the
matrix optional is out.

**R5. `complete_case_pass` is read from the input, before anything is filled.**
Evaluated on the completed data, every row over `vars` passes by construction
and the column silently reports the wrong answer with no error. It has a
regression test named for this; do not remove it.

**R6. Fail loud on anything ambiguous.** An all-missing variable, a
non-numeric variable, an unknown or duplicated name, a zero-row frame: all
errors. There is no path through this package that imputes fewer variables than
asked, or leaves a value missing and reports it as filled. The record is only
worth having if it can be trusted against an audit.

**R7. Indicators are generated, not stored, and `ms_` is not the default.** A
convention adopted for parity becomes permanent the moment a study depends on
it. The record is the single source of truth and the prefix is the caller's
choice. The principle underneath is not negotiable: a value that means
"observed" and a value that means "filled in" must not be the same value.

**R8. Nothing is built against the CONSORT annotation stage until
[hvtiPlotR#131](https://github.com/ehrlinger/hvtiPlotR/issues/131) lands.**
`imputed_any()` and `complete_case_pass()` are the stable half of that
contract. The stage constructor is not, and guessing at its interface is how
the first draft of that design silently resurrected excluded patients.

## Gotchas

- **`PROC STANDARD MEAN=0 STD=1 REPLACE` is a different operation.** It
  standardises *and* fills -- in standardised units the fill value 0 is the
  mean, so it is imputation too, but it rescales observed values as well.
  `impute_mean()` is not a substitute for it. A study that used it is not
  reproduced by this package.
- **`PROC STANDARD` without `REPLACE` is not imputation at all.**
  Standardisation only. The corpus scan
  (`hvtiRdatabuild/dev/specs/artifacts/imputation-method-scan.R`) separates
  the three cases; read it before adding a fourth.
- **A study being reproduced takes its `m` from that study's own saved
  output, never from the macro it called.** The macro cannot tell you; the log
  can.
- **Filling an integer column returns a double.** The mean is rarely integral
  and R widens the column on assignment. This is correct and matches what
  `PROC STANDARD` writes, but it will surprise a caller comparing types.

## Git and versioning

✅ **The `protect main` ruleset is live here as of 2026-09-08**, created by
copying `hvtiRbootstrap`'s live definition from the API rather than retyping
it, and verified back from
`GET /repos/ehrlinger/hvtiRimputation/rulesets/22556413`: five rules, eight
required checks pinned to `integration_id` 15368, zero required approvals, and
the `RepositoryRole` 5 bypass at mode `always`. Everything below therefore
applies in full. Re-read it from the API rather than from this paragraph -- the
entry in the sibling repos was wrong for two weeks precisely because it was
written from memory.

- **Never push to `main`.** Branch, then open a PR and let the maintainer merge.
- **`main` is protected by a GitHub ruleset, and nothing in this repo records that.** A clone
  shows no trace of it, so it is stated here. The ruleset is named `protect main`, is
  identical across all twelve repositories in the HVTI R package family, and enforces four
  rules on the default branch: no deletion, no force-push, pull-request-only, and an
  **automatic Copilot code review** on every PR. A rejected push comes from the server, not a
  local hook.
  ⚠️ This entry was wrong until 2026-09-03 and is now read from the API rather than from
  memory. It had said **zero approvals**; the ruleset in fact required **1**, which on a
  single-maintainer repo nobody can satisfy -- GitHub forbids self-approval, and Copilot
  only ever leaves `COMMENTED`, never `APPROVED`. Every merge was therefore an `--admin`
  override. `required_approving_review_count` was set to **0** on 2026-09-03 so that
  `gh pr merge` works normally. `require_code_owner_review` is `false` (and there is still
  no `CODEOWNERS` file), while `require_extra_approval_for_unattributed_changes` is `true`.
  ⚠️ **The maintainer already bypasses this ruleset completely.** The single bypass actor is
  `RepositoryRole` 5 -- admin -- at mode `always`, and
  `GET /repos/:o/:r/rulesets/rule-suites` shows `result=bypass` for every one of the
  maintainer's updates to `main`. Bypass governs the **ref update**; the approval
  requirement was enforced separately at **merge** time, which is why a full bypass still
  left `--admin` as the only way through. Adding a bypass actor would have been a no-op.
  **CI gates merges as of 2026-09-03.** Until then there was no `required_status_checks`
  rule at all: all nine workflows ran on a pull request and none of them blocked it, so a
  red `R CMD check` was exactly as mergeable as a green one, and the only gate was the
  approval count nobody could satisfy. Eight contexts are now required -- `lint`,
  `house-style`, `pkgdown` and the five `R-CMD-check` matrix jobs -- each pinned to the
  GitHub Actions app (`integration_id` 15368) so nothing else reporting a same-named check
  can satisfy the gate. `strict_required_status_checks_policy` is `false`, so a branch need
  not be up to date with `main` before merging.
  ⚠️ `test-coverage` is deliberately **not** required. It uploads to codecov and fails on
  network and token problems, which would block merges for reasons that say nothing about
  the package.
  ⚠️ **A required check must run on every pull request, or the branch deadlocks.**
  `R-CMD-check.yaml` and `pkgdown.yaml` used to carry `paths-ignore: ['.claude/**']` on
  their `pull_request` trigger, to save runner minutes on house-style recomposes. A
  required check that never runs never reports, and one that never reports can never pass,
  so a `.claude/**`-only pull request would have been permanently unmergeable -- and that
  is a real shape here, since `chore: recompose the house style artifact` touches exactly
  `.claude/house-style.md` and reaches `main` through a pull request. The filter was moved
  to `push` only. **Do not reinstate it on `pull_request`, and do not require a check that
  any path filter can skip.**
  ⚠️ The maintainer's admin bypass means none of this gates *them*: a red check does not
  block a bypassing actor. It protects the branch from accident and from everyone else.
  ⚠️ **An approval survives later pushes, and Copilot does not re-review them.**
  `dismiss_stale_reviews_on_push` and `require_last_push_approval` are both `false`, and the
  `copilot_code_review` rule sets `review_on_push: false`. So a pull request can be reviewed,
  then changed, then merged with neither a fresh approval nor a fresh Copilot pass over what
  actually merged. That is not hypothetical: #34 merged at the commit that predated its own
  fix push, and the fix had to be re-landed as #36. **Check that the merge commit is the one
  you meant**, and re-request review by hand after a substantive push.
  Copilot review is also not perfectly reliable at PR creation -- #35 got none until it was
  requested by hand, and `review_draft_pull_requests: false` does not explain it, since #35
  was never a draft. `gh pr edit --add-reviewer` cannot do it: that routes through
  `requestReviewsByLogin`, which does not resolve bots, and the REST `requested_reviewers`
  endpoint returns **200 while silently doing nothing**. What works is the GraphQL
  `requestReviews` mutation with `botIds`, taking the bot's node id from a review it has
  already left (`.user.node_id` on any Copilot review). Note that the `copilot-swe-agent`
  actor returned by `suggestedActors` is the *coding* agent, not the reviewer.
  One bypass actor is configured (`RepositoryRole` 5, mode `always`). Which role that id
  names could not be determined from the API on a personal account, and it was not tested,
  because the only test is a push to `main`. Read it off the ruleset UI, which names the
  role in words, before assuming the protection is absolute.
- Versions are **straight three digits** (`0.1.0`). Never a `.9000` suffix or a fourth digit.
- **Patch-digit bumps only.** Minor and major are the maintainer's decision.
- **Bump when you tag, not when you merge.** `DESCRIPTION` and the top `NEWS.md` heading
  must always match -- `tests/testthat/test-package.R` checks for exactly that -- but
  matching is the whole requirement, and it does not ask the number to be new. So while
  the top heading is a version that was never tagged, work lands as **bullets under it**
  rather than under a heading of its own.
  ⚠️ This bullet used to say to bump in the same commit as the change, which reads as once
  per PR. That mints versions nobody installs. As of 2026-09-01, 0.9.1 and 0.9.2 had both
  landed in a single afternoon while `v0.1.1` and `v0.9.0` were the only tags in the repo
  -- a snapshot, not a standing claim, and the state that prompted this rewording. The
  precedent is 0.9.0's own notes, which folded 0.1.2's entries in "rather than split
  across two version numbers"; this is that rule applied before the fact instead of after.
  The cost is real and worth paying: two branches adding bullets to the same heading
  conflict in `NEWS.md`. That is one small conflict per PR.

## Change discipline

1. **Think before coding.** Do not assume, ask. If the request is ambiguous or a name, path
   or signature is uncertain, surface the confusion rather than running with a guess.
2. **Simplicity first.** Write the minimum that solves the stated problem.
3. **Surgical changes.** Touch only what the task requires. Raise nearby problems separately.
4. **Goal-driven execution.** State what done looks like before starting, and use tests as the
   criterion. For anything touching selection frequencies, "done" includes checking that the
   `NA` semantics survived.

## Prose

Documentation prose follows the house voice. Every exported function's roxygen names the
macro it ports and the parameter it replaces — a reader arriving from SAS needs that mapping
more than they need an abstract description.
