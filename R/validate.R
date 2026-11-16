# Input validation.
#
# Every check here fails loudly. There is no path through this file that
# imputes fewer variables than asked, or silently leaves a value missing and
# reports it as filled -- the whole point of the record is that it can be
# trusted against an audit, and a record produced by a function that quietly
# narrowed its own scope cannot be.

validate_data <- function(data) {
  if (!is.data.frame(data)) {
    abort("`data` must be a data frame, not ", class(data)[1], ".",
          call. = FALSE)
  }
  if (nrow(data) == 0L) {
    abort("`data` has no rows, so there is nothing to impute from.",
          call. = FALSE)
  }

  # A duplicated column name makes the record ambiguous, and silently so.
  # `data[["age"]]` returns the FIRST `age`, so naming it in `vars` fills one
  # column, leaves the other missing, and emits a single record column called
  # `age` that does not say which. An audit cannot read that, which is the one
  # thing this package's output has to survive.
  dup <- unique(names(data)[duplicated(names(data))])
  if (length(dup) > 0L) {
    abort("`data` has more than one column named ", collapse_names(dup),
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
    abort(
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
    abort("`", arg, "` must be a character vector of column names.",
          call. = FALSE)
  }
  if (length(vars) == 0L) {
    abort("`", arg, "` is empty. Name the columns explicitly; this function ",
          "will not choose them for you.", call. = FALSE)
  }
  if (anyDuplicated(vars)) {
    abort("`", arg, "` names ", collapse_names(unique(vars[duplicated(vars)])),
          " more than once.", call. = FALSE)
  }

  unknown <- setdiff(vars, names(data))
  if (length(unknown) > 0L) {
    abort("`", arg, "` names ", collapse_names(unknown),
          ", which ", plural(unknown, "is", "are"), " not in `data`.",
          call. = FALSE)
  }

  if (numeric_only) {
    not_numeric <- vars[!vapply(data[vars], is.numeric, logical(1))]
    if (length(not_numeric) > 0L) {
      abort("mean imputation needs numeric variables, and ",
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
      abort("mean imputation needs plain numeric variables, and ",
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

# `vars` for impute_multiple(). Unlike impute_mean(), a categorical column is
# a valid imputation target -- mice already knows how to model numeric,
# factor and logical columns via its own per-column method dispatch. What it
# does not know how to model is a column whose type is still undecided
# (character) or whose storage rules are invisible to it (a classed
# numeric), so those are refused for the same reason impute_mean() refuses
# them: guessing either silently is a method choice made for the caller
# rather than by them.
validate_impute_vars <- function(data, vars, arg = "vars") {
  vars <- validate_vars(data, vars, arg = arg, numeric_only = FALSE)

  is_character <- vars[vapply(data[vars], is.character, logical(1))]
  if (length(is_character) > 0L) {
    abort(
      "`", arg, "` names ", collapse_names(is_character), ", which ",
      plural(is_character, "is", "are"), " still character. ",
      "impute_multiple() does not decide what a category's levels are -- ",
      "convert with factor() or r_data_types() first, so the levels are a ",
      "choice you made rather than one made for you.",
      call. = FALSE
    )
  }

  unsupported <- vars[!vapply(data[vars], is_mice_class, logical(1))]
  if (length(unsupported) > 0L) {
    cls <- vapply(data[unsupported], function(x) oldClass(x)[1], character(1))
    abort(
      "mice has no documented imputation method for ",
      paste0("`", unsupported, "` <", cls, ">", collapse = ", "), ". ",
      "Supported column classes are plain numeric, factor and logical; a ",
      "classed numeric (Date, POSIXct, integer64) passes `is.numeric()` ",
      "while carrying storage rules mice does not know about. Convert it ",
      "yourself, so the conversion is a choice you made.",
      call. = FALSE
    )
  }

  # An all-missing column gives mice nothing to model. mice drops it and
  # then either fails with "No predictors were left" or returns it still
  # missing, neither of which names the column or the reason.
  all_missing <- vars[vapply(data[vars], function(x) all(is.na(x)),
                             logical(1))]
  if (length(all_missing) > 0L) {
    abort(
      "`", arg, "` names ", collapse_names(all_missing), ", which ",
      plural(all_missing, "is", "are"), " missing for every row, so there ",
      "is nothing to model ", plural(all_missing, "it", "them"), " from. ",
      "Drop ", plural(all_missing, "it", "them"), " from `", arg, "`.",
      call. = FALSE
    )
  }

  # A constant column has no variation to model. mice removes it before
  # imputing and then either returns it still missing or, when nothing else
  # is left, fails with "No predictors were left after their removal".
  constant <- vars[vapply(data[vars], is_constant, logical(1))]
  if (length(constant) > 0L) {
    abort(
      "`", arg, "` names ", collapse_names(constant), ", which ",
      plural(constant, "takes", "take"), " a single observed value. mice ",
      "removes a constant column before imputing, so its missing values ",
      "would never be filled. Fill ", plural(constant, "it", "them"),
      " with that value yourself, or drop ", plural(constant, "it", "them"),
      " from `", arg, "`.",
      call. = FALSE
    )
  }

  warn_id_like(data, vars, arg)
  vars
}

is_constant <- function(x) {
  length(unique(x[!is.na(x)])) == 1L
}

is_mice_class <- function(x) {
  (is.numeric(x) && is.null(oldClass(x))) || is.factor(x) || is.logical(x)
}

# `predictors` for impute_multiple(): columns that enter the mice model and
# inform every imputed variable, but are never imputed themselves.
#
# They must be fully observed. mice accepts an incomplete column with an
# empty method and runs, but what it does with the missing predictor values
# is undocumented, and the draws change when it does it. A covariate with
# gaps belongs in `vars`, where it is imputed and its fills are on the
# record.
validate_predictors <- function(data, predictors, vars) {
  if (!is.character(predictors) || anyNA(predictors)) {
    abort("`predictors` must be a character vector of column names, or ",
          "character(0) for an imputation that no column outside `vars` ",
          "informs.", call. = FALSE)
  }
  if (length(predictors) == 0L) return(character(0))
  predictors <- validate_vars(data, predictors, arg = "predictors",
                              numeric_only = FALSE)
  both <- intersect(predictors, vars)
  if (length(both) > 0L) {
    abort("`predictors` and `vars` both name ", collapse_names(both), ". A ",
          "column in `vars` already informs the other imputations; ",
          "`predictors` is for columns that inform them without being ",
          "imputed. Name each column in one or the other.", call. = FALSE)
  }

  is_character <- predictors[vapply(data[predictors], is.character,
                                    logical(1))]
  if (length(is_character) > 0L) {
    abort("`predictors` names ", collapse_names(is_character), ", which ",
          plural(is_character, "is", "are"), " still character. Convert ",
          "with factor() first, so the levels are a choice you made.",
          call. = FALSE)
  }
  unsupported <- predictors[!vapply(data[predictors], is_mice_class,
                                    logical(1))]
  if (length(unsupported) > 0L) {
    cls <- vapply(data[unsupported], function(x) oldClass(x)[1], character(1))
    abort("`predictors` names ",
          paste0("`", unsupported, "` <", cls, ">", collapse = ", "),
          ". A predictor must be plain numeric, factor or logical. A date ",
          "would enter the model as days since 1970, which is rarely the ",
          "quantity you mean; derive the number you do mean (years since ",
          "surgery, say) and pass that.", call. = FALSE)
  }

  incomplete <- predictors[vapply(data[predictors], anyNA, logical(1))]
  if (length(incomplete) > 0L) {
    abort("`predictors` names ", collapse_names(incomplete), ", which ",
          plural(incomplete, "has", "have"), " missing values. A predictor ",
          "is not imputed, so it must be fully observed. Move ",
          plural(incomplete, "it", "them"), " to `vars` to have ",
          plural(incomplete, "it", "them"), " imputed and informing the ",
          "others at the same time.", call. = FALSE)
  }

  constant <- predictors[vapply(data[predictors], is_constant, logical(1))]
  if (length(constant) > 0L) {
    abort("`predictors` names ", collapse_names(constant), ", which ",
          plural(constant, "takes", "take"), " a single value. A constant ",
          "carries no information to inform the draws, and mice would drop ",
          plural(constant, "it", "them"), " silently.", call. = FALSE)
  }

  warn_id_like(data, predictors, "predictors")
  predictors
}

# A row identifier imputed, or used to inform an imputation, is noise at
# best. The check is deliberately narrow, so it fires on the obvious case
# only: a column named `id`, or ending in `_id` or `.id`, whose observed
# values are all distinct. It warns rather than refuses, because a name is
# a guess and a refusal would leave a false positive with no way through.
warn_id_like <- function(data, cols, arg) {
  looks_like_id <- vapply(cols, function(v) {
    x <- data[[v]][!is.na(data[[v]])]
    grepl("(^|[._])id$", v, ignore.case = TRUE) && length(x) > 1L &&
      !anyDuplicated(x)
  }, logical(1))
  id_cols <- cols[looks_like_id]
  if (length(id_cols) > 0L) {
    warning(warningCondition(
      paste0(
        "`", arg, "` names ", collapse_names(id_cols), ", which ",
        plural(id_cols, "looks", "look"), " like a row identifier: the ",
        "name ends in `id` and every observed value is distinct. An ",
        "identifier carries no information about the patient, so ",
        "imputing it, or letting it inform other imputations, adds ",
        "noise. Drop it from `", arg, "` unless it is a real measurement."
      ),
      class = "hvtiRimputation_id_like"
    ))
  }
  invisible(cols)
}

# `m` has no default for the same reason `vars` has none in impute_mean():
# the SAS corpus's NIMPUTE defaults disagree across macro copies, so there is
# no single "the default" this package could inherit without silently
# choosing a method (single vs. multiple imputation) the caller did not ask
# for.
validate_m <- function(m) {
  if (!is_count(m)) {
    abort("`m` must be a single positive whole number. impute_multiple() ",
          "will not choose it for you.", call. = FALSE)
  }
  as.integer(m)
}

# `maxit` has a default, but an unvalidated one reaches mice::mice() and
# fails there with an error about array lengths or binary operators that
# names neither the argument nor the fix. Zero is refused too: mice accepts
# it and returns its starting values, random draws from the observed data
# with no chained equations run at all, which is not the method the caller
# asked for.
validate_maxit <- function(maxit) {
  if (!is_count(maxit)) {
    abort("`maxit` must be a single positive whole number, the number of ",
          "chained-equations iterations, not ", deparse(maxit)[1], ".",
          call. = FALSE)
  }
  as.integer(maxit)
}

is_count <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 1 && x %% 1 == 0 &&
    x <= .Machine$integer.max
}

# `seed` arrives either from the caller or from
# getOption("hvtiRimputation.seed"); NULL means neither supplied one. An
# unseeded draw is refused rather than defaulted: a fixed package seed would
# give every study the same draws without anyone choosing that, and NA would
# leave the result hostage to whatever R's RNG state happened to be.
validate_seed <- function(seed) {
  if (is.null(seed)) {
    abort("`seed` is required. Pass `seed =`, or set ",
          "options(hvtiRimputation.seed = <whole number>) once for the ",
          "session. impute_multiple() will not draw from an unseeded RNG, ",
          "because the result could not be reproduced.", call. = FALSE)
  }
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
        seed %% 1 != 0 || abs(seed) > .Machine$integer.max) {
    abort("`seed` must be a single whole number (an integer), not ",
          deparse(seed)[1], ".", call. = FALSE)
  }
  as.integer(seed)
}
