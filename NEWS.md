# hvtiRimputation 0.1.0

First release. Single mean imputation, and the record that goes with it.

* **`impute_mean()`** ports `PROC STANDARD ... REPLACE` -- the form with no
  `MEAN=`/`STD=`, which the `imputsub` macro wraps. Missing values are filled
  with the variable's mean over its non-missing values; observed values are
  never touched.
* **The record is a logical matrix parallel to the data**, one column per
  imputed variable, `TRUE` where a value was filled. Read it with
  `imputed_matrix()`. A count cannot answer *was this patient's value
  imputed?*, so the matrix is the primary artifact and `summary()` is a view of
  it rather than a replacement for it.
* **`imputed_any()` and `complete_case_pass()`** are the two row-level columns
  the attrition record consumes. `complete_case_pass()` is read from the
  **input**, before anything is filled -- evaluated on the completed data every
  row over `vars` would pass, which is the opposite of what the column means.
  Their intersection, `imputed_any(x) & !complete_case_pass(x)`, counts the
  rows in an analysis only because a covariate was filled in. That is the
  number that catches a port which imputed the wrong variable list yet still
  reached the right row count.
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
