# Errors and the provenance record, in the shapes the hvtiR API rubric
# (2026-11-16) fixes for the whole family. Each package implements these
# locally rather than importing a shared helper, and carries a conformance
# test for each.

# Every error this package raises carries two classes: a specific one,
# `hvtiRimputation_<condition>`, and the umbrella `hvtiRimputation_error`.
# A caller can catch either without matching message text.
#
#   invalid_input  an argument or a column of `data` was refused, before
#                  anything was filled
#   unfilled       a value the record would mark as filled is still
#                  missing; the check that keeps the record honest
#
# `call.` is accepted so a call site reads like base::stop(); the call is
# never recorded, because every message already says what went wrong.
# nolint next: object_name_linter.
abort <- function(..., class = "invalid_input", call. = FALSE) {
  stop(errorCondition(
    paste0(...),
    class = c(paste0("hvtiRimputation_", class), "hvtiRimputation_error"),
    call = NULL
  ))
}

# The seven fields every hvtiR provenance record starts with. A field that
# does not apply is NA of its type, so a provenance table prints a gap
# rather than a plausible value. Package-specific fields follow.
provenance_record <- function(method, seed = NA_integer_,
                              rng_kind = rep(NA_character_, 3L)) {
  pkg <- "hvtiRimputation"
  sha <- utils::packageDescription(pkg, fields = "RemoteSha")
  list(
    package = pkg,
    version = as.character(utils::packageVersion(pkg)),
    sha = if (is.character(sha) && length(sha) == 1L && !is.na(sha)) sha else
      NA_character_,
    method = method,
    seed = as.integer(seed),
    rng_kind = as.character(rng_kind),
    time = Sys.time()
  )
}
