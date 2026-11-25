#' Fill missing values with the variable mean
#'
#' Replaces every missing value in `vars` with that variable's mean over its
#' non-missing values, and returns the filled data together with a record of
#' exactly which values were changed.
#'
#' This is the R form of `PROC STANDARD ... REPLACE` with no `MEAN=`/`STD=`,
#' which is what the `imputsub` macro wraps. It is **single** imputation: one
#' completed dataset, and no between-imputation variance. Multiple imputation
#' is [impute_multiple()], a separate function, because a function that
#' quietly does one method when the caller expected the other is a worse
#' failure than no function at all.
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
#' @details
#' **An integer column comes back double.** The fill value is the mean, and
#' a mean is rarely a whole number, so a filled integer column is widened to
#' double rather than rounded. Rounding would make the fill something other
#' than the mean, which is the one thing this function promises to match
#' (`PROC STANDARD` writes the unrounded mean too). Refusing integer columns
#' would turn away every count and every column `read.csv()` read as whole
#' numbers. So the column is widened and you are told, through a message you
#' can silence with `options(hvti.quiet = TRUE)`. A fully observed integer
#' column has nothing filled and keeps its type.
#'
#' **A column that looks like a row identifier draws a warning.** If a name
#' in `vars` is `id`, or ends in `_id` or `.id`, and every observed value is
#' distinct, the call still runs but warns: a patient identifier has no mean
#' worth imputing. The test is deliberately narrow.
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
#'   columns the attrition record consumes. [impute_multiple()] for multiple
#'   imputation.
#' @export
impute_mean <- function(data, vars, cc_vars = names(data)) {
  data <- validate_data(data)
  vars <- validate_vars(data, vars, arg = "vars")
  cc_vars <- validate_vars(data, cc_vars, arg = "cc_vars", numeric_only = FALSE)
  warn_id_like(data, vars, "vars")
  was_integer <- vars[vapply(data[vars], is.integer, logical(1)) &
                        vapply(data[vars], anyNA, logical(1))]

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
      abort(
        "`", v, "` is missing for every row, so it has no mean to impute ",
        "from. Drop the variable or supply the fill value yourself; this ",
        "function will not leave it as NA and call it imputed.",
        call. = FALSE
      )
    }
    value <- mean(data[[v]], na.rm = TRUE)
    validate_fill(value, v)
    fill[[v]] <- value
    # Assign only when something is missing: subassignment widens an
    # integer column to double even when the index selects nothing.
    if (any(missing)) data[[v]][missing] <- value
    record[, v] <- missing

    # The record claims these cells were filled. Prove it, rather than
    # trusting that assignment did what the fill value promised: a fill that
    # is NA or NaN writes a missing value into a cell the record marks TRUE,
    # which is precisely the lie the record exists to make impossible.
    if (anyNA(data[[v]])) {
      abort(
        "`", v, "` still has missing values after imputation, so the record ",
        "would claim a fill that did not happen. This is a bug in ",
        "hvtiRimputation; please report it.",
        class = "unfilled", call. = FALSE
      )
    }
  }

  if (length(was_integer) > 0L) {
    .hvti_inform(
      "impute_mean(): ", collapse_names(was_integer), " ",
      plural(was_integer, "was", "were"), " integer and ",
      plural(was_integer, "is", "are"), " now double, because the fill ",
      "value is the mean and a mean is rarely a whole number. Round ",
      "afterwards if you need integers; the record still marks which ",
      "values were filled."
    )
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
    # No random draw, so seed and rng_kind are NA rather than whatever R's
    # generator happened to hold.
    provenance = c(
      provenance_record(method = "mean"),
      list(
        m = 1L,
        vars = vars,
        cc_vars = cc_vars,
        fill_values = fill,
        n_row = nrow(data)
      )
    )
  )
}
