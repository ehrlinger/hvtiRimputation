# A frame with a known missingness pattern, small enough to check by hand.
#
#   row  age  bmi  sex   outcome
#   1     50   NA  "M"   1
#   2     60   25  "F"   0
#   3     NA   27  "M"   1
#   4     70   29  "F"   NA
#
# age mean over non-missing = (50 + 60 + 70) / 3 = 60
# bmi mean over non-missing = (25 + 27 + 29) / 3 = 27
fixture_frame <- function() {
  data.frame(
    age = c(50, 60, NA, 70),
    bmi = c(NA, 25, 27, 29),
    sex = c("M", "F", "M", "F"),
    outcome = c(1, 0, 1, NA),
    stringsAsFactors = FALSE
  )
}
