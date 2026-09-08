test_that("an all-missing variable errors rather than staying NA", {
  dat <- data.frame(age = c(NA_real_, NA_real_), bmi = c(20, 25))
  expect_error(impute_mean(dat, vars = "age"), "no mean to impute")
})

test_that("a non-numeric variable errors rather than being guessed at", {
  expect_error(
    impute_mean(fixture_frame(), vars = c("age", "sex")),
    "not numeric"
  )
})

test_that("an unknown column name errors", {
  expect_error(impute_mean(fixture_frame(), vars = "weight"), "not in `data`")
})

test_that("`vars` has no default and no empty shortcut", {
  expect_error(impute_mean(fixture_frame()))
  expect_error(impute_mean(fixture_frame(), vars = character(0)), "is empty")
})

test_that("a duplicated variable errors rather than being imputed twice", {
  expect_error(
    impute_mean(fixture_frame(), vars = c("age", "age")),
    "more than once"
  )
})

test_that("a zero-row frame errors", {
  expect_error(impute_mean(fixture_frame()[0, ], vars = "age"), "no rows")
})

test_that("a non-data-frame errors", {
  expect_error(
    impute_mean(matrix(1:4, 2), vars = "age"),
    "must be a data frame"
  )
})

test_that("`cc_vars` accepts non-numeric columns, unlike `vars`", {
  out <- impute_mean(fixture_frame(), vars = "age", cc_vars = c("age", "sex"))
  expect_equal(complete_case_pass(out), c(TRUE, TRUE, FALSE, TRUE))
})

test_that("accessors reject an object of the wrong class", {
  expect_error(imputed_data(list()))
  expect_error(imputed_any(data.frame(x = 1)))
})
