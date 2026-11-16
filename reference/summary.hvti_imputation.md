# Summarise what was imputed

Reduces the record to a per-variable table. It is a view of
[`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md),
never a replacement for it: a count cannot say whether a particular row
was filled.

## Usage

``` r
# S3 method for class 'hvti_imputation'
summary(object, ...)
```

## Arguments

- object:

  An object of class
  [hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md).

- ...:

  Ignored.

## Value

A data frame with one row per imputed variable: the variable name, the
method (`"mean"`), the number of values filled, the proportion of rows
that is, and the value used to fill them. The columns are the ones
[`summary.hvti_imputation_multi()`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation_multi.md)
returns, where `fill_value` is `NA`, so the two tables bind with
[`rbind()`](https://rdrr.io/r/base/cbind.html).

## Examples

``` r
dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
summary(impute_mean(dat, vars = c("age", "bmi")))
#>   variable method n_imputed prop_imputed fill_value
#> 1      age   mean         1         0.25         60
#> 2      bmi   mean         1         0.25         27
```
