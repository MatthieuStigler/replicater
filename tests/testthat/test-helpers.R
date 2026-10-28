test_that("multiplication works", {
  tmpf <- paste0(tempfile(), ".R")
  cat("library(hihi)", file=tmpf)
  # out <- rpl_check_deps(dirname(tmpf))
  expect_message(rpl_check_deps(dirname(tmpf)), "The following packages are missing: hihi")

})

test_that("rpl_check_deps can hide the renv output on scripts with parse errors", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", code = c("library(stats)", "@"))
  expect_output(suppressMessages(rpl_check_deps(dir)), "problems")
  expect_output(suppressMessages(rpl_check_deps(dir, quiet = TRUE, errors = "ignored")), NA)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_install_missing with apt only prints the command", {
  expect_message(cmd <- rpl_install_missing(c("sf", "RSQLite", NA, "sf"), method = "apt"),
                 "sudo apt install r-cran-sf r-cran-rsqlite")
  expect_equal(cmd, "sudo apt install r-cran-sf r-cran-rsqlite")
  expect_warning(suppressMessages(rpl_install_missing("sf", method = "apt", lib = tempdir())),
                 "not used")
})

test_that("rpl_install_missing does nothing when no package is missing", {
  ## rpl_check_deps() returns NA when all packages are installed
  expect_message(out <- rpl_install_missing(NA_character_), "No packages to install")
  expect_equal(out, character())
  expect_error(rpl_install_missing("sf", method = "conda"))
})
