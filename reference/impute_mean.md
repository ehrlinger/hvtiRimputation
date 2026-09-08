# Fill missing values with the variable mean

Replaces every missing value in `vars` with that variable's mean over
its non-missing values, and returns the filled data together with a
record of exactly which values were changed.

## Usage

``` r
impute_mean(data, vars, cc_vars = names(data))
```

## Arguments

- data:

  A data frame.

- vars:

  Character vector of columns to impute. **Required, with no default** –
  see Divergences.

- cc_vars:

  Character vector of columns over which `complete_case_pass` is
  evaluated, defaulting to every column of `data`. This is the listwise
  deletion the imputation is standing in for, so it is usually the whole
  analysis frame rather than just `vars`.

## Value

An object of class `hvti_imputation`.
[`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
gives the completed data frame,
[`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
the row-by-variable record of what was filled, and
[`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
how it was produced. See
[hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md)
for the full shape.

## Details

This is the R form of `PROC STANDARD ... REPLACE` with no
`MEAN=`/`STD=`, which is what the `imputsub` macro wraps. It is
**single** imputation: one completed dataset, and no between-imputation
variance. If you want multiple imputation, call `impute_multiple()` –
there is deliberately no one function that picks between them, because a
function that quietly does one when the caller expected the other is a
worse failure than no function at all.

## Divergences from SAS

**`vars` is required.** `PROC STANDARD` with no `VAR` statement
processes every numeric variable in the dataset. That default is not
inherited here, for the same reason `impute_multiple()` inherits no `m`:
an imputation that silently chose its own variable list is the failure
the record in this package exists to catch. A port that mean-imputes the
*wrong* variable list still reaches the right row count and still looks
correct; it does not reach the right `sum(imputed_any())`.

**`PROC STANDARD MEAN=0 STD=1 REPLACE` is not this function.** That form
standardises *and* fills – in standardised units the fill value 0 is the
mean, so it is imputation too, but it also rescales every value
including the observed ones. It is not implemented here. Do not reach
for `impute_mean()` to reproduce a job that used it.

**`BY`-group means are not implemented.** How much of the corpus imputes
within `BY` groups has not been measured, so this is a gap rather than a
decision.

## See also

[`imputed_any()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
and
[`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
for the two row-level columns the attrition record consumes. Multiple
imputation (`impute_multiple()`) is designed but not yet implemented;
see the README.

## Examples

``` r
dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
out <- impute_mean(dat, vars = c("age", "bmi"))
imputed_data(out)
#>   age bmi
#> 1  50  27
#> 2  60  25
#> 3  60  27
#> 4  70  29
imputed_matrix(out)
#>        age   bmi
#> [1,] FALSE  TRUE
#> [2,] FALSE FALSE
#> [3,]  TRUE FALSE
#> [4,] FALSE FALSE
```
