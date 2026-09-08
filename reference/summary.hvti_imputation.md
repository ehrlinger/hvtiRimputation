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
number of values filled, the proportion of rows that is, and the value
used to fill them.

## Examples

``` r
dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
summary(impute_mean(dat, vars = c("age", "bmi")))
#>   variable n_imputed prop_imputed fill_value
#> 1      age         1         0.25         60
#> 2      bmi         1         0.25         27
```
