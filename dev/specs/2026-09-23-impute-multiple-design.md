# `impute_multiple()` design

Status: prototype implemented, not released. Pooling (Rubin's rules) remains
out of scope, per the README.

## Motivation

`impute_multiple()` is the second of the two functions this package's own
design promises (`README.md`, "Two functions, never one `impute()`"):
`impute_mean()` for single mean imputation, `impute_multiple()` for multiple
imputation by chained equations. It has been "designed, not built" since
`0.1.0`.

The immediate trigger was a reported symptom in a downstream study: MICE
appearing to impute a categorical variable to a value that is not one of its
actual levels -- an average where a category should be. That symptom was
investigated empirically (not just reasoned about) before this design was
written, because the two most obvious explanations turned out to be wrong,
and the real mechanism changes what `impute_multiple()` has to guard against.

### What was tested, and what actually reproduces the symptom

Using `mice` 3.19.0, a categorical variable was imputed in three column
states -- raw numeric codes, a converted unordered factor, and a converted
logical -- both with a single method string forced across every column (the
way an existing downstream study calls `mice::mice()`) and with `mice`'s own
per-column default method selection (`mice::make.method()`). In every one of
these six combinations, **every value in every completed dataset was a real
donor or model-consistent value inside the variable's valid level set.**
Predictive mean matching cannot manufacture a value between categories --
that is the entire point of donor matching -- and neither can `logreg` or
`polyreg`. Forcing `pmm` on an unconverted numeric column produced the same
valid values as auto-selecting `pmm` for it, and forcing `pmm` on a factor
produced the same valid values as auto-selecting `polyreg`. Column type at
imputation time, and method forced-vs-defaulted, were both ruled out as the
source of the "average" symptom. (Scripts: `repro_mice_bug.R`, kept alongside
this design's supporting evidence rather than committed as package code --
they exercise `mice` directly, not this package.)

**What does reproduce it, exactly:** naively averaging the *m* completed
datasets from `mice(..., m > 1)` cell by cell. In a minimal reproduction (a
4-level factor, `m = 5`, `pmm`), every one of the 5 individual completed
datasets was valid -- levels 0 through 3 only. Averaging the 5 numeric-coded
draws per cell (`rowMeans()` over `sapply(1:m, \(i) as.integer(as.character(
complete(imp, i)$var)))`, the shape of code that treats `mice::complete()`'s
output like `m` numbers to reduce rather than `m` categorical draws to
combine) put 29 of 50 imputed cells -- 58% -- strictly between valid levels.
(Script: `repro_pooling_bug.R`.) That is exactly the reported symptom, and it
arises only once `m > 1` (a downstream study running true multiple
imputation), never at `m = 1` (this package's `impute_mean()`, or a study
that runs `mice` for its convenience but draws one dataset).

The conclusion this forces: **the bug is not inside `mice`, and it is not a
column-type problem for `impute_multiple()` to fix by choosing methods more
carefully.** It is a pooling-shaped trap that sits immediately downstream of
any function that hands back `m` completed datasets without pooling them --
which is exactly what `impute_multiple()` is scoped to do, per the README's
own deferral of Rubin's-rules pooling as separate work. So the design's job
is not "impute more carefully"; every method `mice` offers already does that
correctly. The job is to make the naive-average path structurally hard to
reach by accident, and to say loudly, in the one place a caller is about to
take *m* completed datasets and do something with them, that averaging raw
values is not that something.

### A second, smaller, real finding

Independently: when `mice` auto-selects `logreg` for a 2-level `logical`
column (its own default for that class), `complete()` returns the completed
column as plain numeric `0`/`1`, not `logical` -- the class is lost. This did
**not** happen when `pmm` was forced on the same logical column instead; only
`logreg` loses it. This is a real class-fidelity gap between `mice` and a
`logical` input, but it produces valid values with the wrong class (`0`/`1`,
not `TRUE`/`FALSE`), not values outside the valid set. It is unrelated to the
"average" symptom, and is handled below as its own guard.

### A third finding, upstream of imputation entirely

While constructing test columns for the above, a **data-corruption bug in
`hvtiRutilities::r_data_types()`** was found and confirmed: any 2-distinct-
value numeric column converts to `logical` via `as.logical()`, which maps
every nonzero code to `TRUE`. A SAS-style `1`/`2` code -- including
`hvtiRutilities::sample_data()`'s own `boolean` column, documented as
"Integer 1/2" -- silently collapsed to a single `TRUE` value for every row,
with no error or warning. This has nothing to do with `mice` and predates
imputation entirely: it corrupts the data before `impute_multiple()` ever
sees it. Fixed directly, since it strengthens exactly the composition this
design depends on (see "Composition with `r_data_types()`" below):
[ehrlinger/hvtiRutilities#142](https://github.com/ehrlinger/hvtiRutilities/pull/142).
`r_data_types()` now converts to `logical` only when the two values are
actually `0` and `1`; any other 2-distinct-value coding becomes a factor
unconditionally, in both `binary_factor` settings.

## API

```r
impute_multiple(
  data,
  vars,
  m,
  cc_vars = names(data),
  method  = NULL,
  maxit   = 5L,
  seed    = NA_integer_
)
```

- **`vars` and `m` are both required, with no default.** Same reasoning as
  `impute_mean()`'s required `vars`: an imputation that silently chose its
  own variable list, or its own `m`, is the failure the record in this
  package exists to catch. The README already commits to `m` having no
  inherited default, for the same reason `vars` doesn't: the SAS corpus's
  `NIMPUTE` defaults disagree across macro copies, so there is no single "the
  default" to port.
- **`method` defaults to `NULL`**, meaning `mice::make.method(data[vars])`:
  `pmm` for numeric, `logreg` for a 2-level factor, `polyreg` for an unordered
  factor with more than two levels, `polr` for an ordered factor. This is
  `mice`'s own per-column dispatch, not a choice this package invents, and it
  is **never one string applied to every column** -- that is the shape of
  call this design's own investigation shows is *not* the source of the
  reported bug, but forcing a single method across mixed column types is
  still the wrong default to hand a caller, because it silently discards
  distinctions `mice` already knows how to make. A caller who wants to
  override specific columns passes a **named character vector** (e.g.
  `method = c(stage = "polr")`), covering only the columns being overridden;
  every other column still gets its `make.method()` default. There is no
  single-string form: forcing one method across every column, as the
  downstream study's own `mice-full` chunk does, is a decision `mice` already
  makes correctly per column, and re-deciding it as one string is exactly the
  kind of silent, package-wide default this codebase's design philosophy
  rejects elsewhere (`vars`, `m`).
- **`vars` accepts numeric, factor, and logical columns**, not numeric only
  (unlike `impute_mean()`, which is inherently a numeric-only operation).
  Character columns are refused, the same way `impute_mean()` refuses
  non-numeric: converting a character column to a category is a method
  choice (what are the levels, in what order), and `impute_multiple()` does
  not make it silently. The caller converts with `factor()` or
  `r_data_types()` first. Classed numerics (`Date`, `POSIXct`, `integer64`)
  are refused for the same reason `impute_mean()` refuses them: they pass
  `is.numeric()` while carrying storage rules `mice`'s `pmm` does not know
  about it.

## Composition with `r_data_types()`

`impute_multiple()` **trusts column class as the sole signal for "is this
categorical," and does not re-derive it.** It does not look at
`n_distinct()`, and it does not carry its own `factor_size`-shaped threshold.
This mirrors `impute_mean()`'s own posture toward classed numerics: the
function trusts `is.numeric()` and a class-attribute guard, not a second,
competing type-inference pass. Making the type decision twice, once in
`r_data_types()` and again inside the imputation call, is exactly the
failure mode the SAS corpus warning at the top of this package's README
describes for `m`: two decision points that can silently disagree, with no
way for the record to say which one governed.

This makes what a column *is* by the time it reaches `impute_multiple()`
`r_data_types()`'s job, not this function's, and is precisely why the
`r_data_types()` fix above matters to this design and not just to
`hvtiRutilities` generally: a caller who runs `r_data_types()` then
`impute_multiple()` on a 1/2-coded sex column, before the fix, would have
had `impute_multiple()` faithfully impute a column that had already been
silently reduced to a single constant value. `impute_multiple()` cannot see
that failure from where it sits; it can only trust the type it is handed.

## The `hvti_imputation_multi` class

A **new class**, not a reshaped `hvti_imputation`. The existing README
principle -- "two functions, never one `impute()` ... a function that
quietly does one when the caller expected the other is a worse failure than
no function at all" -- applies exactly as much to the return value as to the
function name. `imputed_data(x)`'s documented contract is "a data frame";
silently changing what that means for some inputs (a list, or a long frame,
depending on which function produced `x`) is the same failure in accessor
form. `impute_mean()`'s contract is untouched by this design.

### Storage

```
list(
  data_long          = <data frame, .imp, .id, then vars in original order>,
  matrix             = <logical matrix, nrow(data) x length(vars)>,
  complete_case_pass = <logical vector, length nrow(data)>,
  analysis_pass      = <logical vector, length nrow(data)>,
  provenance         = <list>
)
```

Two shapes were considered for the *m* completed datasets: a list of *m*
data frames, or one long, stacked frame with `.imp`/`.id` columns (the shape
`mice::complete(imp, "long")` already returns, and the shape SAS's
`PROC MI OUT=` produces -- an unforced parity point for the persona (c)
reader this package's SAS-migration framing is written for). **Long wins**,
for a reason specific to this package's own design language: the record is
meant to reduce, never to require reconstruction (`hvti_imputation`'s own
`@section Why a matrix and not a count`). A list of *m* frames does not
reduce to a single completed dataset without picking one out of the list by
position; a long frame reduces to one with a single `filter(.imp == 1)`
subset, and reduces to the pooling-ready form (one row per original
observation per draw) that any correct downstream analysis -- fit per draw,
pool the fits -- already expects.

**`matrix`, `complete_case_pass`, and `analysis_pass` are not lists.** This
is not a simplification made for convenience; it is a fact about what `mice`
guarantees. Which cells were originally missing does not change across the
*m* draws -- only what they were filled *with* does -- so `matrix` is
identical for every draw and is stored once. `complete_case_pass` is read
from the input before any imputation runs, so it is trivially the same for
every draw. `analysis_pass` is less obvious but still invariant: `mice`
guarantees every column that entered the imputation is complete in every
draw, so `complete.cases()` over `cc_vars` evaluates identically regardless
of which draw's values are substituted in. Storing three lists of *m*
identical vectors each would be a working implementation, but it would
misstate the record: it would let a caller ask "does row 12's analysis-pass
status differ by draw?", a question that cannot have a "yes" for any input
this function accepts, and answering a question that cannot arise is not
what the record is for.

### Accessors

Every existing single-imputation accessor keeps its current signature and
behavior. Two changes, both additive:

- **`imputed_data()` becomes a real S3 generic** (`UseMethod`), the one
  accessor whose contract does genuinely differ by class:
  - `imputed_data.hvti_imputation(x)` -- unchanged, the data frame it always
    returned.
  - `imputed_data.hvti_imputation_multi(x, imputation)` -- **`imputation` is
    required, with no default.** Pass an integer `1:m` for one completed
    dataset, or `"long"` for the full stacked frame. This is the one design
    choice that directly closes the door on the reported bug: there is no
    zero-argument call that hands back something a caller could `rowMeans()`
    over by habit. Requiring the argument is the same "no silently chosen
    default" posture as `vars` and `m`, applied to the one call site where
    the wrong silent choice would reproduce the exact symptom this design
    was written against.
  - The other seven accessors (`imputed_matrix`, `imputed_any`,
    `complete_case_pass`, `analysis_pass`, `kept_by_imputation`,
    `imputation_provenance`, `imputation_indicators`) are **not** converted to
    generics. Their bodies are identical for both classes -- they read
    `x$matrix`, `x$complete_case_pass`, `x$analysis_pass`, `x$provenance`,
    all stored in the same shape by both classes -- so the only change
    needed is widening each function's existing `stopifnot(inherits(x,
    "hvti_imputation"))` guard to accept either class. Converting all eight
    to generics for one that needs it would be the kind of unrequested
    abstraction this codebase's own conventions argue against elsewhere.
  - `print.hvti_imputation_multi()` and `summary.hvti_imputation_multi()` are
    new methods (both already true S3 generics in base R). `summary` reports
    per-variable method and imputed-count/proportion, the multi-imputation
    analog of `summary.hvti_imputation()` -- it has no single `fill_value`
    to report, since each draw can fill a given cell differently.

### The logical-class-loss guard

After `mice::complete()`, any column that entered as `logical` is coerced
back to `logical` explicitly and the result is asserted, mirroring
`impute-mean.R`'s own existing idiom for its post-imputation invariant ("the
record claims these cells were filled. Prove it, rather than trusting..."):
`mice` only loses the class when it auto-selects `logreg` for that column,
not when `pmm` is forced on it, so this cannot be left as an assumption.

## What this does not do

- **No pooling.** `impute_multiple()` returns *m* valid completed datasets
  and the record of how they were produced. Combining them into a single
  inferential answer -- Rubin's rules on model coefficients fit separately to
  each draw -- is the caller's job, exactly as the README already commits:
  "multiple imputation is only multiple imputation if the results are
  pooled, and that is separate work with its own verification." This design
  does not change that scope; if anything, the reproduction above is the
  concrete argument for why pooling deserves its own verification rather
  than being folded in here as a convenience.
- **No `BY`-group imputation.** Same gap `impute_mean()` already documents;
  unmeasured in the corpus, not built here either.
- **No change to `impute_mean()`'s contract, file, or tests**, beyond the
  two accessor-guard widenings described above.

## Test plan

- Each of the *m* completed datasets returned by a prototype call contains
  only valid levels for a factor `vars` column -- the property the
  investigation showed always holds, made into a standing regression test
  rather than left as a one-off finding.
- `imputed_data(x)` with no `imputation` argument errors, for the multi
  class specifically (the single-imputation class's zero-argument form is
  untouched and still passes).
- `imputed_data(x, "long")` has `.imp` ranging `1:m`, `.id` ranging
  `1:nrow(data)`, and the non-imputed columns identical across every `.imp`
  group.
- A mixed `vars` list (numeric + unordered factor + logical) gets three
  different methods from the default `NULL`, matching
  `mice::make.method()`'s own per-column choices -- demonstrating the
  "never one string" requirement holds, not just that it is documented.
- A `logical` `vars` column round-trips as `logical` in every one of the *m*
  completed datasets, including under `mice`'s own default (`logreg`)
  method, where the class would otherwise be lost.
- `imputed_matrix()`, `complete_case_pass()`, and `analysis_pass()` each
  return a plain vector/matrix (not a list of length `m`) from a multi-class
  object.
