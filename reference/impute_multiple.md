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
  seed = NA_integer_
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

  Number of chained-equations iterations. Passed to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html).

- seed:

  Passed to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html). `NA`
  (the default) means `mice` does not set one.

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

`impute_multiple()` trusts the class of each `vars` column as the sole
signal for what kind of variable it is, and does not re-derive that from
its distinct-value count. Deciding a column's type is
`hvtiRutilities::r_data_types()`'s job (or the caller's own
[`factor()`](https://rdrr.io/r/base/factor.html)/[`as.logical()`](https://rdrr.io/r/base/logical.html)),
done once, before imputation – not a second, independent guess made here
that could silently disagree with the first one.

## Divergences from SAS

**`vars` and `m` are both required.** `PROC MI` with no `VAR` statement
processes every numeric variable, and its `NIMPUTE` default varies by
macro copy in the corpus this package ports. Neither default is
inherited here, for the reason recorded in
[`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)'s
own Divergences section.

**`vars` needs at least two columns.**
[`mice::mice()`](https://amices.org/mice/reference/mice.html) fits
chained equations, so a single column has no other column to condition
on – passing one fails inside `mice` with no context. This function
checks for it and refuses with an explanation instead.

**`data` cannot use `.imp` or `.id` as column names.** Both are reserved
for the long-format draw index and row identifier this function adds.

**No pooling.** This function returns `m` valid completed datasets and
their record. Combining them into a single inferential answer – fitting
a model to each draw and pooling by Rubin's rules – is the caller's job.
Multiple imputation is only multiple imputation once the results are
pooled, and that is separate work with its own verification; see the
package README.

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
  flag = sample(c(TRUE, FALSE), n, replace = TRUE)
)
dat$age[sample(n, 4)]  <- NA
dat$grp[sample(n, 4)]  <- NA
dat$flag[sample(n, 4)] <- NA

out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2,
                       maxit = 2, seed = 1)
imputed_data(out, imputation = 1)
#>    age grp  flag
#> 1   71   a FALSE
#> 2   55   b FALSE
#> 3   63   b FALSE
#> 4   65   b  TRUE
#> 5   63   b FALSE
#> 6   59   b FALSE
#> 7   72   c FALSE
#> 8   59   a FALSE
#> 9   76   a  TRUE
#> 10  59   b FALSE
#> 11  76   c  TRUE
#> 12  78   b FALSE
#> 13  49   b  TRUE
#> 14  58   b FALSE
#> 15  59   a  TRUE
#> 16  65   a FALSE
#> 17  58   a FALSE
#> 18  39   c  TRUE
#> 19  40   a  TRUE
#> 20  71   b  TRUE
#> 21  58   a FALSE
#> 22  46   a  TRUE
#> 23  59   b FALSE
#> 24  70   c FALSE
#> 25  64   c FALSE
#> 26  57   b FALSE
#> 27  58   a  TRUE
#> 28  46   b  TRUE
#> 29  64   a FALSE
#> 30  71   b  TRUE
imputed_data(out, imputation = "long")
#>    .imp .id age grp  flag
#> 1     1   1  71   a FALSE
#> 2     1   2  55   b FALSE
#> 3     1   3  63   b FALSE
#> 4     1   4  65   b  TRUE
#> 5     1   5  63   b FALSE
#> 6     1   6  59   b FALSE
#> 7     1   7  72   c FALSE
#> 8     1   8  59   a FALSE
#> 9     1   9  76   a  TRUE
#> 10    1  10  59   b FALSE
#> 11    1  11  76   c  TRUE
#> 12    1  12  78   b FALSE
#> 13    1  13  49   b  TRUE
#> 14    1  14  58   b FALSE
#> 15    1  15  59   a  TRUE
#> 16    1  16  65   a FALSE
#> 17    1  17  58   a FALSE
#> 18    1  18  39   c  TRUE
#> 19    1  19  40   a  TRUE
#> 20    1  20  71   b  TRUE
#> 21    1  21  58   a FALSE
#> 22    1  22  46   a  TRUE
#> 23    1  23  59   b FALSE
#> 24    1  24  70   c FALSE
#> 25    1  25  64   c FALSE
#> 26    1  26  57   b FALSE
#> 27    1  27  58   a  TRUE
#> 28    1  28  46   b  TRUE
#> 29    1  29  64   a FALSE
#> 30    1  30  71   b  TRUE
#> 31    2   1  71   a FALSE
#> 32    2   2  55   b FALSE
#> 33    2   3  63   b FALSE
#> 34    2   4  65   b  TRUE
#> 35    2   5  63   b FALSE
#> 36    2   6  59   b  TRUE
#> 37    2   7  72   c FALSE
#> 38    2   8  59   a FALSE
#> 39    2   9  76   a  TRUE
#> 40    2  10  59   b FALSE
#> 41    2  11  72   c  TRUE
#> 42    2  12  78   b FALSE
#> 43    2  13  49   b  TRUE
#> 44    2  14  58   b FALSE
#> 45    2  15  59   a  TRUE
#> 46    2  16  65   a FALSE
#> 47    2  17  58   a FALSE
#> 48    2  18  39   c  TRUE
#> 49    2  19  40   a  TRUE
#> 50    2  20  71   b  TRUE
#> 51    2  21  59   a FALSE
#> 52    2  22  46   a  TRUE
#> 53    2  23  59   a FALSE
#> 54    2  24  70   c FALSE
#> 55    2  25  58   c FALSE
#> 56    2  26  57   a FALSE
#> 57    2  27  58   a  TRUE
#> 58    2  28  46   b  TRUE
#> 59    2  29  64   a FALSE
#> 60    2  30  49   b  TRUE
imputed_matrix(out)
#>         age   grp  flag
#>  [1,] FALSE FALSE  TRUE
#>  [2,] FALSE FALSE FALSE
#>  [3,] FALSE FALSE FALSE
#>  [4,] FALSE FALSE FALSE
#>  [5,] FALSE FALSE FALSE
#>  [6,] FALSE FALSE  TRUE
#>  [7,] FALSE FALSE FALSE
#>  [8,] FALSE  TRUE FALSE
#>  [9,] FALSE FALSE FALSE
#> [10,] FALSE FALSE FALSE
#> [11,]  TRUE FALSE FALSE
#> [12,] FALSE FALSE FALSE
#> [13,] FALSE FALSE  TRUE
#> [14,] FALSE FALSE  TRUE
#> [15,] FALSE FALSE FALSE
#> [16,] FALSE  TRUE FALSE
#> [17,] FALSE FALSE FALSE
#> [18,] FALSE FALSE FALSE
#> [19,] FALSE FALSE FALSE
#> [20,] FALSE FALSE FALSE
#> [21,]  TRUE FALSE FALSE
#> [22,] FALSE FALSE FALSE
#> [23,] FALSE  TRUE FALSE
#> [24,] FALSE FALSE FALSE
#> [25,]  TRUE FALSE FALSE
#> [26,] FALSE  TRUE FALSE
#> [27,] FALSE FALSE FALSE
#> [28,] FALSE FALSE FALSE
#> [29,] FALSE FALSE FALSE
#> [30,]  TRUE FALSE FALSE
```
