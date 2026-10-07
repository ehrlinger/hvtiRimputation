# Reproducibility of impute_multiple(), and an audit that no random call in
# the package draws from an unseeded RNG.

repro_fixture <- function() {
  withr::with_seed(20260923, {
    n <- 40
    x <- stats::rnorm(n)
    dat <- data.frame(
      age = round(50 + 10 * x + stats::rnorm(n, sd = 3)),
      grp = factor(ifelse(x > 0, "hi", "lo")),
      bmi = 25 + 2 * x + stats::rnorm(n)
    )
    dat$age[sample(n, 6)] <- NA
    dat$grp[sample(n, 6)] <- NA
    dat
  })
}

repro_vars <- c("age", "grp", "bmi")

test_that("the same seed gives the same imputations whatever the RNG state", {
  dat <- repro_fixture()

  set.seed(1)
  a <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2, seed = 7)
  set.seed(999)
  stats::runif(50)
  b <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2, seed = 7)

  expect_identical(
    imputed_data(a, imputation = "long"),
    imputed_data(b, imputation = "long")
  )
})

test_that("a caller's non-default RNGkind() does not change the draws", {
  dat <- repro_fixture()
  a <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2, seed = 7)

  withr::local_preserve_seed()
  old <- RNGkind()
  withr::defer(do.call(RNGkind, as.list(unname(old))))
  RNGkind("L'Ecuyer-CMRG", "Box-Muller", "Rejection")
  b <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2, seed = 7)

  expect_identical(
    imputed_data(a, imputation = "long"),
    imputed_data(b, imputation = "long")
  )
  # R-devel adds a fourth kind (binomial), so compare only the three this
  # test set.
  expect_identical(RNGkind()[1:3],
                   c("L'Ecuyer-CMRG", "Box-Muller", "Rejection"))
})

test_that("impute_multiple() leaves the caller's random stream where it was", {
  dat <- repro_fixture()

  set.seed(3)
  expected <- stats::runif(3)
  set.seed(3)
  impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2, seed = 7)
  expect_identical(stats::runif(3), expected)
})

test_that("the session option supplies the seed, and an explicit one wins", {
  dat <- repro_fixture()
  explicit <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2,
                              seed = 7)

  withr::local_options(hvtiRimputation.seed = 7L)
  from_option <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2)
  expect_identical(
    imputed_data(explicit, imputation = "long"),
    imputed_data(from_option, imputation = "long")
  )
  expect_identical(imputation_provenance(from_option)$seed, 7L)

  overridden <- impute_multiple(dat, vars = repro_vars, m = 2, maxit = 2,
                                seed = 8)
  expect_identical(imputation_provenance(overridden)$seed, 8L)
})

test_that("an unseeded call is refused, not drawn", {
  dat <- repro_fixture()
  withr::local_options(hvtiRimputation.seed = NULL)

  expect_error(
    impute_multiple(dat, vars = repro_vars, m = 2),
    "`seed` is required"
  )
  for (bad in list(NA, NA_integer_, 1.5, c(1, 2), "1", Inf, 2^31)) {
    expect_error(
      impute_multiple(dat, vars = repro_vars, m = 2, seed = bad),
      "`seed` must be a single whole number"
    )
  }
})

# --- Enforcement: no unseeded random call anywhere in R/ -------------------
#
# A call to a function that draws random numbers is "seeded" when it sits
# lexically inside withr::with_seed(). Calls that take their own `seed =`
# must also pass one, and randomForestSRC wants that seed negative: its own
# forest calls otherwise take their seed from R's RNG.

# The audited set. Every stats r* generator is found from the installed
# stats exports, by its d* density partner (rnorm/dnorm, rwilcox/dwilcox),
# so a generator R adds later is covered without editing this list. The r*
# generators with no d* partner, base R's sampling, and the package APIs that
# draw internally are named by hand. A function that draws from the RNG
# without being any of these is outside the audit.
stats_exports <- getNamespaceExports("stats")
stats_r <- grep("^r", stats_exports, value = TRUE)
stats_generators <- stats_r[
  paste0("d", substring(stats_r, 2L)) %in% stats_exports
]
random_fns <- c(
  stats_generators,
  "r2dtable", "rWishart", "rsmirnov", "simulate",
  "sample", "sample.int", "jitter",
  "mice", "rfsrc", "rfsrc.fast", "impute", "impute.rfsrc", "varpro"
)
needs_seed_arg <- c("mice", "rfsrc", "rfsrc.fast", "impute", "impute.rfsrc",
                    "varpro")
needs_negative_seed <- c("rfsrc", "rfsrc.fast", "impute", "impute.rfsrc")

# randomForestSRC's seed must be written negated: `-abs(s)` or `-7`.
is_negated <- function(x) {
  is.call(x) && identical(x[[1]], as.name("-")) && length(x) == 2L
}

call_name <- function(e) {
  head <- e[[1]]
  if (is.symbol(head)) return(as.character(head))
  if (is.call(head) && as.character(head[[1]]) %in% c("::", ":::")) {
    return(as.character(head[[3]]))
  }
  ""
}

unseeded_random_calls <- function(e, seeded = FALSE) {
  if (!is.call(e) && !is.pairlist(e) && !is.expression(e)) {
    return(character())
  }
  found <- character()
  if (is.call(e)) {
    nm <- call_name(e)
    seed_arg <- if ("seed" %in% names(e)) e[["seed"]]
    problem <- if (nm %in% random_fns && !seeded) {
      "not inside withr::with_seed()"
    } else if (nm %in% needs_seed_arg && is.null(seed_arg)) {
      "no `seed =` argument"
    } else if (nm %in% needs_negative_seed && !is_negated(seed_arg)) {
      "randomForestSRC needs a negative seed, e.g. `seed = -abs(s)`"
    }
    if (!is.null(problem)) {
      found <- paste0(deparse(e, nlines = 1L), ": ", problem)
    }
    seeded <- seeded || nm == "with_seed"
  }
  parts <- as.list(e)
  for (i in seq_along(parts)) {
    if (is.symbol(parts[[i]]) && !nzchar(as.character(parts[[i]]))) next
    found <- c(found, unseeded_random_calls(parts[[i]], seeded))
  }
  found
}

test_that("the audit catches an unseeded random call (self-test)", {
  flags <- function(code) unseeded_random_calls(code)

  expect_length(flags(quote(function(x) sample(x))), 1L)
  # Generators the first hand-written list missed, now found from stats.
  for (gen in c("rlnorm", "rnbinom", "rgeom", "rhyper", "rsignrank",
                "rwilcox", "rcauchy")) {
    expect_true(gen %in% random_fns, info = gen)
  }
  expect_length(flags(quote(function(n) stats::rlnorm(n))), 1L)
  expect_length(flags(quote(function(n) rwilcox(n, 3, 4))), 1L)
  expect_length(flags(quote(function(x) x[sample(length(x)), ])), 1L)
  expect_match(flags(quote(function(d) mice::mice(d, m = 1))),
               "not inside", all = FALSE)
  expect_match(
    flags(quote(function(d, s) withr::with_seed(s, mice::mice(d, m = 1)))),
    "no `seed =`"
  )
  expect_match(
    flags(quote(function(d, s) {
      withr::with_seed(s, rfsrc(y ~ ., data = d, seed = s))
    })),
    "negative seed"
  )

  expect_length(
    flags(quote(function(d, s) withr::with_seed(s, mice::mice(d, seed = s)))),
    0L
  )
  expect_length(
    flags(quote(function(d, s) {
      withr::with_seed(abs(s), rfsrc(y ~ ., data = d, seed = -abs(s)))
    })),
    0L
  )
  expect_length(flags(quote(function(x) x[, 1])), 0L)
})

test_that("no function in the package makes an unseeded random call", {
  # Parse R/ when the source tree is available (devtools::test()). Under
  # R CMD check or covr only the installed package is -- and covr's R/ holds
  # the lazy-load database, not .R files -- so audit the namespace instead.
  files <- list.files(test_path("..", "..", "R"), pattern = "[.][Rr]$",
                      full.names = TRUE)
  if (length(files) > 0L) {
    found <- unlist(lapply(files, function(f) {
      hits <- unseeded_random_calls(parse(f, keep.source = FALSE))
      if (length(hits)) paste0(basename(f), ": ", hits)
    }))
  } else {
    ns <- asNamespace("hvtiRimputation")
    fns <- Filter(is.function, mget(ls(ns, all.names = TRUE), envir = ns))
    expect_true("impute_multiple" %in% names(fns))
    found <- unlist(lapply(names(fns), function(nm) {
      hits <- unseeded_random_calls(body(fns[[nm]]))
      if (length(hits)) paste0(nm, ": ", hits)
    }))
  }
  expect_identical(found, NULL, info = paste(found, collapse = "\n"))
})
