test_that("rpl_set_dirs sets the global folders", {
  old <- rpl_set_dirs(report_dir = "my_meta")
  expect_equal(rpl_get_dirs(), list(report_dir = "my_meta",
                                    session_dir = file.path("my_meta", "sessions")))
  rpl_set_dirs(report_dir = "a", session_dir = "b")
  expect_equal(rpl_get_dirs()$session_dir, "b")
  options(old)
  expect_equal(rpl_get_dirs()$report_dir, "code_setup")
})

test_that("rpl_list_scripts orders by dir_path, then folder and file name, and excludes", {
  dir <- new_dir()
  old <- rpl_set_dirs(report_dir = dir)
  write_script(file.path(dir, "code_setup"), "1_1_a.R")
  write_script(file.path(dir, "code_setup", "data"), "1_2_b.R")
  write_script(file.path(dir, "code_setup"), "888_aux.R")
  write_script(file.path(dir, "code_analysis"), "1_0_c.R")
  dirs <- file.path(dir, c("code_setup", "code_analysis"))

  out <- rpl_list_scripts(dirs, exclude = "888")
  expect_equal(out$filename, c("1_1_a.R", "1_2_b.R", "1_0_c.R"))
  expect_equal(rpl_list_scripts(rev(dirs), exclude = c("888", "data"))$filename,
               c("1_0_c.R", "1_1_a.R"))
  expect_false("has_error_last" %in% colnames(out))
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_replicate runs, writes the report and .Rout files, and compares with the last run", {
  dir <- new_dir()
  dir_code <- file.path(dir, "code")
  old <- rpl_set_dirs(report_dir = file.path(dir, "code_meta"))
  dir.create(file.path(dir, "code_meta"))
  write_script(dir_code, "1_1_ok.R")
  write_script(dir_code, "1_2_fixed.R", code = "stop('first run fails')")
  write_script(dir_code, "1_3_skip.R", yaml = "run_replicate: FALSE")
  write_script(dir_code, "1_4_broken.R")

  ## run 1
  txt1 <- capture.output(out1 <- suppressMessages(rpl_replicate(rpl_list_scripts(dir_code), echo = FALSE)))
  expect_equal(out1$filename, c("1_1_ok.R", "1_2_fixed.R", "1_4_broken.R"))
  expect_match(txt1, "3 scripts run in .* with 1 errors", all = FALSE)
  dir_session <- file.path(dir, "code_meta", "sessions", paste0("session_", format(Sys.Date(), "%Y_%m_%d")))
  expect_setequal(list.files(dir_session), paste0(out1$filename, "out"))

  ## run 2: one script fixed, one broken
  write_script(dir_code, "1_2_fixed.R")
  write_script(dir_code, "1_4_broken.R", code = "stop('now fails')")
  Sys.sleep(0.01)
  scripts2 <- rpl_list_scripts(dir_code)
  expect_equal(scripts2$has_error_last, c(FALSE, TRUE, NA, FALSE))
  txt2 <- capture.output(suppressMessages(rpl_replicate(scripts2, echo = FALSE)))
  expect_match(txt2, "New errors \\(no error last run\\): 1_4_broken.R", all = FALSE)
  expect_match(txt2, "Fixed since last run: 1_2_fixed.R", all = FALSE)

  report <- readr::read_csv(file.path(dir, "code_meta", "replication_report.csv"), show_col_types = FALSE)
  expect_equal(nrow(report), 6)
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_replicate internal run creates no session folder", {
  dir <- new_dir()
  old <- rpl_set_dirs(report_dir = dir)
  write_script(file.path(dir, "code"), "1_1_ok.R")
  capture.output(out <- suppressMessages(rpl_replicate(rpl_list_scripts(file.path(dir, "code")),
                                                       run_function = "internal", echo = FALSE)))
  expect_false(out$has_error)
  expect_false(dir.exists(file.path(dir, "sessions")))
  expect_error(rpl_replicate(dplyr::filter(out, FALSE)), "No R scripts to run")
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_add_info_last matches ./code with code", {
  dir <- new_dir()
  write_script(file.path(dir, "code"), "1_1_a.R", code = "stop('fails')")
  wd <- setwd(dir)
  rpl_write(rpl_run_Rfiles(rpl_list_Rfiles("./code")), dir_path = ".")
  out <- rpl_add_info_last(rpl_list_Rfiles("code"), dir_path = ".")
  setwd(wd)
  expect_equal(out$folder, "code")
  expect_true(out$has_error_last)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_Rfiles external follows echo", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R")
  dat <- rpl_list_Rfiles(dir)
  expect_silent(rpl_run_Rfiles(dat, run_function = "external"))
  expect_output(rpl_run_Rfiles(dat, run_function = "external", echo = TRUE), "Doing file")
  unlink(dir, recursive = TRUE)
})
