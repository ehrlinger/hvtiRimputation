#' Fill missing values with the variable mean
#'
#' Replaces every missing value in `vars` with that variable's mean over its
#' non-missing values, and returns the filled data together with a record of
#' exactly which values were changed.
#'
#' This is the R form of `PROC STANDARD ... REPLACE` with no `MEAN=`/`STD=`,
#' which is what the `imputsub` macro wraps. It is **single** imputation: one
#' completed dataset, and no between-imputation variance. If you want multiple
#' imputation, call `impute_multiple()` -- there is deliberately no one
#' function that picks between them, because a function that quietly does one
#' when the caller expected the other is a worse failure than no function at
#' all.
#'
#' @param data A data frame.
#' @param vars Character vector of columns to impute. **Required, with no
#'   default** -- see Divergences.
#' @param cc_vars Character vector of columns over which `complete_case_pass`
#'   is evaluated, defaulting to every column of `data`. This is the listwise
#'   deletion the imputation is standing in for, so it is usually the whole
#'   analysis frame rather than just `vars`.
#'
#' @return An object of class `hvti_imputation`. [imputed_data()] gives the
#'   completed data frame, [imputed_matrix()] the row-by-variable record of
#'   what was filled, and [imputation_provenance()] how it was produced. See
#'   [hvti_imputation] for the full shape.
#'
#' @section Divergences from SAS:
#'
#' **`vars` is required.** `PROC STANDARD` with no `VAR` statement processes
#' every numeric variable in the dataset. That default is not inherited here,
#' for the same reason `impute_multiple()` inherits no `m`: an imputation that
#' silently chose its own variable list is the failure the record in this
#' package exists to catch. A port that mean-imputes the *wrong* variable list
#' still reaches the right row count and still looks correct; it does not
#' reach the right `sum(imputed_any())`.
#'
#' **`PROC STANDARD MEAN=0 STD=1 REPLACE` is not this function.** That form
#' standardises *and* fills -- in standardised units the fill value 0 is the
#' mean, so it is imputation too, but it also rescales every value including
#' the observed ones. It is not implemented here. Do not reach for
#' `impute_mean()` to reproduce a job that used it.
#'
#' **`BY`-group means are not implemented.** How much of the corpus imputes
#' within `BY` groups has not been measured, so this is a gap rather than a
#' decision.
#'
#' @examples
#' dat <- data.frame(age = c(50, 60, NA, 70), bmi = c(NA, 25, 27, 29))
#' out <- impute_mean(dat, vars = c("age", "bmi"))
#' imputed_data(out)
#' imputed_matrix(out)
#'
#' @seealso [imputed_any()] and [complete_case_pass()] for the two row-level
#'   columns the attrition record consumes. Multiple imputation
#'   (`impute_multiple()`) is designed but not yet implemented; see the README.
#' @export
impute_mean <- function(data, vars, cc_vars = names(data)) {
  data <- validate_data(data)
  vars <- validate_vars(data, vars, arg = "vars")
  cc_vars <- validate_vars(data, cc_vars, arg = "cc_vars", numeric_only = FALSE)

  # Read BEFORE anything is filled. Evaluated on the completed data every row
  # over `vars` would pass, which is the opposite of what the column means.
  cc_pre <- stats::complete.cases(data[, cc_vars, drop = FALSE])

  record <- matrix(
    FALSE,
    nrow = nrow(data), ncol = length(vars),
    dimnames = list(NULL, vars)
  )

  fill <- stats::setNames(rep(NA_real_, length(vars)), vars)
  for (v in vars) {
    missing <- is.na(data[[v]])
    if (all(missing)) {
      stop(
        "`", v, "` is missing for every row, so it has no mean to impute ",
        "from. Drop the variable or supply the fill value yourself; this ",
        "function will not leave it as NA and call it imputed.",
        call. = FALSE
      )
    }
    value <- mean(data[[v]], na.rm = TRUE)
    validate_fill(value, v)
    fill[[v]] <- value
    data[[v]][missing] <- value
    record[, v] <- missing

    # The record claims these cells were filled. Prove it, rather than
    # trusting that assignment did what the fill value promised: a fill that
    # is NA or NaN writes a missing value into a cell the record marks TRUE,
    # which is precisely the lie the record exists to make impossible.
    if (anyNA(data[[v]])) {
      stop(
        "`", v, "` still has missing values after imputation, so the record ",
        "would claim a fill that did not happen. This is a bug in ",
        "hvtiRimputation; please report it.",
        call. = FALSE
      )
    }
  }

  # Post-imputation completeness. Distinct from `cc_pre`, and not derivable
  # from it: a row can have a value filled and STILL be incomplete because a
  # column outside `vars` is missing. Such a row never enters the analysis, so
  # it was not kept by imputation.
  cc_post <- stats::complete.cases(data[, cc_vars, drop = FALSE])

  new_hvti_imputation(
    data = data,
    matrix = record,
    complete_case_pass = cc_pre,
    analysis_pass = cc_post,
    provenance = list(
      method = "mean",
      m = 1L,
      vars = vars,
      cc_vars = cc_vars,
      fill_values = fill,
      n_row = nrow(data),
      package = "hvtiRimputation",
      version = as.character(utils::packageVersion("hvtiRimputation")),
      seed = NA_integer_,
      time = Sys.time()
    )
  )
}
