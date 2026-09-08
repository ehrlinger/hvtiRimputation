# The imputation record

What every function in this package returns: the completed data, and a
record of exactly what was changed to complete it.

## Why a matrix and not a count

The record is a logical matrix parallel to the data – one row per row of
the input, one column per imputed variable, `TRUE` where the value was
filled. A summary saying "12 values were imputed in this variable"
cannot answer *was this patient's value imputed?*, which is the question
an audit asks. The matrix answers it directly and can be reduced to any
count; the reverse is impossible.

The matrix form is chosen over a long data frame deliberately. It lines
up with the data row for row without a join, and it stays small for a
wide dataset. A long form reads more easily and is much larger, and the
reading is what
[`summary.hvti_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation.md)
is for.

## What it holds

- `data`:

  the completed data frame, via
  [`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)

- `matrix`:

  the logical record, via
  [`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)

- `complete_case_pass`:

  row-level: would this row have survived listwise deletion? Read from
  the input, before anything was filled

- `analysis_pass`:

  row-level: is this row complete *after* imputing? Not derivable from
  the two above – a row can have a value filled and still be incomplete
  because a column outside `vars` is missing

- `provenance`:

  method, `m`, the package version that produced it, and the seed where
  the method is stochastic, via
  [`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)

An imputed dataset that does not say how it was imputed cannot be
reproduced. The SAS corpus this package ports is the proof: thirty years
of imputed datasets whose method is now only partly recoverable, and
only by scanning the code that produced them. So the provenance is not
optional and travels with the artifact.
