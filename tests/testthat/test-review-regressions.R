# Regressions for four defects found in review of the first release. Each
# reproduces the reported failure directly; each failed against the code as
# first written.

test_that("the counterfactual excludes rows still incomplete after filling", {
  # P0. `imputed_any(x) & !complete_case_pass(x)` is TRUE for row 1 -- a value
  # was filled, and it did not pass complete-case -- but `outcome` is still
  # missing, so the row never enters the analysis and was kept by nothing.
  d <- data.frame(age = c(NA, 50, 60), outcome = c(NA, 1, 0))
  out <- impute_mean(d, vars = "age")

  expect_equal(imputed_any(out), c(TRUE, FALSE, FALSE))
  expect_equal(complete_case_pass(out), c(FALSE, TRUE, TRUE))
  expect_equal(analysis_pass(out), c(FALSE, TRUE, TRUE))

  # The wrong formula counts row 1; the accessor does not.
  expect_equal(sum(imputed_any(out) & !complete_case_pass(out)), 1L)
  expect_equal(kept_by_imputation(out), c(FALSE, FALSE, FALSE))
  expect_equal(sum(kept_by_imputation(out)), 0L)
})

test_that("a row completed BY imputation is still counted", {
  # The other side of the same test: without it, returning all-FALSE would
  # pass the one above.
  d <- data.frame(age = c(NA, 50, 60), outcome = c(1, 1, 0))
  out <- impute_mean(d, vars = "age")

  expect_equal(kept_by_imputation(out), c(TRUE, FALSE, FALSE))
})

test_that("both definitions agree when imputation completes every row", {
  # Why the defect survived review: in the study the design was written
  # against, the analysis set was every row, so the wrong formula was right.
  d <- data.frame(age = c(NA, 50, 60), bmi = c(20, NA, 25))
  out <- impute_mean(d, vars = c("age", "bmi"))

  expect_true(all(analysis_pass(out)))
  expect_equal(kept_by_imputation(out),
               imputed_any(out) & !complete_case_pass(out))
})

test_that("a non-finite mean errors rather than recording a phantom fill", {
  # P1. mean(c(Inf, -Inf), na.rm = TRUE) is NaN. Assigning it leaves the cell
  # missing while the record marks it TRUE.
  d <- data.frame(x = c(Inf, -Inf, NA))
  expect_error(impute_mean(d, vars = "x"), "cannot be used as a fill value")

  # An all-infinite column has an infinite mean, rejected for the same reason
  # in the other direction.
  expect_error(
    impute_mean(data.frame(x = c(Inf, Inf, NA)), vars = "x"),
    "cannot be used as a fill value"
  )
})

test_that("no cell the record marks filled is left missing", {
  # The invariant the P1 defect broke, asserted directly rather than through
  # the specific input that broke it.
  d <- data.frame(age = c(50, NA, 70), bmi = c(NA, 25, 29))
  out <- impute_mean(d, vars = c("age", "bmi"))

  filled <- imputed_data(out)
  rec <- imputed_matrix(out)
  for (v in colnames(rec)) {
    expect_false(any(is.na(filled[[v]][rec[, v]])),
                 info = paste("record claims a fill that is still NA in", v))
  }
})

test_that("a classed numeric is rejected rather than silently corrupted", {
  # P1. bit64::integer64 passes is.numeric() but packs an int64 into a
  # double's bits, so its mean taken into an ordinary double reinterprets the
  # bit pattern: 1 and 3 completed as 0, provenance recording 9.88e-324.
  skip_if_not_installed("bit64")
  d <- data.frame(v = bit64::as.integer64(c(1, 3, NA)))
  expect_error(impute_mean(d, vars = "v"), "plain numeric")
  expect_error(impute_mean(d, vars = "v"), "integer64")
})

test_that("the classed-numeric guard keys on the attribute, not a name list", {
  # An arbitrary classed double -- no bit64 needed -- passes is.numeric() and
  # is rejected on the attribute alone. Keying on a list of known classes
  # would catch integer64 and miss whatever the next one is called.
  d <- data.frame(x = structure(c(1, NA, 3), class = "myscale"))
  expect_true(is.numeric(d$x))
  expect_error(impute_mean(d, vars = "x"), "plain numeric")
  expect_error(impute_mean(d, vars = "x"), "myscale")
})

test_that("Date and POSIXct are rejected, though by the is.numeric guard", {
  # Recorded because it is not obvious: is.numeric() is FALSE for Date and
  # POSIXct, so they never reach the classed-numeric guard. Both are still
  # refused, which is the outcome that matters.
  expect_false(is.numeric(as.Date("2026-01-01")))
  d <- data.frame(when = as.Date(c("2026-01-01", NA, "2026-01-03")))
  expect_error(impute_mean(d, vars = "when"), "not numeric")
})

test_that("duplicated column names in `data` error, not fill just one", {
  # P1. data[["age"]] returns the FIRST age, so the second stays missing while
  # a single record column named `age` cannot say which was filled.
  d <- data.frame(age = c(NA, 50), age = c(60, NA), check.names = FALSE)
  expect_equal(names(d), c("age", "age"))
  expect_error(impute_mean(d, vars = "age"), "more than one column named")
})

test_that("a duplicated name errors even when it is not the variable imputed", {
  # cc_vars defaults to every column, so an ambiguous name anywhere reaches
  # the complete-case selection.
  d <- data.frame(age = c(NA, 50), sex = c(1, 2), sex = c(3, 4),
                  check.names = FALSE)
  expect_error(impute_mean(d, vars = "age"), "more than one column named")
})
