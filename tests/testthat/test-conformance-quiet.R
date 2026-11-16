# Conformance with the hvtiR API rubric's quiet-mode spec (2026-11-16). Each
# hvtiR package implements .hvti_inform() itself and carries this test.

test_that(".hvti_inform() messages unless hvti.quiet is TRUE", {
  withr::local_options(hvti.quiet = NULL)
  expect_message(.hvti_inform("hello"), "hello")
  withr::local_options(hvti.quiet = FALSE)
  expect_message(.hvti_inform("hello"), "hello")
  withr::local_options(hvti.quiet = TRUE)
  expect_no_message(.hvti_inform("hello"))
  expect_null(.hvti_inform("hello"))
})

test_that("hvti.quiet never silences a warning", {
  withr::local_options(hvti.quiet = TRUE)
  dat <- data.frame(id = c(1, 2, NA, 4), age = c(50, NA, 60, 70))
  expect_warning(impute_mean(dat, vars = c("id", "age")),
                 class = "hvtiRimputation_id_like")
})
