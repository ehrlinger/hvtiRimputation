# Conformance with the hvtiR API rubric (2026-11-16): the shared provenance
# record and the condition classes. Each hvtiR package carries its own copy
# of these checks.

check_provenance_record <- function(p) {
  seven <- c("package", "version", "sha", "method", "seed", "rng_kind",
             "time")
  testthat::expect_true(all(seven %in% names(p)))
  testthat::expect_identical(names(p)[1:7], seven)

  testthat::expect_type(p$package, "character")
  testthat::expect_length(p$package, 1L)
  testthat::expect_type(p$version, "character")
  testthat::expect_length(p$version, 1L)
  testthat::expect_type(p$sha, "character")
  testthat::expect_length(p$sha, 1L)
  testthat::expect_type(p$method, "character")
  testthat::expect_gte(length(p$method), 1L)
  testthat::expect_type(p$seed, "integer")
  testthat::expect_length(p$seed, 1L)
  testthat::expect_type(p$rng_kind, "character")
  testthat::expect_length(p$rng_kind, 3L)
  testthat::expect_s3_class(p$time, "POSIXct")
  testthat::expect_length(p$time, 1L)
}

test_that("impute_mean() emits the shared provenance record", {
  dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
  p <- imputation_provenance(impute_mean(dat, vars = c("age", "bmi")))
  check_provenance_record(p)
  expect_identical(p$package, "hvtiRimputation")
  expect_identical(p$method, "mean")
  # Nothing was drawn at random: a gap, not a plausible value.
  expect_identical(p$seed, NA_integer_)
  expect_identical(p$rng_kind, rep(NA_character_, 3L))
})

test_that("impute_multiple() emits the shared provenance record", {
  set.seed(1)
  dat <- data.frame(a = stats::rnorm(30), b = stats::rnorm(30))
  dat$a[1:4] <- NA
  p <- imputation_provenance(
    impute_multiple(dat, vars = c("a", "b"), m = 2, maxit = 1, seed = 11,
                    predictors = character(0))
  )
  check_provenance_record(p)
  expect_identical(p$seed, 11L)
  expect_identical(p$rng_kind, c("Mersenne-Twister", "Inversion",
                                 "Rejection"))
  expect_identical(names(p$method), c("a", "b"))
})

test_that("summary() column sets line up across the two classes", {
  dat <- data.frame(a = c(1, NA, 3, 4, 5, 6, 7, 8), b = c(2, 3, NA, 5, 6,
                                                          7, 8, 1))
  single <- summary(impute_mean(dat, vars = c("a", "b")))
  set.seed(2)
  big <- data.frame(a = stats::rnorm(30), b = stats::rnorm(30))
  big$a[1:4] <- NA
  multi <- summary(
    impute_multiple(big, vars = c("a", "b"), m = 2, maxit = 1, seed = 3,
                    predictors = character(0))
  )
  expect_identical(names(single), names(multi))
  expect_identical(single$method, c("mean", "mean"))

  # The promise is that the tables bind, so exercise the bind itself.
  both <- rbind(single, multi)
  expect_identical(nrow(both), 4L)
  expect_type(both$fill_value, "double")
  # No single value speaks for every draw: a gap, not a plausible number.
  expect_identical(multi$fill_value, c(NA_real_, NA_real_))
})

test_that("errors carry hvtiRimputation_<condition> classes", {
  expect_error(impute_mean(list(), vars = "a"),
               class = "hvtiRimputation_invalid_input")
  expect_error(impute_mean(data.frame(a = 1), vars = "nope"),
               class = "hvtiRimputation_error")
  expect_error(imputed_data(1),
               class = "hvtiRimputation_invalid_input")
  expect_error(imputed_matrix(list()),
               class = "hvtiRimputation_invalid_input")
  dat <- data.frame(a = c(NA, 1:9), b = c(1:9, NA), y = 1:10)
  expect_error(
    impute_multiple(dat, vars = c("a", "b"), m = 1, maxit = 0, seed = 1,
                    predictors = "y"),
    class = "hvtiRimputation_invalid_input"
  )
  expect_error(
    impute_multiple(dat, vars = c("a", "b"), m = 1, seed = 1,
                    predictors = "nope"),
    class = "hvtiRimputation_invalid_input"
  )

  # The record-honesty invariant has its own class. Reaching it needs a fill
  # that assignment silently fails to write, which no supported input does,
  # so the classed condition is checked directly.
  err <- tryCatch(abort("x", class = "unfilled"), error = identity)
  expect_s3_class(err, c("hvtiRimputation_unfilled", "hvtiRimputation_error"))
  expect_null(conditionCall(err))
})
