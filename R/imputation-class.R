#' The imputation record
#'
#' What every function in this package returns: the completed data, and a
#' record of exactly what was changed to complete it.
#'
#' @section Why a matrix and not a count:
#'
#' The record is a logical matrix parallel to the data -- one row per row of
#' the input, one column per imputed variable, `TRUE` where the value was
#' filled. A summary saying "12 values were imputed in this variable" cannot
#' answer *was this patient's value imputed?*, which is the question an audit
#' asks. The matrix answers it directly and can be reduced to any count; the
#' reverse is impossible.
#'
#' The matrix form is chosen over a long data frame deliberately. It lines up
#' with the data row for row without a join, and it stays small for a wide
#' dataset. A long form reads more easily and is much larger, and the reading
#' is what [summary.hvti_imputation()] is for.
#'
#' @section What it holds:
#'
#' \describe{
#'   \item{`data`}{the completed data frame, via [imputed_data()]}
#'   \item{`matrix`}{the logical record, via [imputed_matrix()]}
#'   \item{`complete_case_pass`}{row-level: would this row have survived
#'     listwise deletion? Read from the input, before anything was filled}
#'   \item{`provenance`}{method, `m`, the package version that produced it,
#'     and the seed where the method is stochastic, via
#'     [imputation_provenance()]}
#' }
#'
#' An imputed dataset that does not say how it was imputed cannot be
#' reproduced. The SAS corpus this package ports is the proof: thirty years of
#' imputed datasets whose method is now only partly recoverable, and only by
#' scanning the code that produced them. So the provenance is not optional and
#' travels with the artifact.
#'
#' @name hvti_imputation
NULL

new_hvti_imputation <- function(data, matrix, complete_case_pass, provenance) {
  structure(
    list(
      data = data,
      matrix = matrix,
      complete_case_pass = complete_case_pass,
      provenance = provenance
    ),
    class = "hvti_imputation"
  )
}

#' Read an imputation record
#'
#' Accessors for the object [impute_mean()] returns.
#'
#' `imputed_any()` and `complete_case_pass()` are the two row-level columns the
#' attrition record consumes. They enter a CONSORT tracker as an **annotation**
#' -- a stage that records something about the rows without removing any -- and
#' not as an exclusion. Rows kept only because a covariate was filled in are
#' not excluded, and they are not fully observed either, and a record with no
#' vocabulary for that third state will misreport one or the other. The
#' counterfactual is `imputed_any(x) & !complete_case_pass(x)`: the rows in the
#' analysis *only* because something was filled.
#'
#' @param x An object of class [hvti_imputation].
#'
#' @return `imputed_data()` a data frame; `imputed_matrix()` a logical matrix;
#'   `imputed_any()` and `complete_case_pass()` logical vectors, one element
#'   per row; `imputation_indicators()` a data frame of logical columns;
#'   `imputation_provenance()` a list.
#'
#' @examples
#' dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
#' out <- impute_mean(dat, vars = c("age", "bmi"))
#'
#' imputed_any(out)
#' complete_case_pass(out)
#'
#' # Rows in the analysis only because a covariate was filled:
#' sum(imputed_any(out) & !complete_case_pass(out))
#'
#' @name imputation-accessors
NULL

#' @rdname imputation-accessors
#' @export
imputed_data <- function(x) {
  stopifnot(inherits(x, "hvti_imputation"))
  x$data
}

#' @rdname imputation-accessors
#' @export
imputed_matrix <- function(x) {
  stopifnot(inherits(x, "hvti_imputation"))
  x$matrix
}

#' @rdname imputation-accessors
#' @export
imputed_any <- function(x) {
  stopifnot(inherits(x, "hvti_imputation"))
  unname(rowSums(x$matrix) > 0L)
}

#' @rdname imputation-accessors
#' @export
complete_case_pass <- function(x) {
  stopifnot(inherits(x, "hvti_imputation"))
  unname(x$complete_case_pass)
}

#' @rdname imputation-accessors
#' @export
imputation_provenance <- function(x) {
  stopifnot(inherits(x, "hvti_imputation"))
  x$provenance
}

#' Missingness indicators, generated from the record
#'
#' Returns one logical column per imputed variable, `TRUE` where that
#' variable's value was filled. A caller reproducing a SAS analysis that
#' carried `ms_*` indicators as model terms renames in one step:
#' `imputation_indicators(x, prefix = "ms_")`.
#'
#' The indicators are generated rather than stored, and the SAS `ms_` naming is
#' not the default. A convention adopted for parity becomes permanent -- it
#' would be ours to maintain forever the moment a study depended on it -- so
#' the record stays the single source of truth and the name stays the caller's
#' choice.
#'
#' The principle underneath is not negotiable and predates the naming: **a
#' value that means "observed" and a value that means "filled in" must not be
#' the same value.** The indicators are how that survives into a model.
#'
#' @inheritParams imputed_data
#' @param prefix Prepended to each imputed variable's name. Defaults to
#'   `"imputed_"`.
#'
#' @return A data frame of logical columns, one per imputed variable, with
#'   `nrow()` matching the imputed data.
#'
#' @examples
#' dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
#' out <- impute_mean(dat, vars = c("age", "bmi"))
#' imputation_indicators(out)
#' imputation_indicators(out, prefix = "ms_")
#' @export
imputation_indicators <- function(x, prefix = "imputed_") {
  stopifnot(inherits(x, "hvti_imputation"))
  if (!is.character(prefix) || length(prefix) != 1L || is.na(prefix)) {
    stop("`prefix` must be a single string.", call. = FALSE)
  }
  out <- as.data.frame(x$matrix)
  names(out) <- paste0(prefix, colnames(x$matrix))
  out
}

#' @export
print.hvti_imputation <- function(x, ...) {
  p <- x$provenance
  cat("<hvti_imputation>\n")
  cat("  method:  ", p$method, " (m = ", p$m, ")\n", sep = "")
  cat("  rows:    ", p$n_row, "\n", sep = "")
  cat("  imputed: ", length(p$vars), " variable(s), ",
      sum(imputed_any(x)), " row(s) touched\n", sep = "")
  cat("  produced by ", p$package, " ", p$version, "\n", sep = "")
  invisible(x)
}

#' Summarise what was imputed
#'
#' Reduces the record to a per-variable table. It is a view of
#' [imputed_matrix()], never a replacement for it: a count cannot say whether a
#' particular row was filled.
#'
#' @param object An object of class [hvti_imputation].
#' @param ... Ignored.
#'
#' @return A data frame with one row per imputed variable: the variable name,
#'   the number of values filled, the proportion of rows that is, and the
#'   value used to fill them.
#'
#' @examples
#' dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
#' summary(impute_mean(dat, vars = c("age", "bmi")))
#' @export
summary.hvti_imputation <- function(object, ...) {
  n_imputed <- colSums(object$matrix)
  data.frame(
    variable = colnames(object$matrix),
    n_imputed = as.integer(n_imputed),
    prop_imputed = unname(n_imputed / nrow(object$matrix)),
    fill_value = unname(object$provenance$fill_values[colnames(object$matrix)]),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}
