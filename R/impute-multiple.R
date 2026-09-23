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
#' `impute_multiple()` trusts the class of each `vars` column as the sole
#' signal for what kind of variable it is, and does not re-derive that from
#' its distinct-value count. Deciding a column's type is
#' [r_data_types()][hvtiRutilities::r_data_types()]'s job (or the caller's
#' own `factor()`/`as.logical()`), done once, before imputation -- not a
#' second, independent guess made here that could silently disagree with the
#' first one.
#'
#' @inheritParams impute_mean
#' @param m Number of completed datasets to draw. **Required, with no
#'   default** -- for the same reason `vars` has none in [impute_mean()]: the
#'   SAS corpus's `NIMPUTE` defaults disagree across macro copies, so there
#'   is no single "the default" to inherit.
#' @param method `NULL` (the default) uses `mice`'s own per-column method
#'   selection for every `vars` column. A named character vector overrides
#'   specific columns by name; every column not named keeps its default.
#'   There is no single unnamed string form.
#' @param maxit Number of chained-equations iterations. Passed to
#'   `mice::mice()`.
#' @param seed Passed to `mice::mice()`. `NA` (the default) means `mice`
#'   does not set one.
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
#' **No pooling.** This function returns `m` valid completed datasets and
#' their record. Combining them into a single inferential answer -- fitting
#' a model to each draw and pooling by Rubin's rules -- is the caller's job.
#' Multiple imputation is only multiple imputation once the results are
#' pooled, and that is separate work with its own verification; see the
#' package README.
#'
#' @examples
#' dat <- data.frame(
#'   age = c(50, 60, NA, 70, 65, 55, 58, 62),
#'   grp = factor(c("a", "b", NA, "a", "b", "a", "b", "a")),
#'   flag = c(TRUE, FALSE, TRUE, NA, FALSE, TRUE, FALSE, TRUE)
#' )
#' out <- impute_multiple(dat, vars = c("age", "grp", "flag"), m = 2, maxit = 2)
#' imputed_data(out, imputation = 1)
#' imputed_data(out, imputation = "long")
#' imputed_matrix(out)
#'
#' @seealso [impute_mean()] for single imputation -- there is deliberately no
#'   one function that picks between them. [imputed_any()] and
#'   [complete_case_pass()] for the two row-level columns the attrition
#'   record consumes.
#' @export
impute_multiple <- function(data, vars, m, cc_vars = names(data),
                            method = NULL, maxit = 5L, seed = NA_integer_) {
  data <- validate_data(data)
  vars <- validate_impute_vars(data, vars, arg = "vars")
  cc_vars <- validate_vars(data, cc_vars, arg = "cc_vars", numeric_only = FALSE)
  m <- validate_m(m)

  # Read BEFORE anything is filled, same reasoning as impute_mean()'s cc_pre:
  # evaluated on the completed data every row over `cc_vars` would pass.
  cc_pre <- stats::complete.cases(data[, cc_vars, drop = FALSE])

  record <- matrix(
    FALSE,
    nrow = nrow(data), ncol = length(vars),
    dimnames = list(NULL, vars)
  )
  for (v in vars) record[, v] <- is.na(data[[v]])

  imp_input <- data[vars]
  is_logical_col <- vapply(imp_input, is.logical, logical(1))

  method_vec <- mice::make.method(imp_input)
  if (!is.null(method)) {
    if (is.null(names(method)) || anyNA(names(method)) ||
          any(names(method) == "")) {
      stop(
        "`method` must be a named character vector, naming the columns to ",
        "override -- there is no single method applied to every column. ",
        "Every column not named here keeps mice's own default; see ",
        "mice::make.method().",
        call. = FALSE
      )
    }
    unknown <- setdiff(names(method), vars)
    if (length(unknown) > 0L) {
      stop("`method` names ", collapse_names(unknown), ", which ",
           plural(unknown, "is", "are"), " not in `vars`.", call. = FALSE)
    }
    method_vec[names(method)] <- method
  }

  mice_fit <- mice::mice(
    imp_input, m = m, maxit = maxit, method = method_vec,
    seed = seed, printFlag = FALSE
  )

  completed <- mice::complete(mice_fit, "long")

  # mice loses the `logical` class for a column it imputes with its own
  # default `logreg` method (though not when `pmm` is forced on the same
  # column instead), returning plain 0/1 numeric. Restore it explicitly and
  # assert it below, rather than assume mice's completion preserved a class
  # it is only sometimes faithful to.
  for (v in vars[is_logical_col]) {
    completed[[v]] <- as.logical(completed[[v]])
  }

  still_missing <- vars[vapply(vars, function(v) anyNA(completed[[v]]), logical(1))]
  if (length(still_missing) > 0L) {
    stop(
      "`", paste(still_missing, collapse = "`, `"), "` still has missing ",
      "values after imputation, so the record would claim a fill that did ",
      "not happen. This is a bug in hvtiRimputation; please report it.",
      call. = FALSE
    )
  }

  # Stack the FULL input m times, in the same row order mice's own long
  # format uses (draw 1 rows 1:n, draw 2 rows 1:n, ...), then overwrite just
  # the imputed columns. imputed_data() promises every original column, not
  # only the imputed ones, matching impute_mean()'s own contract.
  row_order <- rep(seq_len(nrow(data)), times = m)
  data_long <- data[row_order, , drop = FALSE]
  rownames(data_long) <- NULL
  for (v in vars) data_long[[v]] <- completed[[v]]
  data_long <- cbind(
    .imp = completed$.imp, .id = completed$.id, data_long
  )

  # analysis_pass is identical for every draw (see hvti_imputation_multi),
  # so it is computed from one of them rather than stored m times.
  one_draw <- data_long[data_long$.imp == 1L, names(data), drop = FALSE]
  cc_post <- stats::complete.cases(one_draw[, cc_vars, drop = FALSE])

  new_hvti_imputation_multi(
    data_long = data_long,
    matrix = record,
    complete_case_pass = cc_pre,
    analysis_pass = cc_post,
    provenance = list(
      method = method_vec[vars],
      m = m,
      maxit = maxit,
      vars = vars,
      cc_vars = cc_vars,
      n_row = nrow(data),
      package = "hvtiRimputation",
      version = as.character(utils::packageVersion("hvtiRimputation")),
      seed = seed,
      time = Sys.time()
    )
  )
}
