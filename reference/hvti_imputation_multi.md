# The multiple-imputation record

What
[`impute_multiple()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_multiple.md)
returns: `m` completed datasets, stacked long, and the record of how
they were produced.

## Why long, and why not a list of `m` frames

[hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md)'s
own record is a matrix rather than a count because the record is meant
to reduce, never to require reconstruction. The same reasoning picks the
storage shape here. A long frame – one `.imp` column naming the draw,
one `.id` column naming the original row, then every column of the input
– reduces to a single completed dataset with one `imputation == 1`
filter, and is already the shape a correct downstream analysis expects:
fit a model to each draw, then pool the fits. A list of `m` frames does
not reduce to anything without picking an element out of the list first.
The long form is also the shape `mice::complete(imp, "long")` already
returns, and the shape SAS's `PROC MI OUT=` produces – unforced parity
with both.

## Why the matrix and the two row-level columns are not lists of `m`

Which cells were originally missing does not change across the `m` draws
– only what they were filled *with* does – so
[`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is identical for every draw and is stored once.
[`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is read from the input before any imputation runs, so it is the same for
every draw by construction.
[`analysis_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is less obvious but still invariant: `mice` guarantees every column that
entered the imputation is complete in every draw, so completeness over
`cc_vars` evaluates identically regardless of which draw's values are
substituted in. Storing three lists of `m` identical vectors would work,
but it would misstate the record – it would let a caller ask a question
("does row 12's analysis-pass status differ by draw?") that cannot have
a "yes" for any input this function accepts.

## What it holds

- `data_long`:

  every column of the input, stacked `m` times with `.imp` (`1:m`) and
  `.id` (the original row number) columns added, via
  [`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)

- `matrix`:

  the logical record, via
  [`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)

- `complete_case_pass`:

  row-level, read from the input

- `analysis_pass`:

  row-level, after imputing

- `provenance`:

  method (one per imputed variable), `m`, `maxit`, and the rest, via
  [`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
