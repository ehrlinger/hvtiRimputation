test_that("missing values are filled with the non-missing mean", {
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))
  filled <- imputed_data(out)

  expect_equal(filled$age, c(50, 60, 60, 70))
  expect_equal(filled$bmi, c(27, 25, 27, 29))
})

test_that("observed values are left alone", {
  dat <- fixture_frame()
  filled <- imputed_data(impute_mean(dat, vars = c("age", "bmi")))

  observed <- !is.na(dat$age)
  expect_equal(filled$age[observed], dat$age[observed])
})

test_that("columns outside `vars` are untouched, missing or not", {
  out <- impute_mean(fixture_frame(), vars = "age")
  filled <- imputed_data(out)

  expect_equal(filled$bmi, c(NA, 25, 27, 29))
  expect_true(is.na(filled$outcome[4]))
  expect_identical(colnames(imputed_matrix(out)), "age")
})

test_that("the record marks exactly the cells that were filled", {
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))
  rec <- imputed_matrix(out)

  expect_equal(dim(rec), c(4L, 2L))
  expect_equal(rec[, "age"], c(FALSE, FALSE, TRUE, FALSE))
  expect_equal(rec[, "bmi"], c(TRUE, FALSE, FALSE, FALSE))
})

test_that("`complete_case_pass` is read from the input, not the filled data", {
  # The regression this test exists for: evaluated on the completed data,
  # every row over `vars` passes by construction, and the column silently
  # reports the wrong answer with no error.
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))

  # Row 2 is the only fully observed row; rows 1 and 3 are missing a
  # covariate and row 4 is missing the outcome.
  expect_equal(complete_case_pass(out), c(FALSE, TRUE, FALSE, FALSE))
  expect_false(all(complete_case_pass(out)))
})

test_that("`cc_vars` narrows complete-case to the named columns", {
  out <- impute_mean(fixture_frame(), vars = "age", cc_vars = c("age", "bmi"))
  expect_equal(complete_case_pass(out), c(FALSE, TRUE, FALSE, TRUE))
})

test_that("the counterfactual counts rows kept only because of a fill", {
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))
  kept_by_imputation <- imputed_any(out) & !complete_case_pass(out)

  expect_equal(kept_by_imputation, c(TRUE, FALSE, TRUE, FALSE))
  expect_equal(sum(kept_by_imputation), 2L)
})

test_that("`imputed_any` and the indicators agree, as the spec requires", {
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))
  ind <- imputation_indicators(out)

  expect_equal(sum(imputed_any(out)), sum(rowSums(ind) > 0L))
})

test_that("indicators are generated with the caller's prefix", {
  out <- impute_mean(fixture_frame(), vars = c("age", "bmi"))

  expect_named(imputation_indicators(out), c("imputed_age", "imputed_bmi"))
  expect_named(
    imputation_indicators(out, prefix = "ms_"),
    c("ms_age", "ms_bmi")
  )
  expect_equal(nrow(imputation_indicators(out)), 4L)
})

test_that("provenance records the method, m and the producing version", {
  p <- imputation_provenance(impute_mean(fixture_frame(), vars = "age"))

  expect_equal(p$method, "mean")
  expect_equal(p$m, 1L)
  expect_equal(p$vars, "age")
  expect_equal(p$fill_values[["age"]], 60)
  expect_equal(
    p$version,
    as.character(utils::packageVersion("hvtiRimputation"))
  )
})

test_that("summary reduces the record without replacing it", {
  s <- summary(impute_mean(fixture_frame(), vars = c("age", "bmi")))

  expect_equal(s$variable, c("age", "bmi"))
  expect_equal(s$n_imputed, c(1L, 1L))
  expect_equal(s$prop_imputed, c(0.25, 0.25))
  expect_equal(s$fill_value, c(60, 27))
})

test_that("a variable with nothing missing gets FALSE, not an error", {
  dat <- data.frame(age = c(50, 60), bmi = c(20, 25))
  out <- impute_mean(dat, vars = c("age", "bmi"))

  expect_false(any(imputed_matrix(out)))
  expect_equal(imputed_any(out), c(FALSE, FALSE))
})
