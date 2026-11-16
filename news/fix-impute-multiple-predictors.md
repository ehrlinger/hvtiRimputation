* **`impute_multiple()` gains a required `predictors` argument.** Columns
  named there enter the `mice` model and inform every draw, and are never
  imputed. For an association analysis the outcome belongs there (time and
  status, for a survival outcome); otherwise every filled value is drawn as
  though it had no relationship to the outcome, and the estimated
  associations are biased toward the null. `predictors = character(0)` is the
  explicit outcome-free choice, defensible for a prediction model. A call
  without `predictors` runs as before with a once-per-session warning (class
  `hvtiRimputation_deprecated`); in the next release it is an error. Each
  predictor must be fully observed, plain numeric, factor or logical, not
  constant, and not also in `vars`.

* `impute_multiple()` validates `maxit` as a single positive whole number,
  instead of failing inside `mice` with an error about array lengths.

* `impute_multiple()` refuses an all-missing or constant `vars` column
  before calling `mice`, and when `mice` drops a column as collinear it
  reports the reason from `mice`'s `loggedEvents` rather than calling it a
  bug in this package. A predictor `mice` drops draws a warning.

* `impute_mean()` keeps a fully observed integer column integer, and says so
  (through a message `options(hvti.quiet = TRUE)` silences) when it widens a
  filled integer column to double.

* A column in `vars` or `predictors` that looks like a row identifier (named
  `id`, or ending `_id` or `.id`, with every observed value distinct) draws a
  warning of class `hvtiRimputation_id_like`.

* The accessors refuse a non-imputation object with a message naming what
  they expected, instead of a bare `stopifnot()` failure.

* `predictors` is the last formal of `impute_multiple()`, so a call written
  before it existed keeps its positional meaning. One variable in `vars` is
  enough when `predictors` supplies a second column. A predictor `mice` drops
  from a single model (linearly dependent among the rows where that model's
  target is observed) draws a warning naming the column, the target and the
  number of fits, and every event `mice` logged is kept in the provenance as
  `logged_events`.
