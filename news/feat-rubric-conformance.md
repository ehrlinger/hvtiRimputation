* Every error now carries a condition class, `hvtiRimputation_error` plus a
  specific one: `hvtiRimputation_invalid_input` for an argument or column
  refused before anything is filled, `hvtiRimputation_unfilled` for a value
  the record would mark filled that is still missing. Catch by class rather
  than by message text. Messages are unchanged.

* `imputation_provenance()` opens with the seven fields the hvtiR packages
  share, in the same order and types from both `impute_mean()` and
  `impute_multiple()`: `package`, `version`, `sha` (new; the install's
  commit when recorded, else `NA`), `method`, `seed`, `rng_kind` (new; `NA`
  for mean imputation, which draws nothing) and `time`. Package-specific
  fields follow, as before.

* `summary()` of an `impute_mean()` result gains a `method` column, and
  `summary()` of an `impute_multiple()` result gains `fill_value`, always
  `NA` because no single value speaks for every draw. The two tables now
  have the same columns and bind with `rbind()`.
