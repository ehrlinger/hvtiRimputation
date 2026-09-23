# Summarise what was imputed, across the m completed datasets

Reduces the record to a per-variable table: which method each variable
was imputed with, and how many of its values were filled. Unlike
[`summary.hvti_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation.md),
there is no single `fill_value` column – each of the `m` draws can fill
a given cell with a different value, which is the entire point of
multiple imputation, so no single value speaks for all of them.

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
method used, the number of values filled, and the proportion of rows
that is.

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

out <- impute_multiple(dat, vars = c("age", "grp"), m = 2, maxit = 2,
                       seed = 1)
summary(out)
#>   variable  method n_imputed prop_imputed
#> 1      age     pmm         4    0.1333333
#> 2      grp polyreg         4    0.1333333
```
