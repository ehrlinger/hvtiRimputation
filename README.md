# hvtiRimputation — fill missing values, and say exactly what you filled

<!-- badges: start -->
[![R-CMD-check](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ehrlinger/hvtiRimputation/branch/main/graph/badge.svg)](https://app.codecov.io/gh/ehrlinger/hvtiRimputation?branch=main)
[![Project Status: WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![pkgdown](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/pkgdown.yaml)
![GitHub R package version](https://img.shields.io/github/r-package/v/ehrlinger/hvtiRimputation)
[![lint](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/lint.yaml/badge.svg)](https://github.com/ehrlinger/hvtiRimputation/actions/workflows/lint.yaml)
<!-- badges: end -->

> **A SAS port.** `impute_mean()` is the R form of `PROC STANDARD ... REPLACE`,
> which the CORR library's `imputsub` macro wraps. It is held to the macro's
> *arithmetic* — the fill value is the mean over non-missing values, and
> observed values are never touched — and deliberately not to its *defaults*.
> Where this package diverges it says so in the function's own help, under
> **Divergences from SAS**. See [What this promises about reproducing
> SAS](#what-this-promises-about-reproducing-sas), which is a shorter list than
> you might expect.

## Status

**v0.1.0. Single mean imputation only.**

| Piece | State |
|---|---|
| `impute_mean()` — single mean imputation (`PROC STANDARD REPLACE`, `imputsub`) | ✅ implemented |
| The record: per-cell matrix, generated indicators, provenance | ✅ implemented |
| `imputed_any()` / `complete_case_pass()` — the row-level attrition columns | ✅ implemented |
| `impute_multiple()` — multiple imputation (`PROC MI`, `mult_imput`) | ⛔ designed, not built |
| Pooling (Rubin's rules) | ⛔ deferred — multiple imputation is only multiple imputation if the results are pooled, and that is separate work with its own verification |
| The CONSORT annotation stage | ⛔ blocked on [hvtiPlotR#131](https://github.com/ehrlinger/hvtiPlotR/issues/131) |
| `BY`-group means | ⛔ not measured, not built |
| `PROC STANDARD MEAN=0 STD=1 REPLACE` (standardise *and* fill) | ⛔ not built |

## What it does

Takes a data frame, fills its missing values by a stated method, and hands back
the filled data **together with a record of exactly what it changed**.

It knows nothing about the warehouse, the build, or any study. That is the
whole scope: a data frame in, a data frame and a record out. Any study,
manifest or provenance context belongs to the caller.

**Full documentation:** <https://ehrlinger.github.io/hvtiRimputation/>

## Installation

```r
# install.packages("pak")
pak::pak("ehrlinger/hvtiRimputation")
```

## Quick start

```r
library(hvtiRimputation)

dat <- data.frame(
  age     = c(50, 60, NA, 70),
  bmi     = c(NA, 25, 27, 29),
  outcome = c(1, 0, 1, NA)
)

out <- impute_mean(dat, vars = c("age", "bmi"))

imputed_data(out)     # the completed frame
imputed_matrix(out)   # TRUE where a value was filled
summary(out)          # per-variable counts and fill values
```

The two row-level columns the attrition record wants:

```r
imputed_any(out)         # did this row have anything filled?
complete_case_pass(out)  # would this row have survived listwise deletion?

# Rows in the analysis ONLY because a covariate was filled in:
sum(imputed_any(out) & !complete_case_pass(out))
```

That last number is the one worth checking a port against. A port that
mean-imputes the **wrong variable list** still reaches the right row count and
still looks correct — it does not reach the right count here.

Missingness indicators, for carrying "this was missing" into a model:

```r
imputation_indicators(out)                  # imputed_age, imputed_bmi
imputation_indicators(out, prefix = "ms_")  # ms_age, ms_bmi, as SAS named them
```

## Function reference

### Imputation

| Function | What it does |
|---|---|
| `impute_mean()` | Fill each missing value with its variable's mean. One completed dataset. |

### Reading the record

| Function | What it does |
|---|---|
| `imputed_data()` | The completed data frame |
| `imputed_matrix()` | Logical matrix, one row per row and one column per imputed variable, `TRUE` where filled |
| `imputed_any()` | Row-level: did this row have any value filled? |
| `complete_case_pass()` | Row-level: would this row have survived listwise deletion? |
| `imputation_indicators()` | Missingness indicator columns, generated from the record, with the prefix you choose |
| `imputation_provenance()` | Method, `m`, fill values, package version, seed |
| `summary()` | Per-variable counts and fill values — a view of the record, never a replacement for it |

## Design notes

### Two functions, never one `impute()`

223 studies in the corpus call single mean imputation, 326 call multiple
imputation, and 18 call both. They are different methods with different
inferential properties.

So this package will expose two functions rather than one function with a
`method=` argument. A single `impute()` that quietly does one when the caller
expected the other is a worse failure than no package at all, and a `method=`
argument with a default is exactly that failure wearing an argument name. Two
functions cannot be confused by omission.

### Nothing inherits a SAS default

`impute_mean()` requires `vars`, though `PROC STANDARD` with no `VAR` statement
processes every numeric column. `impute_multiple()` will require `m`, though
the macros carry `NIMPUTE` defaults.

The reason is that **there is no "the SAS default" to inherit.** Five macro
names exist in copies declaring different `NIMPUTE` defaults, and three of the
five straddle 1 — so a plurality default would silently convert a
single-imputation call site into multiple imputation. That is not a
conservative error in one direction; it is a change of method under an
unchanged call. Where this package has a default it is **ours**, and the
documentation says so rather than claiming parity.

### The record is a matrix, not a count

One row per row of the input, one column per imputed variable, `TRUE` where the
value was filled.

A summary saying "12 values were imputed in this variable" cannot answer *was
this patient's value imputed?*, which is the question an audit asks. The matrix
answers it directly and reduces to any count; the reverse is impossible.

Indicators are **generated** from that record rather than stored, and the SAS
`ms_*` naming is not the default. A convention adopted for parity becomes
permanent — it would be ours to maintain forever the moment a study depended on
it. The principle underneath is not negotiable and predates the naming: **a
value that means "observed" and a value that means "filled in" must not be the
same value.**

### Imputation is an annotation, not an exclusion

Rows kept only because a covariate was filled in are not excluded, and they are
not fully observed either. A record with no vocabulary for that third state
will misreport one or the other.

So `imputed_any()` and `complete_case_pass()` are meant to enter a CONSORT
tracker as an **annotation stage** — one that records something about the rows
without removing any. The two columns are the stable half of that contract and
are available now; the stage constructor itself is
[hvtiPlotR#131](https://github.com/ehrlinger/hvtiPlotR/issues/131) and nothing
here is built against a guess at its interface.

## What this promises about reproducing SAS

Three tiers, and this package will not blur them.

**Known.** 292 call sites state their `NIMPUTE` value outright. For those the
method and `m` are facts, and an R run can be checked against the study's saved
output.

**Inferred, pending validation.** 518 more are settled only by the copy of the
macro sitting in the calling study. That is strong evidence and not proof:
which copy SAS loaded depends on the autocall path and `%include` order at run
time. Reproducing one of these studies means confirming `m` against that
study's saved log **first**.

**Not promised.** Any general "reproduces the SAS corpus" guarantee. 129 of 939
calls cannot be attributed to a method from the code at all — 38 because the
study's own copies disagree with each other, and 91 because the calling study
holds no copy and the corpus-wide definitions conflict.

⚠️ That bound is a property of the corpus, not of this package, and no
implementation choice lifts it. **A study being reproduced takes its `m` from
that study's own saved output, never from the macro it called.** The macro
cannot tell you; the log can.

## Related packages

| Package | Relationship |
|---|---|
| [hvtiRdatabuild](https://github.com/ehrlinger/hvtiRdatabuild) | Where the design specs live. **No dependency in either direction** — imputation is a method, not a build step, and a method package that took a build-layer dependency would drag the warehouse credential ladder into every job that wanted to fill a column |
| [hvtiPlotR](https://github.com/ehrlinger/hvtiPlotR) | Owns the CONSORT tracker the two row-level columns feed |
| [hvtiRbootstrap](https://github.com/ehrlinger/hvtiRbootstrap) | Sibling method package, same shape: a method, its record, and its provenance |
