# Fill missing values with multiple imputation

Draws `m` completed datasets by chained-equations multiple imputation
(`mice`), and returns them together with a record of exactly what was
filled. This is the R form of `PROC MI`, which the `mult_imput` macro
wraps.

## Usage

``` r
impute_multiple(
  data,
  vars,
  m,
  cc_vars = names(data),
  method = NULL,
  maxit = 5L,
  seed = getOption("hvtiRimputation.seed"),
  predictors
)
```

## Arguments

- data:

  A data frame.

- vars:

  Character vector of columns to impute. **Required, with no default** –
  see Divergences.

- m:

  Number of completed datasets to draw. **Required, with no default** –
  for the same reason `vars` has none in
  [`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md):
  the SAS corpus's `NIMPUTE` defaults disagree across macro copies, so
  there is no single "the default" to inherit.

- cc_vars:

  Character vector of columns over which `complete_case_pass` is
  evaluated, defaulting to every column of `data`. This is the listwise
  deletion the imputation is standing in for, so it is usually the whole
  analysis frame rather than just `vars`.

- method:

  `NULL` (the default) uses `mice`'s own per-column method selection for
  every `vars` column. A named character vector overrides specific
  columns by name; every column not named keeps its default. There is no
  single unnamed string form.

- maxit:

  Number of chained-equations iterations, a single positive whole
  number. Passed to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html).

- seed:

  A single whole number. **Required**, either here or once per session
  through `options(hvtiRimputation.seed = )`, which is where the default
  reads it from. With neither, the call fails rather than drawing from
  an unseeded RNG. Passed to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html) and
  recorded in
  [`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md).

- predictors:

  Character vector of columns that inform the imputation without being
  imputed: they enter the `mice` data and its predictor matrix, and
  their values are never changed. **Required, with no default**;
  `character(0)` is the explicit choice of an imputation that no column
  outside `vars` informs. For an association analysis this is where the
  outcome goes (time and status, for a survival outcome); see Details
  for why. Each column must be fully observed, plain numeric, factor or
  logical, and not also in `vars`. Omitting the argument is an error.

## Value

An object of class `hvti_imputation_multi`.
[`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
with a required `imputation` argument gives one completed data frame or
all `m` stacked long,
[`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
the row-by-variable record of what was filled (identical across every
draw), and
[`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
how it was produced. See
[hvti_imputation_multi](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation_multi.md)
for the full shape.

## Details

Unlike
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md),
a categorical variable is a normal imputation target here: `method`
defaults to `mice::make.method(data[vars])`, `mice`'s own per-column
dispatch (`pmm` for numeric, `logreg` for a 2-level factor, `polyreg`
for an unordered factor with more than two levels, `polr` for an ordered
factor). **There is no single method string applied to every column.** A
caller overriding specific columns passes a named character vector
naming only those columns; every other column keeps its own default.
Forcing one method across a mix of column types is a silent,
package-wide default of exactly the kind this package's design avoids
for `vars` and `m`, and it is not what
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)'s
single completed dataset needs multiplied by `m` – it needs `mice`
making its own per-column decision, `m` times.

**What informs the draws.** `mice` models each imputed column from the
other columns it is given, and it is given `vars` plus `predictors`,
nothing else. A column left out of both cannot shape a single draw. That
matters most for the outcome. If you impute the covariates without the
outcome and then fit a model of the outcome on the completed data, every
filled value was drawn as though it had no relationship to the outcome.
The association you estimate is a blend of the real one (from observed
rows) and zero (from filled ones), so it is biased toward the null, and
the more you filled the stronger the pull. Moons and colleagues (2006)
and Sterne and colleagues (2009) both make this point, and it is the
standard advice for multiple imputation.

So `predictors` is **required, with no default**. For an association
analysis, name the outcome there: for a survival outcome, both the
follow-up time and the event indicator (the Nelson-Aalen cumulative
hazard is a better predictor than raw time, per White and Royston,
2009). For a prediction model, an imputation the outcome never saw is
defensible, because the model will meet new patients whose outcome is
unknown; pass `predictors = character(0)` to make that choice on
purpose. Before 0.1.4 the argument did not exist and every call was
outcome-free unless the outcome was itself in `vars`. We did not choose
that; the function simply had no way to ask. We are still changing our
processes to be correct, and a required argument is how the choice gets
made, and made visibly, at every call site. In 0.1.4 a call without
`predictors` still ran outcome-free, with a warning; from 0.1.5 it is an
error.

`impute_multiple()` trusts the class of each `vars` column as the sole
signal for what kind of variable it is, and does not re-derive that from
its distinct-value count. Deciding a column's type is
`hvtiRutilities::r_data_types()`'s job (or the caller's own
[`factor()`](https://rdrr.io/r/base/factor.html)/[`as.logical()`](https://rdrr.io/r/base/logical.html)),
done once, before imputation – not a second, independent guess made here
that could silently disagree with the first one.

**Reproducibility.** The same `data`, arguments and `seed` give the same
imputed values whatever state R's random number generator was in
beforehand. The call runs under
[`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html)
with the RNG kind pinned to R's defaults (`"Mersenne-Twister"`,
`"Inversion"`, `"Rejection"`), so a caller who changed
[`RNGkind()`](https://rdrr.io/r/base/Random.html) still gets the same
draws, and the caller's own RNG state is restored afterwards: calling
this function does not move their random stream. Before 0.1.2 the
default was `seed = NA`, which left the draws to whatever the global RNG
held; a call that already passed a seed gets the same values as before
when the RNG kind is R's default.

**Choosing `m`.** For a prediction model, `m = 1`, an outcome-free
single draw (`predictors = character(0)`), is defensible. `m > 1` costs
more but lets a downstream variable screen show how much its selection
depends on which draw it saw.

## Divergences from SAS

**`vars` and `m` are both required.** `PROC MI` with no `VAR` statement
processes every numeric variable, and its `NIMPUTE` default varies by
macro copy in the corpus this package ports. Neither default is
inherited here, for the reason recorded in
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)'s
own Divergences section.

**`vars` and `predictors` need at least two columns between them.**
[`mice::mice()`](https://amices.org/mice/reference/mice.html) fits
chained equations, so a single column has no other column to condition
on, and passing one fails inside `mice` with no context. One imputed
variable is fine when a predictor (the outcome, say) supplies the second
column. This function checks for it and refuses with an explanation
instead.

**Columns `mice` drops are reported, not hidden.** `mice` quietly
removes a column that is constant or collinear with another before it
imputes anything, and records the removal in its `loggedEvents`. If it
removed one of `vars`, that column comes back still missing, and this
function refuses with the reason `mice` logged. If it removed one of
`predictors`, the imputation ran without it, and this function warns,
because the column you named to inform the draws did not. `mice` also
drops a predictor from a single model when it is linearly dependent on
the others among the rows where that model's target is observed, a
dependence that need not hold in the full data. That is logged against
the imputation method rather than as `"collinear"`, and this function
warns for it too, naming the column, the target and how many of the
`maxit` x `m` fits lost it. Every event `mice` logged is kept in the
provenance as `logged_events`.

**`data` cannot use `.imp` or `.id` as column names.** Both are reserved
for the long-format draw index and row identifier this function adds.

**No pooling.** This function returns `m` valid completed datasets and
their record. Combining them into a single inferential answer – fitting
a model to each draw and pooling by Rubin's rules – is the caller's job.
Multiple imputation is only multiple imputation once the results are
pooled, and that is separate work with its own verification; see the
package README.

## References

Moons KGM, Donders RART, Stijnen T, Harrell FE Jr (2006). Using the
outcome for imputation of missing predictor values was preferred.
*Journal of Clinical Epidemiology*, 59(10), 1092-1101.
[doi:10.1016/j.jclinepi.2006.01.009](https://doi.org/10.1016/j.jclinepi.2006.01.009)

Sterne JAC, White IR, Carlin JB, et al. (2009). Multiple imputation for
missing data in epidemiological and clinical research: potential and
pitfalls. *BMJ*, 338, b2393.
[doi:10.1136/bmj.b2393](https://doi.org/10.1136/bmj.b2393)

White IR, Royston P (2009). Imputing missing covariate values for the
Cox model. *Statistics in Medicine*, 28(15), 1982-1998.
[doi:10.1002/sim.3618](https://doi.org/10.1002/sim.3618)

## See also

[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
for single imputation – there is deliberately no one function that picks
between them.
[`imputed_any()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
and
[`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
for the two row-level columns the attrition record consumes.

## Examples

``` r
set.seed(42)
n <- 30
dat <- data.frame(
  age  = round(rnorm(n, 60, 8)),
  grp  = factor(sample(c("a", "b", "c"), n, replace = TRUE)),
  flag = sample(c(TRUE, FALSE), n, replace = TRUE),
  dead = sample(c(0, 1), n, replace = TRUE)
)
dat$age[sample(n, 4)]  <- NA
dat$grp[sample(n, 4)]  <- NA
dat$flag[sample(n, 4)] <- NA

# `dead` is the outcome: it informs the draws and is never imputed.
out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2,
                       predictors = "dead", maxit = 2, seed = 1)
imputed_data(out, imputation = 1)
#>    age grp  flag dead
#> 1   71   a FALSE    0
#> 2   55   b FALSE    0
#> 3   63   b FALSE    1
#> 4   65   b  TRUE    0
#> 5   63   b FALSE    0
#> 6   59   a  TRUE    1
#> 7   72   c FALSE    1
#> 8   59   b FALSE    1
#> 9   76   a  TRUE    0
#> 10  59   b FALSE    0
#> 11  70   a  TRUE    1
#> 12  78   b FALSE    0
#> 13  49   b  TRUE    0
#> 14  58   b FALSE    1
#> 15  63   a  TRUE    0
#> 16  65   a FALSE    0
#> 17  78   a FALSE    0
#> 18  39   c  TRUE    1
#> 19  40   a  TRUE    1
#> 20  71   b  TRUE    0
#> 21  58   a FALSE    1
#> 22  46   a  TRUE    1
#> 23  59   a FALSE    1
#> 24  70   b FALSE    0
#> 25  75   c FALSE    0
#> 26  57   a FALSE    0
#> 27  58   a  TRUE    0
#> 28  46   b  TRUE    0
#> 29  65   a FALSE    0
#> 30  55   b  TRUE    0
imputed_data(out, imputation = "long")
#>    .imp .id age grp  flag dead
#> 1     1   1  71   a FALSE    0
#> 2     1   2  55   b FALSE    0
#> 3     1   3  63   b FALSE    1
#> 4     1   4  65   b  TRUE    0
#> 5     1   5  63   b FALSE    0
#> 6     1   6  59   a  TRUE    1
#> 7     1   7  72   c FALSE    1
#> 8     1   8  59   b FALSE    1
#> 9     1   9  76   a  TRUE    0
#> 10    1  10  59   b FALSE    0
#> 11    1  11  70   a  TRUE    1
#> 12    1  12  78   b FALSE    0
#> 13    1  13  49   b  TRUE    0
#> 14    1  14  58   b FALSE    1
#> 15    1  15  63   a  TRUE    0
#> 16    1  16  65   a FALSE    0
#> 17    1  17  78   a FALSE    0
#> 18    1  18  39   c  TRUE    1
#> 19    1  19  40   a  TRUE    1
#> 20    1  20  71   b  TRUE    0
#> 21    1  21  58   a FALSE    1
#> 22    1  22  46   a  TRUE    1
#> 23    1  23  59   a FALSE    1
#> 24    1  24  70   b FALSE    0
#> 25    1  25  75   c FALSE    0
#> 26    1  26  57   a FALSE    0
#> 27    1  27  58   a  TRUE    0
#> 28    1  28  46   b  TRUE    0
#> 29    1  29  65   a FALSE    0
#> 30    1  30  55   b  TRUE    0
#> 31    2   1  71   a FALSE    0
#> 32    2   2  55   b FALSE    0
#> 33    2   3  63   b FALSE    1
#> 34    2   4  65   b  TRUE    0
#> 35    2   5  63   b  TRUE    0
#> 36    2   6  59   a  TRUE    1
#> 37    2   7  72   c FALSE    1
#> 38    2   8  59   b FALSE    1
#> 39    2   9  76   a  TRUE    0
#> 40    2  10  59   b FALSE    0
#> 41    2  11  70   a  TRUE    1
#> 42    2  12  78   b FALSE    0
#> 43    2  13  49   b  TRUE    0
#> 44    2  14  78   b FALSE    1
#> 45    2  15  63   a  TRUE    0
#> 46    2  16  65   a  TRUE    0
#> 47    2  17  55   a  TRUE    0
#> 48    2  18  39   c  TRUE    1
#> 49    2  19  40   a  TRUE    1
#> 50    2  20  71   b  TRUE    0
#> 51    2  21  58   a FALSE    1
#> 52    2  22  46   a  TRUE    1
#> 53    2  23  59   a FALSE    1
#> 54    2  24  70   c FALSE    0
#> 55    2  25  75   c FALSE    0
#> 56    2  26  57   a FALSE    0
#> 57    2  27  58   a  TRUE    0
#> 58    2  28  46   b  TRUE    0
#> 59    2  29  75   a FALSE    0
#> 60    2  30  55   b FALSE    0
imputed_matrix(out)
#>         age   grp  flag
#>  [1,] FALSE FALSE FALSE
#>  [2,] FALSE FALSE FALSE
#>  [3,] FALSE FALSE FALSE
#>  [4,] FALSE FALSE FALSE
#>  [5,] FALSE FALSE  TRUE
#>  [6,] FALSE  TRUE FALSE
#>  [7,] FALSE FALSE FALSE
#>  [8,] FALSE FALSE FALSE
#>  [9,] FALSE FALSE FALSE
#> [10,] FALSE FALSE FALSE
#> [11,] FALSE  TRUE FALSE
#> [12,] FALSE FALSE FALSE
#> [13,] FALSE FALSE FALSE
#> [14,]  TRUE FALSE FALSE
#> [15,]  TRUE  TRUE FALSE
#> [16,] FALSE FALSE  TRUE
#> [17,]  TRUE FALSE  TRUE
#> [18,] FALSE FALSE FALSE
#> [19,] FALSE FALSE FALSE
#> [20,] FALSE FALSE FALSE
#> [21,] FALSE FALSE FALSE
#> [22,] FALSE FALSE FALSE
#> [23,] FALSE FALSE FALSE
#> [24,] FALSE  TRUE FALSE
#> [25,] FALSE FALSE FALSE
#> [26,] FALSE FALSE FALSE
#> [27,] FALSE FALSE FALSE
#> [28,] FALSE FALSE FALSE
#> [29,]  TRUE FALSE FALSE
#> [30,] FALSE FALSE  TRUE
```
