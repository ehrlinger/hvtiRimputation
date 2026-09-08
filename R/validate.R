# Input validation.
#
# Every check here fails loudly. There is no path through this file that
# imputes fewer variables than asked, or silently leaves a value missing and
# reports it as filled -- the whole point of the record is that it can be
# trusted against an audit, and a record produced by a function that quietly
# narrowed its own scope cannot be.

validate_data <- function(data) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame, not ", class(data)[1], ".",
         call. = FALSE)
  }
  if (nrow(data) == 0L) {
    stop("`data` has no rows, so there is nothing to impute from.",
         call. = FALSE)
  }

  # A duplicated column name makes the record ambiguous, and silently so.
  # `data[["age"]]` returns the FIRST `age`, so naming it in `vars` fills one
  # column, leaves the other missing, and emits a single record column called
  # `age` that does not say which. An audit cannot read that, which is the one
  # thing this package's output has to survive.
  dup <- unique(names(data)[duplicated(names(data))])
  if (length(dup) > 0L) {
    stop("`data` has more than one column named ", collapse_names(dup),
         ". A duplicated name makes the imputation record ambiguous -- it ",
         "cannot say which column a filled value came from. Rename the ",
         "columns before imputing.",
         call. = FALSE)
  }
  data
}

# The fill value has to be a real number before it is written anywhere.
#
# The failure this exists for: `mean(c(Inf, -Inf), na.rm = TRUE)` is `NaN`.
# Assigning it leaves the cell missing while the record marks it filled --
# the record telling an auditor a value was imputed when it was not. An
# infinite mean is rejected for the same reason in the other direction: it is
# not a plausible imputed measurement, and writing it would poison every
# downstream model silently rather than loudly.
validate_fill <- function(value, var) {
  if (length(value) != 1L || !is.finite(value)) {
    what <- if (is.nan(value)) "NaN" else if (is.na(value)) "NA" else
      paste0("`", format(value), "`")
    stop(
      "the mean of `", var, "` is ", what, ", which cannot be used as a fill ",
      "value. This usually means the column holds non-finite values (`Inf`, ",
      "`-Inf`, `NaN`), whose mean is not a number. Filling with it would ",
      "leave the cell missing while the record claimed it was imputed. Clean ",
      "the column, or supply the fill value yourself.",
      call. = FALSE
    )
  }
  invisible(value)
}

validate_vars <- function(data, vars, arg, numeric_only = TRUE) {
  if (!is.character(vars) || anyNA(vars)) {
    stop("`", arg, "` must be a character vector of column names.",
         call. = FALSE)
  }
  if (length(vars) == 0L) {
    stop("`", arg, "` is empty. Name the columns explicitly; this function ",
         "will not choose them for you.", call. = FALSE)
  }
  if (anyDuplicated(vars)) {
    stop("`", arg, "` names ", collapse_names(unique(vars[duplicated(vars)])),
         " more than once.", call. = FALSE)
  }

  unknown <- setdiff(vars, names(data))
  if (length(unknown) > 0L) {
    stop("`", arg, "` names ", collapse_names(unknown),
         ", which ", plural(unknown, "is", "are"), " not in `data`.",
         call. = FALSE)
  }

  if (numeric_only) {
    not_numeric <- vars[!vapply(data[vars], is.numeric, logical(1))]
    if (length(not_numeric) > 0L) {
      stop("mean imputation needs numeric variables, and ",
           collapse_names(not_numeric), " ",
           plural(not_numeric, "is", "are"), " not numeric. ",
           "A mean of a factor or a character column is not defined, and ",
           "guessing one here would be a method choice made silently.",
           call. = FALSE)
    }

    # `is.numeric()` is necessary and not sufficient. A classed numeric --
    # `bit64::integer64`, `Date`, `POSIXct`, `units` -- passes it while
    # carrying storage or interpretation rules this function does not know.
    # `integer64` is the sharp case: it packs a 64-bit integer INTO a double's
    # bits, so taking its mean into an ordinary double reinterprets the bit
    # pattern. Observed: a column of 1 and 3 completed as 0, with the
    # provenance recording 9.88e-324 rather than 2. Wrong data and wrong
    # provenance, no error.
    classed <- vars[vapply(data[vars], function(x) !is.null(oldClass(x)),
                           logical(1))]
    if (length(classed) > 0L) {
      cls <- vapply(data[classed], function(x) oldClass(x)[1], character(1))
      stop("mean imputation needs plain numeric variables, and ",
           paste0("`", classed, "` is <", cls, ">", collapse = ", "),
           ". A classed numeric passes `is.numeric()` while carrying storage ",
           "rules this function does not know, and imputing it silently ",
           "corrupts both the data and the provenance. Convert it yourself ",
           "-- `as.numeric()` for integer64 -- so the conversion is a choice ",
           "you made rather than one made for you.",
           call. = FALSE)
    }
  }

  vars
}

collapse_names <- function(x) {
  paste0("`", x, "`", collapse = ", ")
}

plural <- function(x, one, many) {
  if (length(x) == 1L) one else many
}
