# Read an imputation record

Accessors for the object
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
returns.

## Usage

``` r
imputed_data(x)

imputed_matrix(x)

imputed_any(x)

complete_case_pass(x)

analysis_pass(x)

kept_by_imputation(x)

imputation_provenance(x)
```

## Arguments

- x:

  An object of class
  [hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md).

## Value

`imputed_data()` a data frame; `imputed_matrix()` a logical matrix;
`imputed_any()`, `complete_case_pass()`, `analysis_pass()` and
`kept_by_imputation()` logical vectors, one element per row;
[`imputation_indicators()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation_indicators.md)
a data frame of logical columns; `imputation_provenance()` a list.

## Details

`imputed_any()` and `complete_case_pass()` are the two row-level columns
the attrition record consumes. They enter a CONSORT tracker as an
**annotation** – a stage that records something about the rows without
removing any – and not as an exclusion. Rows kept only because a
covariate was filled in are not excluded, and they are not fully
observed either, and a record with no vocabulary for that third state
will misreport one or the other.

**Use `kept_by_imputation()` for the counterfactual, not
`imputed_any(x) & !complete_case_pass(x)`.** That expression overcounts.
It is `TRUE` for a row that had a value filled but is *still* incomplete
because a column outside `vars` is missing – a row that never enters the
analysis at all, and so was not kept by anything.

The two agree only when imputation completes every row, which is why the
error is easy to miss: in the study the design was written against, the
analysis set was every row, so post-imputation completeness was
uniformly `TRUE` and the wrong formula gave the right answer.

## Examples

``` r
dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
out <- impute_mean(dat, vars = c("age", "bmi"))

imputed_any(out)
#> [1]  TRUE FALSE  TRUE FALSE
complete_case_pass(out)
#> [1] FALSE  TRUE FALSE  TRUE
analysis_pass(out)
#> [1] TRUE TRUE TRUE TRUE

# Rows in the analysis only because a covariate was filled:
sum(kept_by_imputation(out))
#> [1] 2
```
