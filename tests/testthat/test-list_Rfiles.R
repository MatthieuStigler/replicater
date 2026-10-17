test_that("rpl_list_Rfiles reports YAML header parse errors", {
  dir <- new_dir()
  write_script(dir, "1_1_good.R")
  write_script(dir, "1_2_bad_yaml.R", yaml = "Title: [unclosed")
  out <- rpl_list_Rfiles(dir)

  good <- out[out$filename == "1_1_good.R", ]
  bad <- out[out$filename == "1_2_bad_yaml.R", ]
  expect_false(good$has_error_parse)
  expect_true(is.na(good$error_parse))
  expect_true(bad$has_error_parse)
  expect_match(bad$error_parse, "Parser error")
  expect_false(bad$has_yaml)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles without any parse error", {
  dir <- new_dir()
  write_script(dir, "1_1_good.R")
  write_script(dir, "1_2_no_yaml.R", yaml = NULL)
  out <- rpl_list_Rfiles(dir)
  expect_equal(out$has_error_parse, c(FALSE, FALSE))
  expect_equal(out$error_parse, c(NA_character_, NA_character_))
  expect_equal(out$has_yaml, c(TRUE, FALSE))
  expect_equal(out$has_runMat, c(TRUE, FALSE))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles warns on ambiguous numbers", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R")
  write_script(dir, "1_1_b.R")
  expect_warning(rpl_list_Rfiles(dir), "Ambiguous numbers")
  expect_no_warning(rpl_list_Rfiles(dir, check_numbers = FALSE))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles parses numbers from file names", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R")
  write_script(dir, "2_10_b.R")
  write_script(dir, "3_2_1_c.R")
  write_script(dir, "no_number.R")
  out <- rpl_list_Rfiles(dir)
  expect_equal(out$number_char, c("1_1", "2_10", "3_2_1", NA))
  expect_equal(out$number, c(1.1, 2.10, 3.21, NA))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles handles recursive and old folders", {
  dir <- new_dir()
  write_script(dir, "1_1_top.R")
  write_script(file.path(dir, "sub"), "2_1_sub.R")
  write_script(file.path(dir, "OLD"), "3_1_old.R")

  expect_equal(rpl_list_Rfiles(dir)$filename, "1_1_top.R")
  expect_setequal(rpl_list_Rfiles(dir, recursive = TRUE)$filename,
                  c("1_1_top.R", "2_1_sub.R"))
  expect_setequal(rpl_list_Rfiles(dir, recursive = TRUE, no_old = FALSE)$filename,
                  c("1_1_top.R", "2_1_sub.R", "3_1_old.R"))
  out <- rpl_list_Rfiles(dir, recursive = TRUE)
  expect_equal(out$subfolder[out$filename == "2_1_sub.R"], "sub")
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles keeps extra YAML fields", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", yaml = c("runMat: TRUE", "Author: \"Me\"", "run_replicate: FALSE"))
  write_script(dir, "1_2_b.R", yaml = "runMat: TRUE")
  out <- rpl_list_Rfiles(dir, keep_field = c("Author", "run_replicate"))
  expect_equal(out$Author, c("Me", NA))
  expect_equal(out$run_replicate, c(FALSE, NA))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_Rfiles errors on missing folder", {
  expect_error(rpl_list_Rfiles(file.path(tempdir(), "does_not_exist")), "Missing folder")
})
