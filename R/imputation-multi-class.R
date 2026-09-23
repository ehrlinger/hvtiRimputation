#' The multiple-imputation record
#'
#' What [impute_multiple()] returns: `m` completed datasets, stacked long,
#' and the record of how they were produced.
#'
#' @section Why long, and why not a list of `m` frames:
#'
#' [hvti_imputation]'s own record is a matrix rather than a count because the
#' record is meant to reduce, never to require reconstruction. The same
#' reasoning picks the storage shape here. A long frame -- one `.imp` column
#' naming the draw, one `.id` column naming the original row, then every
#' column of the input -- reduces to a single completed dataset with one
#' `imputation == 1` filter, and is already the shape a correct downstream
#' analysis expects: fit a model to each draw, then pool the fits. A list of
#' `m` frames does not reduce to anything without picking an element out of
#' the list first. The long form is also the shape `mice::complete(imp,
#' "long")` already returns, and the shape SAS's `PROC MI OUT=` produces --
#' unforced parity with both.
#'
#' @section Why the matrix and the two row-level columns are not lists of `m`:
#'
#' Which cells were originally missing does not change across the `m`
#' draws -- only what they were filled *with* does -- so [imputed_matrix()]
#' is identical for every draw and is stored once. [complete_case_pass()] is
#' read from the input before any imputation runs, so it is the same for
#' every draw by construction. [analysis_pass()] is less obvious but still
#' invariant: `mice` guarantees every column that entered the imputation is
#' complete in every draw, so completeness over `cc_vars` evaluates
#' identically regardless of which draw's values are substituted in. Storing
#' three lists of `m` identical vectors would work, but it would misstate the
#' record -- it would let a caller ask a question ("does row 12's
#' analysis-pass status differ by draw?") that cannot have a "yes" for any
#' input this function accepts.
#'
#' @section What it holds:
#'
#' \describe{
#'   \item{`data_long`}{every column of the input, stacked `m` times with
#'     `.imp` (`1:m`) and `.id` (the original row number) columns added, via
#'     [imputed_data()]}
#'   \item{`matrix`}{the logical record, via [imputed_matrix()]}
#'   \item{`complete_case_pass`}{row-level, read from the input}
#'   \item{`analysis_pass`}{row-level, after imputing}
#'   \item{`provenance`}{method (one per imputed variable), `m`, `maxit`,
#'     and the rest, via [imputation_provenance()]}
#' }
#'
#' @name hvti_imputation_multi
NULL

new_hvti_imputation_multi <- function(data_long, matrix, complete_case_pass,
                                      analysis_pass, provenance) {
  structure(
    list(
      data_long = data_long,
      matrix = matrix,
      complete_case_pass = complete_case_pass,
      analysis_pass = analysis_pass,
      provenance = provenance
    ),
    class = "hvti_imputation_multi"
  )
}

#' @rdname imputation-accessors
#' @param imputation For the `hvti_imputation_multi` method: which completed
#'   dataset to return. A single integer in `1:m`, or `"long"` for all `m`
#'   stacked together. **Required, with no default** -- there is no
#'   zero-argument form that hands back something a caller could average
#'   cell by cell across the `m` draws. See `dev/specs/
#'   2026-09-23-impute-multiple-design.md` for why that specific silent
#'   default would reproduce the exact bug this design was written against.
#' @export
imputed_data.hvti_imputation_multi <- function(x, imputation, ...) {
  m <- x$provenance$m
  if (missing(imputation)) {
    stop(
      "`imputation` is required: pass an integer in 1:", m, " for one ",
      "completed dataset, or \"long\" for all ", m, " stacked together. ",
      "There is no default here on purpose -- averaging the completed ",
      "datasets cell by cell is not a valid way to combine them, and a ",
      "zero-argument call that quietly returned something is how that ",
      "mistake gets made by habit rather than on purpose.",
      call. = FALSE
    )
  }
  if (identical(imputation, "long")) {
    return(x$data_long)
  }
  if (!is.numeric(imputation) || length(imputation) != 1L || is.na(imputation) ||
        !imputation %in% seq_len(m)) {
    stop("`imputation` must be \"long\", or a single integer in 1:", m, ".",
         call. = FALSE)
  }
  out <- x$data_long[x$data_long$.imp == imputation, , drop = FALSE]
  out[[".imp"]] <- NULL
  out[[".id"]] <- NULL
  rownames(out) <- NULL
  out
}

#' @export
print.hvti_imputation_multi <- function(x, ...) {
  p <- x$provenance
  cat("<hvti_imputation_multi>\n")
  cat("  m:       ", p$m, " completed dataset(s) (maxit = ", p$maxit, ")\n",
      sep = "")
  cat("  rows:    ", p$n_row, "\n", sep = "")
  cat("  imputed: ", length(p$vars), " variable(s), ",
      sum(imputed_any(x)), " row(s) touched\n", sep = "")
  cat("  produced by ", p$package, " ", p$version, "\n", sep = "")
  invisible(x)
}

#' Summarise what was imputed, across the m completed datasets
#'
#' Reduces the record to a per-variable table: which method each variable
#' was imputed with, and how many of its values were filled. Unlike
#' [summary.hvti_imputation()], there is no single `fill_value` column --
#' each of the `m` draws can fill a given cell with a different value, which
#' is the entire point of multiple imputation, so no single value speaks for
#' all of them.
#'
#' @param object An object of class `hvti_imputation_multi`.
#' @param ... Ignored.
#'
#' @return A data frame with one row per imputed variable: the variable
#'   name, the method used, the number of values filled, and the proportion
#'   of rows that is.
#'
#' @examples
#' dat <- data.frame(
#'   age = c(50, 60, NA, 70, 65, 55),
#'   grp = factor(c("a", "b", NA, "a", "b", "a"))
#' )
#' out <- impute_multiple(dat, vars = c("age", "grp"), m = 2, maxit = 2)
#' summary(out)
#' @export
summary.hvti_imputation_multi <- function(object, ...) {
  n_imputed <- colSums(object$matrix)
  data.frame(
    variable = colnames(object$matrix),
    method = unname(object$provenance$method[colnames(object$matrix)]),
    n_imputed = as.integer(n_imputed),
    prop_imputed = unname(n_imputed / nrow(object$matrix)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}
