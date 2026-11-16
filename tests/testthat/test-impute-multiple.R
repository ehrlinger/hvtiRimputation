# Every call here draws under one session seed, read through the option
# impute_multiple() uses as its default. The seed itself is tested in
# test-reproducibility.R.
withr::local_options(hvtiRimputation.seed = 20261007L)

# A larger, seeded frame: mice needs enough rows and signal to fit ridge-free
# models for pmm/logreg/polyreg, which fixture_frame()'s 4 rows cannot give.
# grp is a genuine 3-level unordered factor -- exactly the shape whose
# imputed values were checked, empirically, to never fall outside its levels
# (see dev/specs/2026-09-23-impute-multiple-design.md).
multi_fixture <- function(n = 60, seed = 20260923) {
  set.seed(seed)

  x <- stats::rnorm(n)
  breaks <- stats::quantile(x, probs = seq(0, 1, length.out = 4))
  dat <- data.frame(
    age  = round(50 + 10 * x + stats::rnorm(n, sd = 3)),
    grp  = factor(cut(
      x, breaks = breaks, include.lowest = TRUE,
      labels = c("lo", "mid", "hi")
    )),
    flag = x > stats::median(x)
  )
  dat$age[sample(n, round(0.15 * n))] <- NA
  dat$grp[sample(n, round(0.15 * n))] <- NA
  dat$flag[sample(n, round(0.15 * n))] <- NA
  dat
}

test_that("impute_multiple() returns an hvti_imputation_multi object", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 3, predictors = character(0),
    maxit = 2
  )

  expect_s3_class(out, "hvti_imputation_multi")
})

test_that("every completed dataset holds only valid factor levels", {
  # The empirical finding this design is built on: mice never invents a value
  # outside a factor's levels, in any single completed dataset. This is a
  # standing regression test for that property, not a one-off observation.
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 5, predictors = character(0),
    maxit = 3
  )

  for (i in 1:5) {
    grp_i <- imputed_data(out, imputation = i)$grp
    expect_true(all(as.character(grp_i) %in% levels(dat$grp)))
    expect_false(anyNA(grp_i))
  }
})

test_that("imputed_data() on the multi class requires `imputation`", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2
  )

  expect_error(imputed_data(out), "imputation.*is required")

  # The single-imputation class's zero-argument form is untouched.
  dat2 <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
  single <- impute_mean(dat2, vars = c("age", "bmi"))
  expect_no_error(imputed_data(single))
})

test_that("imputed_data(x, \"long\") stacks all m draws with .imp and .id", {
  dat <- multi_fixture(n = 20)
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 3, predictors = character(0),
    maxit = 2
  )

  long <- imputed_data(out, imputation = "long")

  expect_equal(nrow(long), 20 * 3)
  expect_setequal(unique(long$.imp), 1:3)
  expect_setequal(unique(long$.id), 1:20)

  # Non-imputed columns are identical across every draw for a given row --
  # there is nothing here for mice to have varied.
  by_id <- split(long, long$.id)
  one_id_each <- vapply(
    by_id, function(d) length(unique(d$.id)) == 1L, logical(1)
  )
  expect_true(all(one_id_each))
})

test_that("imputed_data(x, i) returns every original column", {
  dat <- multi_fixture(n = 20)
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2
  )

  one <- imputed_data(out, imputation = 1)
  expect_equal(names(one), names(dat))
  expect_equal(nrow(one), nrow(dat))
  expect_false(".imp" %in% names(one))
  expect_false(".id" %in% names(one))
})

test_that("method defaults to mice's own per-column dispatch", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2
  )

  methods <- imputation_provenance(out)$method
  expect_equal(unname(methods["age"]), "pmm")
  expect_equal(unname(methods["grp"]), "polyreg")
  expect_equal(unname(methods["flag"]), "logreg")
  # Not all three the same -- the property "never one string across every
  # column" would be trivially true if they all happened to agree.
  expect_gt(length(unique(methods)), 1L)
})

test_that("a `method` override only replaces the named column(s)", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2,
    method = c(age = "norm")
  )

  methods <- imputation_provenance(out)$method
  expect_equal(unname(methods["age"]), "norm")
  expect_equal(unname(methods["grp"]), "polyreg")
  expect_equal(unname(methods["flag"]), "logreg")
})

test_that("`method` must be a named vector, not a single string", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(
      dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
      maxit = 2,
      method = "pmm"
    ),
    "named character vector"
  )
})

test_that("a logical vars column round-trips as logical in every draw", {
  # mice's own default (logreg) silently returns a logical column as plain
  # numeric 0/1 in complete() -- confirmed empirically against mice 3.19.0.
  # impute_multiple() restores the class explicitly; this is the regression
  # test for that restoration.
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 3, predictors = character(0),
    maxit = 2
  )

  long <- imputed_data(out, imputation = "long")
  expect_type(long$flag, "logical")
  for (i in 1:3) {
    expect_type(imputed_data(out, imputation = i)$flag, "logical")
  }
})

test_that("the matrix and row-level accessors are not lists of m", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 4, predictors = character(0),
    maxit = 2
  )

  expect_true(is.matrix(imputed_matrix(out)))
  expect_false(is.list(complete_case_pass(out)))
  expect_false(is.list(analysis_pass(out)))
  expect_length(complete_case_pass(out), nrow(dat))
  expect_length(analysis_pass(out), nrow(dat))
})

test_that("imputed_matrix() matches is.na() on the original data", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2
  )

  mat <- imputed_matrix(out)
  expect_equal(unname(mat[, "age"]), is.na(dat$age))
  expect_equal(unname(mat[, "grp"]), is.na(dat$grp))
  expect_equal(unname(mat[, "flag"]), is.na(dat$flag))
})

test_that("character vars are refused -- levels are not decided silently", {
  dat <- multi_fixture()
  dat$chr <- as.character(dat$grp)
  expect_error(
    impute_multiple(dat, vars = c("age", "chr"), m = 2,
                    predictors = character(0),
                    maxit = 2),
    "still character"
  )
})

test_that("m has no default and is validated", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(dat, vars = c("age", "grp"), m = 0,
                    predictors = character(0),
                    maxit = 2),
    "positive whole number"
  )
  expect_error(
    impute_multiple(dat, vars = c("age", "grp"), m = 1.5,
                    predictors = character(0),
                    maxit = 2),
    "positive whole number"
  )
})

test_that("a `data` column named .imp or .id is refused, not collided", {
  dat <- multi_fixture()
  dat$.imp <- seq_len(nrow(dat))
  expect_error(
    impute_multiple(dat, vars = c("age", "grp"), m = 2,
                    predictors = character(0),
                    maxit = 2),
    "reserved by impute_multiple"
  )

  dat2 <- multi_fixture()
  dat2$.id <- NA_real_
  expect_error(
    impute_multiple(dat2, vars = c("age", "grp"), m = 2,
                    predictors = character(0),
                    maxit = 2),
    "reserved by impute_multiple"
  )
})

test_that(".id is positional, not mice's row-name-derived .id", {
  dat <- multi_fixture(n = 15)
  rownames(dat) <- paste0("row", seq_len(15))
  out <- impute_multiple(dat, vars = c("age", "grp"), m = 2,
                         predictors = character(0),
                         maxit = 2)

  long <- imputed_data(out, imputation = "long")
  expect_type(long$.id, "integer")
  expect_equal(long$.id, rep(1:15, times = 2))
})

test_that("`vars` must name at least two columns", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(dat, vars = "age", m = 2, predictors = character(0),
                    maxit = 2),
    "at least two columns"
  )
})

test_that("`method` must be a character vector with unique names", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(
      dat, vars = c("age", "grp"), m = 2, predictors = character(0), maxit = 2,
      method = list(age = "pmm")
    ),
    "named character vector"
  )
  expect_error(
    impute_multiple(
      dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
      maxit = 2,
      method = c(age = "pmm", age = "norm")
    ),
    "more than once"
  )
})

test_that("a method incompatible with a logical column is refused", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(
      dat, vars = c("age", "grp", "flag"), m = 3, predictors = character(0),
      maxit = 2,
      method = c(flag = "norm")
    ),
    "not 0 or 1"
  )
})

test_that("summary() reports method and counts, with no fill_value", {
  dat <- multi_fixture()
  out <- impute_multiple(
    dat, vars = c("age", "grp", "flag"), m = 2, predictors = character(0),
    maxit = 2
  )

  s <- summary(out)
  expect_setequal(
    names(s), c("variable", "method", "n_imputed", "prop_imputed")
  )
  expect_equal(sort(s$variable), sort(c("age", "grp", "flag")))
})

# predictors (QA decision D1, 2026-11-16) ------------------------------------

# x and z are imputed; y is an outcome strongly tied to x and fully observed.
outcome_fixture <- function(n = 80, seed = 20261116) {
  set.seed(seed)
  y <- stats::rnorm(n)
  dat <- data.frame(
    x = y + stats::rnorm(n, sd = 0.3),
    z = stats::rnorm(n),
    y = y
  )
  dat$x[1:20] <- NA
  dat$z[21:30] <- NA
  dat
}

test_that("the outcome as a predictor changes the draws", {
  dat <- outcome_fixture()
  with_y <- impute_multiple(dat, vars = c("x", "z"), m = 2,
                            predictors = "y", maxit = 3)
  without <- impute_multiple(dat, vars = c("x", "z"), m = 2,
                             predictors = character(0), maxit = 3)

  filled_with <- imputed_data(with_y, imputation = 1)$x[1:20]
  filled_without <- imputed_data(without, imputation = 1)$x[1:20]
  expect_false(isTRUE(all.equal(filled_with, filled_without)))

  # And in the direction that matters: with the outcome informing the
  # draws, the filled x values track y; without it they do not.
  expect_gt(stats::cor(filled_with, dat$y[1:20]),
            stats::cor(filled_without, dat$y[1:20]) + 0.3)
})

test_that("predictors are never imputed and are not in the record", {
  dat <- outcome_fixture()
  out <- impute_multiple(dat, vars = c("x", "z"), m = 2,
                         predictors = "y", maxit = 2)

  long <- imputed_data(out, imputation = "long")
  expect_identical(long$y, rep(dat$y, 2))
  expect_identical(colnames(imputed_matrix(out)), c("x", "z"))
  expect_identical(imputation_provenance(out)$predictors, "y")
  expect_false("y" %in% names(imputation_provenance(out)$method))
})

test_that("omitting predictors warns once per session and runs as before", {
  dat <- outcome_fixture()
  rm(list = ls(.hvti_state), envir = .hvti_state)
  withr::defer(rm(list = ls(.hvti_state), envir = .hvti_state))

  expect_warning(
    old <- impute_multiple(dat, vars = c("x", "z"), m = 2, maxit = 2),
    class = "hvtiRimputation_deprecated"
  )
  expect_warning(
    impute_multiple(dat, vars = c("x", "z"), m = 2, maxit = 2),
    NA
  )
  explicit <- impute_multiple(dat, vars = c("x", "z"), m = 2,
                              predictors = character(0), maxit = 2)
  expect_identical(imputed_data(old, imputation = "long"),
                   imputed_data(explicit, imputation = "long"))
})

test_that("the deprecation warning gives the why and the fix", {
  dat <- outcome_fixture()
  rm(list = ls(.hvti_state), envir = .hvti_state)
  withr::defer(rm(list = ls(.hvti_state), envir = .hvti_state))
  expect_warning(
    impute_multiple(dat, vars = c("x", "z"), m = 1, maxit = 1),
    "toward the null.*time and status.*character\\(0\\).*error in the next"
  )
})

test_that("predictors are validated", {
  dat <- outcome_fixture()
  dat$when <- as.Date("2020-01-01") + seq_len(nrow(dat))
  dat$label <- "a"
  dat$gappy <- dat$y
  dat$gappy[5] <- NA

  call_with <- function(p) {
    impute_multiple(dat, vars = c("x", "z"), m = 1, predictors = p,
                    maxit = 1)
  }
  expect_error(call_with(NULL), "character vector")
  expect_error(call_with(NA_character_), "character vector")
  expect_error(call_with(c("y", "y")), "more than once")
  expect_error(call_with("nope"), "not in `data`")
  expect_error(call_with(c("y", "x")), "both name `x`")
  expect_error(call_with("label"), "still character")
  expect_error(call_with("when"), "days since 1970")
  expect_error(call_with("gappy"), "fully observed")
})

test_that("an ID-like column draws a warning in vars or predictors", {
  dat <- outcome_fixture()
  dat$patient_id <- seq_len(nrow(dat))
  expect_warning(
    impute_multiple(dat, vars = c("x", "z"), m = 1,
                    predictors = c("y", "patient_id"), maxit = 1),
    class = "hvtiRimputation_id_like"
  )
  # A repeated value means it is not an identifier.
  dat$site_id <- rep(1:4, length.out = nrow(dat))
  expect_warning(
    impute_multiple(dat, vars = c("x", "z"), m = 1,
                    predictors = c("y", "site_id"), maxit = 1),
    NA
  )
})

test_that("maxit is validated like m", {
  dat <- outcome_fixture()
  for (bad in list(-1, 0, 1.5, "x", NA, c(1, 2), Inf)) {
    expect_error(
      impute_multiple(dat, vars = c("x", "z"), m = 1,
                      predictors = character(0), maxit = bad),
      "`maxit` must be a single positive whole number"
    )
  }
})

test_that("a constant vars column is refused before mice sees it", {
  dat <- outcome_fixture()
  dat$k <- 5
  dat$k[1] <- NA
  expect_error(
    impute_multiple(dat, vars = c("x", "k"), m = 1,
                    predictors = character(0), maxit = 1),
    "`k`, which takes a single observed value"
  )
  expect_error(
    impute_multiple(dat, vars = c("x", "z"), m = 1,
                    predictors = "k", maxit = 1),
    "fully observed"
  )
  dat$k[1] <- 5
  expect_error(
    impute_multiple(dat, vars = c("x", "z"), m = 1,
                    predictors = "k", maxit = 1),
    "`k`, which takes a single value"
  )
})

test_that("a vars column mice drops as collinear gets mice's reason", {
  dat <- outcome_fixture()
  dat$z2 <- 2 * dat$z
  dat$z2[31] <- NA
  err <- tryCatch(
    suppressWarnings(
      impute_multiple(dat, vars = c("x", "z", "z2"), m = 1,
                      predictors = character(0), maxit = 1)
    ),
    error = conditionMessage
  )
  expect_match(err, "mice removed `z2` as collinear")
  expect_no_match(err, "bug in hvtiRimputation")
})

test_that("an all-missing vars column is refused before mice sees it", {
  dat <- outcome_fixture()
  dat$e <- NA_real_
  expect_error(
    impute_multiple(dat, vars = c("x", "e"), m = 1,
                    predictors = character(0), maxit = 1),
    "`e`, which is missing for every row"
  )
})

test_that("a predictor mice drops draws a warning", {
  dat <- outcome_fixture()
  dat$y2 <- 2 * dat$y
  expect_warning(
    suppressWarnings(
      impute_multiple(dat, vars = c("x", "z"), m = 1,
                      predictors = c("y", "y2"), maxit = 1),
      classes = "simpleWarning"
    ),
    class = "hvtiRimputation_predictor_dropped"
  )
})
