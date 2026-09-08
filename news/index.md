# Changelog

## hvtiRimputation 0.1.0

First release. Single mean imputation, and the record that goes with it.

- **[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)**
  ports `PROC STANDARD ... REPLACE` – the form with no `MEAN=`/`STD=`,
  which the `imputsub` macro wraps. Missing values are filled with the
  variable’s mean over its non-missing values; observed values are never
  touched.

- **The record is a logical matrix parallel to the data**, one column
  per imputed variable, `TRUE` where a value was filled. Read it with
  [`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md).
  A count cannot answer *was this patient’s value imputed?*, so the
  matrix is the primary artifact and
  [`summary()`](https://rdrr.io/r/base/summary.html) is a view of it
  rather than a replacement for it.

- **[`imputed_any()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md),
  [`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  and
  [`analysis_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)**
  are the row-level columns the attrition record consumes.
  [`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  is read from the **input**, before anything is filled – evaluated on
  the completed data every row over `vars` would pass, which is the
  opposite of what the column means.
  [`analysis_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  is the same question after imputing.

- **[`kept_by_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)**
  counts the rows in an analysis only because a covariate was filled in
  – the number that catches a port which imputed the wrong variable list
  yet still reached the right row count.

  ⚠️ **It is `analysis_pass & !complete_case_pass`, not
  `imputed_any & !complete_case_pass`.** The latter overcounts: it is
  `TRUE` for a row that had a value filled but is still incomplete
  because a column outside `vars` is missing, and such a row never
  enters the analysis at all. The two agree only when imputation
  completes every row, which is the case the design was written against
  – so the wrong formula gave the right answer there and the error was
  invisible.

- **[`imputation_indicators()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation_indicators.md)**
  generates missingness indicators from the record, with a prefix the
  caller chooses. The SAS `ms_*` spelling is available
  (`prefix = "ms_"`) and is deliberately not the default: a convention
  adopted for parity becomes permanent.

- **[`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)**
  records the method, `m`, the fill values, the package version and the
  seed. An imputed dataset that does not say how it was imputed cannot
  be reproduced.

### Divergences from SAS, stated once

- **`vars` is required.** `PROC STANDARD` with no `VAR` statement
  processes every numeric variable in the dataset; that default is not
  inherited. An imputation that silently chose its own variable list is
  the failure the record exists to catch.
- **An all-missing variable is an error, not a pass-through.** There is
  no mean to impute from, and leaving the column as `NA` while reporting
  it as imputed would be a lie in the record.
- **A non-finite mean is an error.** `mean(c(Inf, -Inf), na.rm = TRUE)`
  is `NaN`; filling with it leaves the cell missing while the record
  marks it imputed. An infinite mean is refused in the other direction,
  as not a plausible measurement. The completed column is then asserted
  to hold no missing values, so the invariant is proved rather than
  assumed.
- **A classed numeric is an error**, even though it passes
  [`is.numeric()`](https://rdrr.io/r/base/numeric.html).
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  packs a 64-bit integer into a double’s bits, so taking its mean into
  an ordinary double reinterprets the bit pattern – a column of 1 and 3
  completes as 0, with the provenance recording `9.88e-324` rather
  than 2. Wrong data and wrong provenance, no error. The guard keys on
  the class attribute rather than a list of known classes, so it also
  catches whatever the next one is called. Convert with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) yourself, so the
  conversion is a choice you made.
- **Duplicated column names in `data` are an error.** `data[["age"]]`
  returns the first `age`, so naming it fills one column, leaves the
  other missing, and emits a single record column that cannot say which.
  An audit cannot read that.
- **A non-numeric variable is an error.** A mean of a factor or a
  character column is not defined, and guessing one would be a method
  choice made silently.

### Not in this release

`impute_multiple()` (`PROC MI`, `mult_imput`) is designed and not built.
Pooling by Rubin’s rules is deferred: multiple imputation is only
multiple imputation if the results are pooled, and that is separate work
with its own verification. `BY`-group means are unmeasured in the corpus
and unimplemented. `PROC STANDARD MEAN=0 STD=1 REPLACE`, which
standardises *and* fills, is a different operation and is not what
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
does.
