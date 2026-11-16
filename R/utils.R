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

# Session state for once-per-session deprecation warnings. A flag set here
# lasts until the namespace is unloaded, which is what "once per session"
# means for a package.
.hvti_state <- new.env(parent = emptyenv())

warn_once <- function(id, message, class) {
  if (isTRUE(.hvti_state[[id]])) return(invisible(FALSE))
  .hvti_state[[id]] <- TRUE
  warning(warningCondition(message, class = class))
  invisible(TRUE)
}
