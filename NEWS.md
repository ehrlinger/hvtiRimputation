# hvtiRimputation 0.1.5

* **The `predictors` deprecation announced in 0.1.4 takes effect.** 0.1.4
  made `predictors` a required argument of `impute_multiple()` and said a
  call without it would warn for one release and then be an error. This is
  that release: such a call now fails with an error of class
  `hvtiRimputation_invalid_input`, where 0.1.4 ran it outcome-free with a
  once-per-session warning. To keep the outcome-free behaviour, pass
  `predictors = character(0)`; for an association analysis, pass the outcome
  instead. The warning class `hvtiRimputation_deprecated` is gone with the
  warning.

* The maintainer address is `john.ehrlinger@gmail.com`, as in the rest of the
  hvtiR family.

* The package help, README, vignette and `Description` no longer call
  `impute_multiple()` unbuilt or unreleased. It has shipped since 0.1.1; the
  README's status line said v0.1.0 and its function table left it out.

# hvtiRimputation 0.1.4

* **`impute_multiple()` gains a required `predictors` argument.** Columns
  named there enter the `mice` model and inform every draw, and are never
  imputed. For an association analysis the outcome belongs there (time and
  status, for a survival outcome); otherwise every filled value is drawn as
  though it had no relationship to the outcome, and the estimated
  associations are biased toward the null. `predictors = character(0)` is the
  explicit outcome-free choice, defensible for a prediction model. A call
  without `predictors` runs as before with a once-per-session warning (class
  `hvtiRimputation_deprecated`); in the next release it is an error. Each
  predictor must be fully observed, plain numeric, factor or logical, not
  constant, and not also in `vars`.

* `impute_multiple()` validates `maxit` as a single positive whole number,
  instead of failing inside `mice` with an error about array lengths.

* `impute_multiple()` refuses an all-missing or constant `vars` column
  before calling `mice`, and when `mice` drops a column as collinear it
  reports the reason from `mice`'s `loggedEvents` rather than calling it a
  bug in this package. A predictor `mice` drops draws a warning.

* `impute_mean()` keeps a fully observed integer column integer, and says so
  (through a message `options(hvti.quiet = TRUE)` silences) when it widens a
  filled integer column to double.

* A column in `vars` or `predictors` that looks like a row identifier (named
  `id`, or ending `_id` or `.id`, with every observed value distinct) draws a
  warning of class `hvtiRimputation_id_like`.

* The accessors refuse a non-imputation object with a message naming what
  they expected, instead of a bare `stopifnot()` failure.

* `predictors` is the last formal of `impute_multiple()`, so a call written
  before it existed keeps its positional meaning. One variable in `vars` is
  enough when `predictors` supplies a second column. A predictor `mice` drops
  from a single model (linearly dependent among the rows where that model's
  target is observed) draws a warning naming the column, the target and the
  number of fits, and every event `mice` logged is kept in the provenance as
  `logged_events`.

* Every error now carries a condition class, `hvtiRimputation_error` plus a
  specific one: `hvtiRimputation_invalid_input` for an argument or column
  refused before anything is filled, `hvtiRimputation_unfilled` for a value
  the record would mark filled that is still missing. Catch by class rather
  than by message text. Messages are unchanged.

* `imputation_provenance()` opens with the seven fields the hvtiR packages
  share, in the same order and types from both `impute_mean()` and
  `impute_multiple()`: `package`, `version`, `sha` (new; the install's
  commit when recorded, else `NA`), `method`, `seed`, `rng_kind` (new; `NA`
  for mean imputation, which draws nothing) and `time`. Package-specific
  fields follow, as before.

* `summary()` of an `impute_mean()` result gains a `method` column, and
  `summary()` of an `impute_multiple()` result gains `fill_value`, always
  `NA` because no single value speaks for every draw. The two tables now
  have the same columns and bind with `rbind()`.

* The package description quotes 'SAS' and spells out CORR and HVTI.

* `?summary.hvti_imputation` and `?summary.hvti_imputation_multi` link
  `rbind()` to base R's, not to `mice`'s.

# hvtiRimputation 0.1.3

* `DESCRIPTION` now declares the Quarto command line tool in
  `SystemRequirements`, which the new vignette needs to build.

* New Overview vignette, `vignette("hvtiRimputation")`. It walks one small
  synthetic example from `impute_mean()` through the record, the row-level
  attrition columns, indicators, provenance and the inputs the package
  refuses, then shows the `impute_multiple()` prototype. On the pkgdown site,
  articles put the table of contents on the left and use the full window
  width, through `pkgdown/extra.css`. `quarto` and `knitr` join `Suggests`.

# hvtiRimputation 0.1.2

* **`impute_multiple()` is now reproducible by default (breaking).** `seed`
  is required, either as an argument or once per session through
  `options(hvtiRimputation.seed = )`; with neither, the call fails. The old
  default, `seed = NA`, left the draws to whatever state R's RNG happened to
  be in. The `mice` call now runs under `withr::with_seed()` with the RNG kind
  pinned to R's defaults, so the same seed gives the same imputations after
  any `set.seed()` or `RNGkind()` change, and the caller's own random stream
  is restored afterwards. A call that already passed a seed gets the same
  values as before under R's default RNG kind. `withr` is a new import.
* A new test parses `R/` and fails on a call outside `withr::with_seed()` to
  any function in a defined audited set: every `stats` random generator
  (found from the installed `stats` exports, so new ones are covered),
  `sample()`, `jitter()`, `simulate()`, `mice`, `randomForestSRC` and
  `varPro`. It also fails on a `randomForestSRC` call without a negative
  `seed =`, and it self-tests on planted violations. A function that draws
  from the RNG internally without being in that set is outside the audit.
* Now requires R 4.4.0 or newer, up from 4.1.0, to match the rest of the
  HVTI family. `hvtiR::install()` installs the members together, and several
  already required 4.4.0, so on an older R the install failed whatever this
  package declared.

# hvtiRimputation 0.1.1

## New features

* **`impute_multiple()` prototype.** Multiple imputation by chained
  equations (`mice`), returning `m` completed datasets stacked long plus the
  same shape of record `impute_mean()` returns. Method defaults to `mice`'s
  own per-column dispatch (`pmm`/`logreg`/`polyreg`/`polr`) rather than one
  string forced across every column; a named-vector `method` argument
  overrides specific columns. A new class, `hvti_imputation_multi`, keeps
  `impute_mean()`'s own contract untouched. `imputed_data()` is now a real S3
  generic; its `hvti_imputation_multi` method requires an `imputation`
  argument with no default, on purpose -- see
  `dev/specs/2026-09-23-impute-multiple-design.md` for why. Pooling (Rubin's
  rules) remains out of scope, per the design note and the README.

# hvtiRimputation 0.1.0

First release. Single mean imputation, and the record that goes with it.

* The `impute_mean()` help page no longer tells readers to call the designed
  but unimplemented `impute_multiple()` function.
* Coverage uploads without a Codecov token are now best-effort, so a successful
  package test run is not marked failed solely because tokenless upload is
  unavailable.

* **`impute_mean()`** ports `PROC STANDARD ... REPLACE` -- the form with no
  `MEAN=`/`STD=`, which the `imputsub` macro wraps. Missing values are filled
  with the variable's mean over its non-missing values; observed values are
  never touched.
* **The record is a logical matrix parallel to the data**, one column per
  imputed variable, `TRUE` where a value was filled. Read it with
  `imputed_matrix()`. A count cannot answer *was this patient's value
  imputed?*, so the matrix is the primary artifact and `summary()` is a view of
  it rather than a replacement for it.
* **`imputed_any()`, `complete_case_pass()` and `analysis_pass()`** are the
  row-level columns the attrition record consumes. `complete_case_pass()` is
  read from the **input**, before anything is filled -- evaluated on the
  completed data every row over `vars` would pass, which is the opposite of
  what the column means. `analysis_pass()` is the same question after
  imputing.
* **`kept_by_imputation()`** counts the rows in an analysis only because a
  covariate was filled in -- the number that catches a port which imputed the
  wrong variable list yet still reached the right row count.

  ⚠️ **It is `analysis_pass & !complete_case_pass`, not
  `imputed_any & !complete_case_pass`.** The latter overcounts: it is `TRUE`
  for a row that had a value filled but is still incomplete because a column
  outside `vars` is missing, and such a row never enters the analysis at all.
  The two agree only when imputation completes every row, which is the case
  the design was written against -- so the wrong formula gave the right answer
  there and the error was invisible.
* **`imputation_indicators()`** generates missingness indicators from the
  record, with a prefix the caller chooses. The SAS `ms_*` spelling is
  available (`prefix = "ms_"`) and is deliberately not the default: a
  convention adopted for parity becomes permanent.
* **`imputation_provenance()`** records the method, `m`, the fill values, the
  package version and the seed. An imputed dataset that does not say how it was
  imputed cannot be reproduced.

## Divergences from SAS, stated once

* **`vars` is required.** `PROC STANDARD` with no `VAR` statement processes
  every numeric variable in the dataset; that default is not inherited. An
  imputation that silently chose its own variable list is the failure the
  record exists to catch.
* **An all-missing variable is an error, not a pass-through.** There is no mean
  to impute from, and leaving the column as `NA` while reporting it as imputed
  would be a lie in the record.
* **A non-finite mean is an error.** `mean(c(Inf, -Inf), na.rm = TRUE)` is
  `NaN`; filling with it leaves the cell missing while the record marks it
  imputed. An infinite mean is refused in the other direction, as not a
  plausible measurement. The completed column is then asserted to hold no
  missing values, so the invariant is proved rather than assumed.
* **A classed numeric is an error**, even though it passes `is.numeric()`.
  `bit64::integer64` packs a 64-bit integer into a double's bits, so taking
  its mean into an ordinary double reinterprets the bit pattern -- a column of
  1 and 3 completes as 0, with the provenance recording `9.88e-324` rather
  than 2. Wrong data and wrong provenance, no error. The guard keys on the
  class attribute rather than a list of known classes, so it also catches
  whatever the next one is called. Convert with `as.numeric()` yourself, so
  the conversion is a choice you made.
* **Duplicated column names in `data` are an error.** `data[["age"]]` returns
  the first `age`, so naming it fills one column, leaves the other missing,
  and emits a single record column that cannot say which. An audit cannot read
  that.
* **A non-numeric variable is an error.** A mean of a factor or a character
  column is not defined, and guessing one would be a method choice made
  silently.

## Not in this release

`impute_multiple()` (`PROC MI`, `mult_imput`) is designed and not built.
Pooling by Rubin's rules is deferred: multiple imputation is only multiple
imputation if the results are pooled, and that is separate work with its own
verification. `BY`-group means are unmeasured in the corpus and unimplemented.
`PROC STANDARD MEAN=0 STD=1 REPLACE`, which standardises *and* fills, is a
different operation and is not what `impute_mean()` does.
