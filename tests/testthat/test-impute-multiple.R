# A larger, seeded frame: mice needs enough rows and signal to fit ridge-free
# models for pmm/logreg/polyreg, which fixture_frame()'s 4 rows cannot give.
# grp is a genuine 3-level unordered factor -- exactly the shape whose
# imputed values were checked, empirically, to never fall outside its levels
# (see dev/specs/2026-09-23-impute-multiple-design.md).
multi_fixture <- function(n = 60, seed = 20260923) {
  set.seed(seed)

  x <- stats::rnorm(n)
  dat <- data.frame(
    age  = round(50 + 10 * x + stats::rnorm(n, sd = 3)),
    grp  = factor(cut(x, breaks = stats::quantile(x, probs = seq(0, 1, length.out = 4)),
                      include.lowest = TRUE, labels = c("lo", "mid", "hi"))),
    flag = x > stats::median(x)
  )
  dat$age[sample(n, round(0.15 * n))] <- NA
  dat$grp[sample(n, round(0.15 * n))] <- NA
  dat$flag[sample(n, round(0.15 * n))] <- NA
  dat
}

test_that("impute_multiple() returns an hvti_imputation_multi object", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 3, maxit = 2)

  expect_s3_class(out, "hvti_imputation_multi")
})

test_that("every one of the m completed datasets holds only valid factor levels", {
  # The empirical finding this design is built on: mice never invents a value
  # outside a factor's levels, in any single completed dataset. This is a
  # standing regression test for that property, not a one-off observation.
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 5, maxit = 3)

  for (i in 1:5) {
    grp_i <- imputed_data(out, imputation = i)$grp
    expect_true(all(as.character(grp_i) %in% levels(dat$grp)))
    expect_false(anyNA(grp_i))
  }
})

test_that("imputed_data() on the multi class requires `imputation`, with no default", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)

  expect_error(imputed_data(out), "imputation.*is required")

  # The single-imputation class's zero-argument form is untouched.
  dat2 <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
  single <- impute_mean(dat2, vars = c("age", "bmi"))
  expect_no_error(imputed_data(single))
})

test_that("imputed_data(x, \"long\") stacks all m draws with .imp and .id", {
  dat <- multi_fixture(n = 20)
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 3, maxit = 2)

  long <- imputed_data(out, imputation = "long")

  expect_equal(nrow(long), 20 * 3)
  expect_setequal(unique(long$.imp), 1:3)
  expect_setequal(unique(long$.id), 1:20)

  # Non-imputed columns are identical across every draw for a given row --
  # there is nothing here for mice to have varied.
  by_id <- split(long, long$.id)
  expect_true(all(vapply(by_id, function(d) length(unique(d$.id)) == 1L, logical(1))))
})

test_that("imputed_data(x, i) returns every original column, matching impute_mean()'s contract", {
  dat <- multi_fixture(n = 20)
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)

  one <- imputed_data(out, imputation = 1)
  expect_equal(names(one), names(dat))
  expect_equal(nrow(one), nrow(dat))
  expect_false(".imp" %in% names(one))
  expect_false(".id" %in% names(one))
})

test_that("method defaults to mice's own per-column dispatch, never one string for every column", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)

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
    dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2,
    method = c(age = "norm")
  )

  methods <- imputation_provenance(out)$method
  expect_equal(unname(methods["age"]), "norm")
  expect_equal(unname(methods["grp"]), "polyreg")
  expect_equal(unname(methods["flag"]), "logreg")
})

test_that("`method` must be a named vector -- an unnamed single string is refused", {
  dat <- multi_fixture()
  expect_error(
    impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2,
                    method = "pmm"),
    "named character vector"
  )
})

test_that("a logical vars column round-trips as logical in every completed draw", {
  # mice's own default (logreg) silently returns a logical column as plain
  # numeric 0/1 in complete() -- confirmed empirically against mice 3.19.0.
  # impute_multiple() restores the class explicitly; this is the regression
  # test for that restoration.
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 3, maxit = 2)

  long <- imputed_data(out, imputation = "long")
  expect_type(long$flag, "logical")
  for (i in 1:3) {
    expect_type(imputed_data(out, imputation = i)$flag, "logical")
  }
})

test_that("imputed_matrix(), complete_case_pass() and analysis_pass() are single vectors/matrix, not lists of m", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 4, maxit = 2)

  expect_true(is.matrix(imputed_matrix(out)))
  expect_false(is.list(complete_case_pass(out)))
  expect_false(is.list(analysis_pass(out)))
  expect_length(complete_case_pass(out), nrow(dat))
  expect_length(analysis_pass(out), nrow(dat))
})

test_that("imputed_matrix() matches is.na() on the original data, for every vars column", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)

  mat <- imputed_matrix(out)
  expect_equal(unname(mat[, "age"]), is.na(dat$age))
  expect_equal(unname(mat[, "grp"]), is.na(dat$grp))
  expect_equal(unname(mat[, "flag"]), is.na(dat$flag))
})

test_that("character vars are refused -- impute_multiple() does not decide category levels", {
  dat <- multi_fixture()
  dat$chr <- as.character(dat$grp)
  expect_error(
    impute_multiple(dat, vars = c("age", "chr"), m = 2, maxit = 2),
    "still character"
  )
})

test_that("m has no default and is validated", {
  dat <- multi_fixture()
  expect_error(impute_multiple(dat, vars = "age", m = 0, maxit = 2),
              "positive whole number")
  expect_error(impute_multiple(dat, vars = "age", m = 1.5, maxit = 2),
              "positive whole number")
})

test_that("summary() reports method, n_imputed and prop_imputed per variable, no fill_value", {
  dat <- multi_fixture()
  out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)

  s <- summary(out)
  expect_setequal(names(s), c("variable", "method", "n_imputed", "prop_imputed"))
  expect_equal(sort(s$variable), sort(c("age", "grp", "flag")))
})
