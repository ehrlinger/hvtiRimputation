# Getting Started with hvtiRimputation

## Why keep a record of what you filled?

Most of us have filled a missing covariate with its mean and moved on.
In SAS that was `PROC STANDARD ... REPLACE`, usually through the
`imputsub` macro, and the job ended with a complete dataset and no trace
of which values had been missing. Months later a reviewer asks how many
patients were in the model only because a covariate was filled in, or
whether one particular patient’s value was observed, and the dataset
can’t tell you.

`hvtiRimputation` fills missing values by a stated method and hands back
the filled data together with a record of exactly what it changed. The
record is a logical matrix with one row per row of your data and one
column per imputed variable, `TRUE` where a value was filled. Every
count, indicator and attrition column in the package is read from that
matrix.

The scope is deliberately small. A data frame goes in, and a data frame
and a record come out. The package knows nothing about the warehouse,
the build or any study, so the study context (manifests, cohort
definitions, provenance of the input) stays with you.

This vignette is for the CORR biostatistician who already knows R and
has used the SAS macros. It walks one small synthetic example from the
fill to the attrition columns a CONSORT diagram wants, then shows the
multiple-imputation prototype.

## Installation

``` r

# install.packages("pak")
pak::pak("ehrlinger/hvtiRimputation")
```

``` r

library(hvtiRimputation)
```

## A small example

Eight synthetic rows: three covariates with gaps, and an outcome that is
missing for one row. Nothing here comes from a real patient.

``` r

dat <- data.frame(
  age     = c(64, 71, NA, 58, 66, NA, 73, 69),
  bmi     = c(27.1, NA, 31.4, 24.8, NA, 29.0, 26.3, 30.2),
  ef      = c(55, 60, 45, NA, 50, 58, 62, 40),
  outcome = c(0, 1, 0, 0, 1, NA, 1, 0)
)
dat
#>   age  bmi ef outcome
#> 1  64 27.1 55       0
#> 2  71   NA 60       1
#> 3  NA 31.4 45       0
#> 4  58 24.8 NA       0
#> 5  66   NA 50       1
#> 6  NA 29.0 58      NA
#> 7  73 26.3 62       1
#> 8  69 30.2 40       0
```

Only three rows are complete. Listwise deletion would keep rows 1, 7 and
8.

## Fill, then read the record

[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
replaces each missing value in `vars` with that variable’s mean over its
observed values. Observed values are never touched.

``` r

out <- impute_mean(dat, vars = c("age", "bmi", "ef"))
out
#> <hvti_imputation>
#>   method:  mean (m = 1)
#>   rows:    8
#>   imputed: 3 variable(s), 5 row(s) touched
#>   produced by hvtiRimputation 0.1.2
```

`vars` has no default. `PROC STANDARD` with no `VAR` statement processes
every numeric column, and we chose not to inherit that: an imputation
that picks its own variable list is the mistake the record exists to
catch. Here `outcome` is numeric and is left alone because we did not
name it.

The completed data, and the matrix that says which cells in it were
filled:

``` r

imputed_data(out)
#>        age      bmi       ef outcome
#> 1 64.00000 27.10000 55.00000       0
#> 2 71.00000 28.13333 60.00000       1
#> 3 66.83333 31.40000 45.00000       0
#> 4 58.00000 24.80000 52.85714       0
#> 5 66.00000 28.13333 50.00000       1
#> 6 66.83333 29.00000 58.00000      NA
#> 7 73.00000 26.30000 62.00000       1
#> 8 69.00000 30.20000 40.00000       0
imputed_matrix(out)
#>        age   bmi    ef
#> [1,] FALSE FALSE FALSE
#> [2,] FALSE  TRUE FALSE
#> [3,]  TRUE FALSE FALSE
#> [4,] FALSE FALSE  TRUE
#> [5,] FALSE  TRUE FALSE
#> [6,]  TRUE FALSE FALSE
#> [7,] FALSE FALSE FALSE
#> [8,] FALSE FALSE FALSE
```

Row 3’s `age` of 66.8 is the mean of the six observed ages. The matrix
is what lets you tell it apart from an observed 66.8, and it answers the
audit question directly: was this patient’s value imputed? A count can’t
answer that, though the matrix reduces to any count you need.
[`summary()`](https://rdrr.io/r/base/summary.html) is one such view:

``` r

summary(out)
#>   variable n_imputed prop_imputed fill_value
#> 1      age         2        0.250   66.83333
#> 2      bmi         2        0.250   28.13333
#> 3       ef         1        0.125   52.85714
```

## Which rows did imputation keep?

Mean imputation is usually standing in for listwise deletion, so the
question a CONSORT diagram asks is how many rows entered the analysis
only because something was filled. Three row-level columns answer it.

``` r

data.frame(
  imputed_any        = imputed_any(out),
  complete_case_pass = complete_case_pass(out),
  analysis_pass      = analysis_pass(out),
  kept_by_imputation = kept_by_imputation(out)
)
#>   imputed_any complete_case_pass analysis_pass kept_by_imputation
#> 1       FALSE               TRUE          TRUE              FALSE
#> 2        TRUE              FALSE          TRUE               TRUE
#> 3        TRUE              FALSE          TRUE               TRUE
#> 4        TRUE              FALSE          TRUE               TRUE
#> 5        TRUE              FALSE          TRUE               TRUE
#> 6        TRUE              FALSE         FALSE              FALSE
#> 7       FALSE               TRUE          TRUE              FALSE
#> 8       FALSE               TRUE          TRUE              FALSE
```

[`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is read from the data *before* anything was filled, over `cc_vars`
(every column, by default).
[`analysis_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is the same test after the fill.
[`kept_by_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
flags the rows that fail the first and pass the second.

Look at row 6. Its `age` was filled, so
[`imputed_any()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
is `TRUE`, but its `outcome` is still missing, so it never enters the
analysis. That is why the tempting shortcut gives the wrong count:

``` r

sum(imputed_any(out) & !complete_case_pass(out)) # overcounts row 6
#> [1] 5
sum(kept_by_imputation(out))                     # the supported answer
#> [1] 4
```

The two agree only when imputation completes every row. Use
[`kept_by_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md).
It is also the number worth checking a port against: a port that
mean-imputes the wrong variable list can still reach the right final row
count, but it won’t reach the right
[`kept_by_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
total.

## Indicators for a model

To carry “this value was missing” into a model, generate indicator
columns from the record. The prefix is your choice; `"ms_"` reproduces
the SAS naming when a study used it.

``` r

imputation_indicators(out)
#>   imputed_age imputed_bmi imputed_ef
#> 1       FALSE       FALSE      FALSE
#> 2       FALSE        TRUE      FALSE
#> 3        TRUE       FALSE      FALSE
#> 4       FALSE       FALSE       TRUE
#> 5       FALSE        TRUE      FALSE
#> 6        TRUE       FALSE      FALSE
#> 7       FALSE       FALSE      FALSE
#> 8       FALSE       FALSE      FALSE
cbind(imputed_data(out), imputation_indicators(out, prefix = "ms_"))
#>        age      bmi       ef outcome ms_age ms_bmi ms_ef
#> 1 64.00000 27.10000 55.00000       0  FALSE  FALSE FALSE
#> 2 71.00000 28.13333 60.00000       1  FALSE   TRUE FALSE
#> 3 66.83333 31.40000 45.00000       0   TRUE  FALSE FALSE
#> 4 58.00000 24.80000 52.85714       0  FALSE  FALSE  TRUE
#> 5 66.00000 28.13333 50.00000       1  FALSE   TRUE FALSE
#> 6 66.83333 29.00000 58.00000      NA   TRUE  FALSE FALSE
#> 7 73.00000 26.30000 62.00000       1  FALSE  FALSE FALSE
#> 8 69.00000 30.20000 40.00000       0  FALSE  FALSE FALSE
```

The indicators are generated from the matrix, never stored separately,
so they can’t drift from it.

## How it was produced

[`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
records the method, `m`, the variables, the fill values and the package
version. Save it alongside the analysis.

``` r

prov <- imputation_provenance(out)
prov[c("method", "m", "vars", "cc_vars", "fill_values", "version")]
#> $method
#> [1] "mean"
#> 
#> $m
#> [1] 1
#> 
#> $vars
#> [1] "age" "bmi" "ef" 
#> 
#> $cc_vars
#> [1] "age"     "bmi"     "ef"      "outcome"
#> 
#> $fill_values
#>      age      bmi       ef 
#> 66.83333 28.13333 52.85714 
#> 
#> $version
#> [1] "0.1.2"
```

## What it refuses

The record must never claim a fill that did not happen, so the package
refuses inputs a more relaxed function would quietly accept. A variable
missing in every row has no mean to fill from:

``` r

all_missing <- transform(dat, ef = NA_real_)
tryCatch(
  impute_mean(all_missing, vars = c("age", "ef")),
  error = conditionMessage
)
#> [1] "`ef` is missing for every row, so it has no mean to impute from. Drop the variable or supply the fill value yourself; this function will not leave it as NA and call it imputed."
```

The same goes for a non-numeric variable, a name that is not in the
data, a column whose mean is not finite, a classed numeric such as
`integer64` or `Date`, duplicated column names and a zero-row frame.
Each is an error, not a warning. A refusal costs you a line of code; a
wrong record costs you an audit nobody can pass, because nothing
downstream can detect it.

## Multiple imputation (prototype)

[`impute_multiple()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_multiple.md)
is the R form of `PROC MI`, which the `mult_imput` macro wraps. It draws
`m` completed datasets with `mice` and returns the same shape of record.
It is a prototype: designed and tested, not yet hardened or released,
and it does **not** pool. Fitting a model to each draw and combining the
results by Rubin’s rules is still your job.

It is a separate function from
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
on purpose. The two are different methods with different inferential
properties, and there is no single `impute()` with a `method=` argument
that could quietly run one when you expected the other.

``` r

mi <- impute_multiple(
  dat,
  vars  = c("age", "bmi", "ef"),
  m     = 2,
  maxit = 2,
  seed  = 20261007
)
mi
#> <hvti_imputation_multi>
#>   m:       2 completed dataset(s) (maxit = 2)
#>   rows:    8
#>   imputed: 3 variable(s), 5 row(s) touched
#>   produced by hvtiRimputation 0.1.2
```

`m` and `seed` are both required. Copies of the SAS macros declare
different `NIMPUTE` defaults, and they don’t even agree on whether the
default is 1, so there is no default to inherit. An unseeded draw can’t
be reproduced. You can set the seed once per session with
`options(hvtiRimputation.seed = 20261007)` instead of passing it every
call.

[`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
needs to be told which draw you want, either one completed dataset or
all of them stacked long with `.imp` and `.id` columns:

``` r

imputed_data(mi, imputation = 1)
#>   age  bmi ef outcome
#> 1  64 27.1 55       0
#> 2  71 24.8 60       1
#> 3  64 31.4 45       0
#> 4  58 24.8 58       0
#> 5  66 27.1 50       1
#> 6  66 29.0 58      NA
#> 7  73 26.3 62       1
#> 8  69 30.2 40       0
head(imputed_data(mi, imputation = "long"))
#>   .imp .id age  bmi ef outcome
#> 1    1   1  64 27.1 55       0
#> 2    1   2  71 24.8 60       1
#> 3    1   3  64 31.4 45       0
#> 4    1   4  58 24.8 58       0
#> 5    1   5  66 27.1 50       1
#> 6    1   6  66 29.0 58      NA
```

There is no default for `imputation`, because averaging the draws cell
by cell is not a valid way to combine them. The record and the row-level
columns read the same as before, since which cells were missing does not
change from draw to draw:

``` r

imputed_matrix(mi)
#>        age   bmi    ef
#> [1,] FALSE FALSE FALSE
#> [2,] FALSE  TRUE FALSE
#> [3,]  TRUE FALSE FALSE
#> [4,] FALSE FALSE  TRUE
#> [5,] FALSE  TRUE FALSE
#> [6,]  TRUE FALSE FALSE
#> [7,] FALSE FALSE FALSE
#> [8,] FALSE FALSE FALSE
sum(kept_by_imputation(mi))
#> [1] 4
```

## Where to go next

- [`?impute_mean`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
  and
  [`?impute_multiple`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_multiple.md),
  each with a **Divergences from SAS** section listing where the R port
  differs from the macro and why.
- [`?hvti_imputation`](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md)
  and
  [`?hvti_imputation_multi`](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation_multi.md)
  for the full shape of the returned objects.
- The [package
  README](https://github.com/ehrlinger/hvtiRimputation#readme) for what
  the package promises about reproducing SAS. In short: the arithmetic
  is matched, the defaults deliberately are not, and a study being
  reproduced takes its `m` from that study’s own saved output.
