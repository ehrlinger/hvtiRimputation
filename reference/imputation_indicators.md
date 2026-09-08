# Missingness indicators, generated from the record

Returns one logical column per imputed variable, `TRUE` where that
variable's value was filled. A caller reproducing a SAS analysis that
carried `ms_*` indicators as model terms renames in one step:
`imputation_indicators(x, prefix = "ms_")`.

## Usage

``` r
imputation_indicators(x, prefix = "imputed_")
```

## Arguments

- x:

  An object of class
  [hvti_imputation](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md).

- prefix:

  Prepended to each imputed variable's name. Defaults to `"imputed_"`.

## Value

A data frame of logical columns, one per imputed variable, with
[`nrow()`](https://rdrr.io/r/base/nrow.html) matching the imputed data.

## Details

The indicators are generated rather than stored, and the SAS `ms_`
naming is not the default. A convention adopted for parity becomes
permanent – it would be ours to maintain forever the moment a study
depended on it – so the record stays the single source of truth and the
name stays the caller's choice.

The principle underneath is not negotiable and predates the naming: **a
value that means "observed" and a value that means "filled in" must not
be the same value.** The indicators are how that survives into a model.

## Examples

``` r
dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
out <- impute_mean(dat, vars = c("age", "bmi"))
imputation_indicators(out)
#>   imputed_age imputed_bmi
#> 1       FALSE        TRUE
#> 2       FALSE       FALSE
#> 3        TRUE       FALSE
#> 4       FALSE       FALSE
imputation_indicators(out, prefix = "ms_")
#>   ms_age ms_bmi
#> 1  FALSE   TRUE
#> 2  FALSE  FALSE
#> 3   TRUE  FALSE
#> 4  FALSE  FALSE
```
