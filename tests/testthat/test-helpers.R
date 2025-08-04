test_that("multiplication works", {
  tmpf <- paste0(tempfile(), ".R")
  cat("library(hihi)", file=tmpf)
  # out <- rpl_check_deps(dirname(tmpf))
  expect_message(rpl_check_deps(dirname(tmpf)), "The following packages are missing: hihi")

})
