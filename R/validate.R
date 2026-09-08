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
  data
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
  }

  vars
}

collapse_names <- function(x) {
  paste0("`", x, "`", collapse = ", ")
}

plural <- function(x, one, many) {
  if (length(x) == 1L) one else many
}
