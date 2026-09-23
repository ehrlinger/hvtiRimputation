# Package index

## 

Impute

One function per method, never one function with a `method=` argument.
Single mean imputation is the SAS `imputsub` / `PROC STANDARD REPLACE`
job; multiple imputation (`PROC MI` / `mult_imput`) is a prototype, not
yet hardened or released, and does not pool its `m` completed datasets.

- [`impute_mean()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_mean.md)
  : Fill missing values with the variable mean
- [`impute_multiple()`](https://ehrlinger.github.io/hvtiRimputation/reference/impute_multiple.md)
  : Fill missing values with multiple imputation

## 

Read the record

Every imputation returns the completed data and a record of exactly what
was changed. The matrix is the primary artifact; everything else here is
a view of it.

- [`hvti_imputation`](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation.md)
  : The imputation record
- [`hvti_imputation_multi`](https://ehrlinger.github.io/hvtiRimputation/reference/hvti_imputation_multi.md)
  : The multiple-imputation record
- [`imputed_data()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`imputed_matrix()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`imputed_any()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`complete_case_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`analysis_pass()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`kept_by_imputation()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  [`imputation_provenance()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation-accessors.md)
  : Read an imputation record
- [`imputation_indicators()`](https://ehrlinger.github.io/hvtiRimputation/reference/imputation_indicators.md)
  : Missingness indicators, generated from the record
- [`summary(`*`<hvti_imputation>`*`)`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation.md)
  : Summarise what was imputed
- [`summary(`*`<hvti_imputation_multi>`*`)`](https://ehrlinger.github.io/hvtiRimputation/reference/summary.hvti_imputation_multi.md)
  : Summarise what was imputed, across the m completed datasets

## Package

- [`hvtiRimputation`](https://ehrlinger.github.io/hvtiRimputation/reference/hvtiRimputation-package.md)
  [`hvtiRimputation-package`](https://ehrlinger.github.io/hvtiRimputation/reference/hvtiRimputation-package.md)
  : hvtiRimputation: Missing Value Imputation for the HVTI CORR Group
