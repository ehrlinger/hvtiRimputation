# Summarise what was imputed, across the m completed datasets

Reduces the record to a per-variable table: which method each variable
was imputed with, and how many of its values were filled. Unlike
[`summary.hvti_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation.md),
`fill_value` is always `NA`: each of the `m` draws can fill a given cell
with a different value, which is the entire point of multiple
imputation, so no single value speaks for all of them. The column is
there, as a gap, so the two summaries have the same columns and bind
with [`base::rbind()`](https://rdrr.io/r/base/cbind.html).

## Usage

``` r
# S3 method for class 'hvti_imputation_multi'
summary(object, ...)
```

## Arguments

- object:

  An object of class `hvti_imputation_multi`.

- ...:

  Ignored.

## Value

A data frame with one row per imputed variable: the variable name, the
method used, the number of values filled, the proportion of rows that
is, and `fill_value` (`NA`, see above).

## Examples

``` r
set.seed(42)
n <- 30
dat <- data.frame(
  age = round(rnorm(n, 60, 8)),
  grp = factor(sample(c("a", "b", "c"), n, replace = TRUE))
)
dat$age[sample(n, 4)] <- NA
dat$grp[sample(n, 4)] <- NA

out <- impute_multiple(dat, vars = c("age", "grp"), m = 2,
                       predictors = character(0), maxit = 2, seed = 1)
summary(out)
#>   variable  method n_imputed prop_imputed fill_value
#> 1      age     pmm         4    0.1333333         NA
#> 2      grp polyreg         4    0.1333333         NA
```
