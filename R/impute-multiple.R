#' Fill missing values with multiple imputation
#'
#' Draws `m` completed datasets by chained-equations multiple imputation
#' (`mice`), and returns them together with a record of exactly what was
#' filled. This is the R form of `PROC MI`, which the `mult_imput` macro
#' wraps.
#'
#' Unlike [impute_mean()], a categorical variable is a normal imputation
#' target here: `method` defaults to `mice::make.method(data[vars])`,
#' `mice`'s own per-column dispatch (`pmm` for numeric, `logreg` for a
#' 2-level factor, `polyreg` for an unordered factor with more than two
#' levels, `polr` for an ordered factor). **There is no single method string
#' applied to every column.** A caller overriding specific columns passes a
#' named character vector naming only those columns; every other column
#' keeps its own default. Forcing one method across a mix of column types is
#' a silent, package-wide default of exactly the kind this package's design
#' avoids for `vars` and `m`, and it is not what `impute_mean()`'s single
#' completed dataset needs multiplied by `m` -- it needs `mice` making its
#' own per-column decision, `m` times.
#'
#' **What informs the draws.** `mice` models each imputed column from the
#' other columns it is given, and it is given `vars` plus `predictors`,
#' nothing else. A column left out of both cannot shape a single draw. That
#' matters most for the outcome. If you impute the covariates without the
#' outcome and then fit a model of the outcome on the completed data, every
#' filled value was drawn as though it had no relationship to the outcome.
#' The association you estimate is a blend of the real one (from observed
#' rows) and zero (from filled ones), so it is biased toward the null, and
#' the more you filled the stronger the pull. Moons and colleagues (2006)
#' and Sterne and colleagues (2009) both make this point, and it is the
#' standard advice for multiple imputation.
#'
#' So `predictors` is **required, with no default**. For an association
#' analysis, name the outcome there: for a survival outcome, both the
#' follow-up time and the event indicator (the Nelson-Aalen cumulative
#' hazard is a better predictor than raw time, per White and Royston,
#' 2009). For a prediction model, an imputation the outcome never saw is
#' defensible, because the model will meet new patients whose outcome is
#' unknown; pass `predictors = character(0)` to make that choice on
#' purpose. Before
#' 0.1.4 the argument did not exist and every call was outcome-free unless
#' the outcome was itself in `vars`. We did not choose that; the function
#' simply had no way to ask. We are still changing our processes to be
#' correct, and a required argument is how the choice gets made, and made
#' visibly, at every call site. In 0.1.4 a call without `predictors` still
#' ran outcome-free, with a warning; from 0.1.5 it is an error.
#'
#' `impute_multiple()` trusts the class of each `vars` column as the sole
#' signal for what kind of variable it is, and does not re-derive that from
#' its distinct-value count. Deciding a column's type is
#' `hvtiRutilities::r_data_types()`'s job (or the caller's own
#' `factor()`/`as.logical()`), done once, before imputation -- not a
#' second, independent guess made here that could silently disagree with the
#' first one.
#'
#' @inheritParams impute_mean
#' @param m Number of completed datasets to draw. **Required, with no
#'   default** -- for the same reason `vars` has none in [impute_mean()]: the
#'   SAS corpus's `NIMPUTE` defaults disagree across macro copies, so there
#'   is no single "the default" to inherit.
#' @param predictors Character vector of columns that inform the
#'   imputation without being imputed: they enter the `mice` data and its
#'   predictor matrix, and their values are never changed. **Required, with
#'   no default**; `character(0)` is the explicit choice of an imputation
#'   that no column outside `vars` informs. For an association analysis this
#'   is where the outcome goes (time and status, for a survival outcome);
#'   see Details for why. Each column must be fully observed, plain numeric,
#'   factor or logical, and not also in `vars`. Omitting the argument is an
#'   error.
#' @param method `NULL` (the default) uses `mice`'s own per-column method
#'   selection for every `vars` column. A named character vector overrides
#'   specific columns by name; every column not named keeps its default.
#'   There is no single unnamed string form.
#' @param maxit Number of chained-equations iterations, a single positive
#'   whole number. Passed to `mice::mice()`.
#' @param seed A single whole number. **Required**, either here or once per
#'   session through `options(hvtiRimputation.seed = )`, which is where the
#'   default reads it from. With neither, the call fails rather than drawing
#'   from an unseeded RNG. Passed to `mice::mice()` and recorded in
#'   [imputation_provenance()].
#'
#' @details
#' **Reproducibility.** The same `data`, arguments and `seed` give the same
#' imputed values whatever state R's random number generator was in
#' beforehand. The call runs under `withr::with_seed()` with the RNG kind
#' pinned to R's defaults (`"Mersenne-Twister"`, `"Inversion"`,
#' `"Rejection"`), so a caller who changed [RNGkind()] still gets the same
#' draws, and the caller's own RNG state is restored afterwards: calling
#' this function does not move their random stream. Before 0.1.2 the default
#' was `seed = NA`, which left the draws to whatever the global RNG held;
#' a call that already passed a seed gets the same values as before when the
#' RNG kind is R's default.
#'
#' **Choosing `m`.** For a prediction model, `m = 1`, an outcome-free
#' single draw (`predictors = character(0)`), is defensible. `m > 1` costs
#' more but lets a downstream variable screen show how much its selection
#' depends on which draw it saw.
#'
#' @return An object of class `hvti_imputation_multi`.
#'   [imputed_data()] with a required `imputation` argument gives one
#'   completed data frame or all `m` stacked long, [imputed_matrix()] the
#'   row-by-variable record of what was filled (identical across every
#'   draw), and [imputation_provenance()] how it was produced. See
#'   [hvti_imputation_multi] for the full shape.
#'
#' @section Divergences from SAS:
#'
#' **`vars` and `m` are both required.** `PROC MI` with no `VAR` statement
#' processes every numeric variable, and its `NIMPUTE` default varies by
#' macro copy in the corpus this package ports. Neither default is
#' inherited here, for the reason recorded in `impute_mean()`'s own
#' Divergences section.
#'
#' **`vars` and `predictors` need at least two columns between them.**
#' `mice::mice()` fits chained equations, so a single column has no other
#' column to condition on, and passing one fails inside `mice` with no
#' context. One imputed variable is fine when a predictor (the outcome,
#' say) supplies the second column. This function checks for it and
#' refuses with an explanation instead.
#'
#' **Columns `mice` drops are reported, not hidden.** `mice` quietly
#' removes a column that is constant or collinear with another before it
#' imputes anything, and records the removal in its `loggedEvents`. If it
#' removed one of `vars`, that column comes back still missing, and this
#' function refuses with the reason `mice` logged. If it removed one of
#' `predictors`, the imputation ran without it, and this function warns,
#' because the column you named to inform the draws did not. `mice` also
#' drops a predictor from a single model when it is linearly dependent on
#' the others among the rows where that model's target is observed, a
#' dependence that need not hold in the full data. That is logged against
#' the imputation method rather than as `"collinear"`, and this function
#' warns for it too, naming the column, the target and how many of the
#' `maxit` x `m` fits lost it. Every event `mice` logged is kept in the
#' provenance as `logged_events`.
#'
#' **`data` cannot use `.imp` or `.id` as column names.** Both are reserved
#' for the long-format draw index and row identifier this function adds.
#'
#' **No pooling.** This function returns `m` valid completed datasets and
#' their record. Combining them into a single inferential answer -- fitting
#' a model to each draw and pooling by Rubin's rules -- is the caller's job.
#' Multiple imputation is only multiple imputation once the results are
#' pooled, and that is separate work with its own verification; see the
#' package README.
#'
#' @examples
#' set.seed(42)
#' n <- 30
#' dat <- data.frame(
#'   age  = round(rnorm(n, 60, 8)),
#'   grp  = factor(sample(c("a", "b", "c"), n, replace = TRUE)),
#'   flag = sample(c(TRUE, FALSE), n, replace = TRUE),
#'   dead = sample(c(0, 1), n, replace = TRUE)
#' )
#' dat$age[sample(n, 4)]  <- NA
#' dat$grp[sample(n, 4)]  <- NA
#' dat$flag[sample(n, 4)] <- NA
#'
#' # `dead` is the outcome: it informs the draws and is never imputed.
#' out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2,
#'                        predictors = "dead", maxit = 2, seed = 1)
#' imputed_data(out, imputation = 1)
#' imputed_data(out, imputation = "long")
#' imputed_matrix(out)
#'
#' @references
#' Moons KGM, Donders RART, Stijnen T, Harrell FE Jr (2006). Using the
#' outcome for imputation of missing predictor values was preferred.
#' *Journal of Clinical Epidemiology*, 59(10), 1092-1101.
#' \doi{10.1016/j.jclinepi.2006.01.009}
#'
#' Sterne JAC, White IR, Carlin JB, et al. (2009). Multiple imputation for
#' missing data in epidemiological and clinical research: potential and
#' pitfalls. *BMJ*, 338, b2393. \doi{10.1136/bmj.b2393}
#'
#' White IR, Royston P (2009). Imputing missing covariate values for the
#' Cox model. *Statistics in Medicine*, 28(15), 1982-1998.
#' \doi{10.1002/sim.3618}
#'
#' @seealso [impute_mean()] for single imputation -- there is deliberately no
#'   one function that picks between them. [imputed_any()] and
#'   [complete_case_pass()] for the two row-level columns the attrition
#'   record consumes.
#' @export
# `predictors` is the last formal, after the defaulted ones, so a call
# written before it existed keeps its positional meaning: the fourth
# positional argument is still `cc_vars`.
impute_multiple <- function(data, vars, m, cc_vars = names(data),
                            method = NULL, maxit = 5L,
                            seed = getOption("hvtiRimputation.seed"),
                            predictors) {
  data <- validate_data(data)

  # .imp and .id are the long-format draw index and row identifier this
  # function adds itself. A `data` column already using either name would
  # collide with them in data_long -- two columns of the same name, the
  # first of which silently wins every $.imp/$.id read -- the same ambiguity
  # validate_data() already refuses for a duplicated column name generally.
  reserved <- intersect(c(".imp", ".id"), names(data))
  if (length(reserved) > 0L) {
    abort(
      "`data` has a column named ", collapse_names(reserved), ", which ",
      plural(reserved, "is", "are"),
      " reserved by impute_multiple() for the long-format draw index and ",
      "row identifier. Rename the column in `data` before calling this ",
      "function.",
      call. = FALSE
    )
  }

  vars <- validate_impute_vars(data, vars, arg = "vars")
  if (missing(predictors)) {
    abort(
      "impute_multiple() needs `predictors`, the columns that inform the ",
      "draws without being imputed. Without them no column outside `vars` ",
      "informs the draws, so the outcome shapes the imputations only if it ",
      "is itself in `vars`, and for an association analysis that biases ",
      "the estimated associations toward the null. Pass the outcome as ",
      "`predictors` (for survival, both time and status), or `predictors = ",
      "character(0)` to choose an outcome-free imputation on purpose, as a ",
      "prediction model may. Until 0.1.5 a call without `predictors` ran ",
      "outcome-free with a warning.",
      call. = FALSE
    )
  }
  predictors <- validate_predictors(data, predictors, vars)
  if (length(vars) + length(predictors) < 2L) {
    abort(
      "impute_multiple() needs at least two columns between `vars` and ",
      "`predictors`. mice::mice() fits chained equations, so the imputed ",
      "variable needs another column to condition on, and with one column ",
      "it fails with an opaque error (\"Data should contain at least two ",
      "columns\"). Name the outcome in `predictors`, add a second column to ",
      "`vars`, or use impute_mean() if a single numeric variable is all you ",
      "need filled.",
      call. = FALSE
    )
  }
  cc_vars <- validate_vars(data, cc_vars, arg = "cc_vars", numeric_only = FALSE)
  m <- validate_m(m)
  maxit <- validate_maxit(maxit)
  seed <- validate_seed(seed)

  # Read BEFORE anything is filled, same reasoning as impute_mean()'s cc_pre:
  # evaluated on the completed data every row over `cc_vars` would pass.
  cc_pre <- stats::complete.cases(data[, cc_vars, drop = FALSE])

  record <- matrix(
    FALSE,
    nrow = nrow(data), ncol = length(vars),
    dimnames = list(NULL, vars)
  )
  for (v in vars) record[, v] <- is.na(data[[v]])

  # Predictors ride along in the mice data so the default predictor matrix
  # uses them for every imputed column; an empty method keeps mice from
  # imputing them (they are fully observed, so it would not anyway).
  imp_input <- data[c(vars, predictors)]
  is_logical_col <- vapply(data[vars], is.logical, logical(1))

  method_vec <- mice::make.method(imp_input)
  method_vec[predictors] <- ""
  if (!is.null(method)) {
    if (!is.character(method) || anyNA(method)) {
      abort(
        "`method` must be a named character vector (or NULL), not ",
        class(method)[1], ".",
        call. = FALSE
      )
    }
    if (is.null(names(method)) || anyNA(names(method)) ||
          any(names(method) == "")) {
      abort(
        "`method` must be a named character vector, naming the columns to ",
        "override -- there is no single method applied to every column. ",
        "Every column not named here keeps mice's own default; see ",
        "mice::make.method().",
        call. = FALSE
      )
    }
    dup <- unique(names(method)[duplicated(names(method))])
    if (length(dup) > 0L) {
      abort("`method` names ", collapse_names(dup), " more than once.",
            call. = FALSE)
    }
    unknown <- setdiff(names(method), vars)
    if (length(unknown) > 0L) {
      abort("`method` names ", collapse_names(unknown), ", which ",
            plural(unknown, "is", "are"), " not in `vars`.", call. = FALSE)
    }
    method_vec[names(method)] <- method
  }

  # mice seeds itself from `seed`, but it does so by calling set.seed() on
  # the caller's global RNG. with_seed() sets the same seed under a pinned
  # RNG kind, so a caller who changed RNGkind() still gets the same draws,
  # and restores the caller's RNG state afterwards.
  rng_kind <- c("Mersenne-Twister", "Inversion", "Rejection")
  mice_fit <- withr::with_seed(
    seed,
    mice::mice(
      imp_input, m = m, maxit = maxit, method = method_vec,
      seed = seed, printFlag = FALSE
    ),
    .rng_kind = rng_kind[[1]],
    .rng_normal_kind = rng_kind[[2]],
    .rng_sample_kind = rng_kind[[3]]
  )

  completed <- mice::complete(mice_fit, "long")

  # mice loses the `logical` class for a column it imputes with its own
  # default `logreg` method (though not when `pmm` is forced on the same
  # column instead), returning plain 0/1 numeric. Restore it explicitly,
  # rather than assume mice's completion preserved a class it is only
  # sometimes faithful to -- but only after checking the values really are
  # 0/1. A `method` override incompatible with a 2-level column (`"norm"`,
  # say) makes mice return an arbitrary continuous draw, and as.logical()
  # maps every nonzero value to TRUE regardless of what it actually was --
  # silently turning a bad method choice into a record that claims success.
  for (v in vars[is_logical_col]) {
    raw <- completed[[v]]
    if (!is.logical(raw)) {
      bad <- !is.na(raw) & !(raw %in% c(0, 1))
      if (any(bad)) {
        abort(
          "`", v, "` is a logical column, but the method used for it (`",
          method_vec[[v]], "`) returned ", format(raw[bad][1]), ", which ",
          "is not 0 or 1. Coercing that to logical would silently map ",
          "every nonzero draw to TRUE. Choose a method for `", v, "` that ",
          "respects a 2-level column (mice's own default, or \"pmm\"), not ",
          "one meant for a continuous variable.",
          call. = FALSE
        )
      }
      completed[[v]] <- as.logical(raw)
    }
  }

  # mice removes a constant or collinear column before imputing anything and
  # says so only in loggedEvents (plus a warning that gives a count). Read
  # the log, so the caller hears the reason rather than a missing value.
  dropped <- mice_dropped(mice_fit)
  warn_model_drops(mice_fit, maxit = maxit, m = m)
  lost_predictors <- intersect(predictors, names(dropped))
  if (length(lost_predictors) > 0L) {
    warning(warningCondition(
      paste0(
        "mice removed ", collapse_names(lost_predictors), " from the ",
        "model as ", paste(unique(dropped[lost_predictors]), collapse = "/"),
        ", so ", plural(lost_predictors, "it", "they"), " did not inform ",
        "the draws although `predictors` named ",
        plural(lost_predictors, "it", "them"), ". Check ",
        plural(lost_predictors, "that column", "those columns"),
        " against the others."
      ),
      class = "hvtiRimputation_predictor_dropped"
    ))
  }

  still_missing <- vars[
    vapply(vars, function(v) anyNA(completed[[v]]), logical(1))
  ]
  explained <- intersect(still_missing, names(dropped))
  if (length(explained) > 0L) {
    reason <- ifelse(
      dropped[explained] == "constant",
      "constant (its observed values do not vary)",
      paste0(dropped[explained], " with other columns in the model")
    )
    abort(
      "mice removed ",
      paste0("`", explained, "` as ", reason, collapse = "; "),
      " before imputing, so its missing values were never filled. Drop ",
      plural(explained, "it", "them"), " from `vars`. A constant column ",
      "can be filled with its one observed value by hand; a collinear one ",
      "is better left out, or replaced by the column it duplicates.",
      class = "unfilled", call. = FALSE
    )
  }
  if (length(still_missing) > 0L) {
    abort(
      "`", paste(still_missing, collapse = "`, `"), "` still has missing ",
      "values after imputation, so the record would claim a fill that did ",
      "not happen. This is a bug in hvtiRimputation; please report it.",
      class = "unfilled", call. = FALSE
    )
  }

  # Stack the FULL input m times, in the same row order mice's own long
  # format uses (draw 1 rows 1:n, draw 2 rows 1:n, ...), then overwrite just
  # the imputed columns. imputed_data() promises every original column, not
  # only the imputed ones, matching impute_mean()'s own contract.
  # .id is positional (1:nrow(data)), not mice::complete()'s own .id, which
  # copies `data`'s row names verbatim -- a custom or filtered row name
  # ("row1", or a non-consecutive original row number) would otherwise
  # contradict the class's own documented contract that .id is the original
  # row *number*, and the record here is positional throughout.
  row_order <- rep(seq_len(nrow(data)), times = m)
  data_long <- data[row_order, , drop = FALSE]
  rownames(data_long) <- NULL
  for (v in vars) data_long[[v]] <- completed[[v]]
  data_long <- cbind(.imp = completed$.imp, .id = row_order, data_long)

  # analysis_pass is identical for every draw (see hvti_imputation_multi),
  # so it is computed from one of them rather than stored m times.
  one_draw <- data_long[data_long$.imp == 1L, names(data), drop = FALSE]
  cc_post <- stats::complete.cases(one_draw[, cc_vars, drop = FALSE])

  new_hvti_imputation_multi(
    data_long = data_long,
    matrix = record,
    complete_case_pass = cc_pre,
    analysis_pass = cc_post,
    provenance = c(
      provenance_record(
        method = method_vec[vars], seed = seed, rng_kind = rng_kind
      ),
      list(
        m = m,
        maxit = maxit,
        vars = vars,
        predictors = predictors,
        logged_events = logged_events(mice_fit),
        cc_vars = cc_vars,
        n_row = nrow(data)
      )
    )
  )
}

# The columns mice removed from the model before imputing, named by column,
# valued by the reason it logged ("constant", "collinear"). Empty when it
# removed nothing.
mice_dropped <- function(mice_fit) {
  ev <- mice_fit$loggedEvents
  if (is.null(ev) || nrow(ev) == 0L || !all(c("meth", "out") %in% names(ev))) {
    return(stats::setNames(character(0), character(0)))
  }
  ev <- ev[ev$meth %in% c("constant", "collinear"), , drop = FALSE]
  out <- strsplit(as.character(ev$out), ", ", fixed = TRUE)
  stats::setNames(rep(as.character(ev$meth), lengths(out)), unlist(out))
}

# Every event mice logged, as a data frame with mice's own columns (it, im,
# dep, meth, out); zero rows when it logged none.
logged_events <- function(mice_fit) {
  ev <- mice_fit$loggedEvents
  if (is.null(ev)) {
    return(data.frame(it = integer(0), im = integer(0), dep = character(0),
                      meth = character(0), out = character(0)))
  }
  ev
}

# mice drops a predictor from one target's model, inside a single iteration
# and draw, when it is linearly dependent on the other predictors among the
# rows where that target is observed. It logs the event under the target's
# imputation method (pmm, logreg, ...), not as "collinear", so
# mice_dropped() does not see it, and the dependence need not exist in the
# full data. Say which column, for which target, in how many of the
# maxit x m fits.
warn_model_drops <- function(mice_fit, maxit, m) {
  ev <- logged_events(mice_fit)
  ev <- ev[!(ev$meth %in% c("constant", "collinear")) & nzchar(ev$dep),
           , drop = FALSE]
  if (nrow(ev) == 0L) return(invisible())
  out <- strsplit(as.character(ev$out), ", ", fixed = TRUE)
  pairs <- data.frame(
    dep = rep(as.character(ev$dep), lengths(out)),
    out = unlist(out),
    fit = rep(paste(ev$it, ev$im), lengths(out))
  )
  pairs <- unique(pairs)
  counts <- stats::aggregate(fit ~ out + dep, data = pairs, FUN = length)
  lines <- paste0(
    "`", counts$out, "` from the model for `", counts$dep, "` in ",
    counts$fit, " of ", maxit * m, " fits"
  )
  warning(warningCondition(
    paste0(
      "mice dropped a predictor from an imputation model as linearly ",
      "dependent on the others, among the rows where that model's target ",
      "is observed: ", paste(lines, collapse = "; "), ". In those fits ",
      "the column did not inform the draws. The full list is in ",
      "imputation_provenance()$logged_events."
    ),
    class = "hvtiRimputation_predictor_dropped"
  ))
  invisible()
}
