# Package-wide helpers that are not input validation.

# The family quiet mode (hvtiR API rubric, 2026-11-16). Every informational
# message goes through here, so `options(hvti.quiet = TRUE)` silences them
# across the hvtiR packages at once. Warnings and errors never go through
# it: a quiet option that could hide a warning would hide the thing the
# warning exists to say.
.hvti_inform <- function(...) {
  if (!isTRUE(getOption("hvti.quiet"))) message(...)
  invisible()
}
