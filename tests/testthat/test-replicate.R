## the whole pipe, output captured
run_pipe <- function(scripts, ...) {
  out <- NULL
  txt <- capture.output(out <- suppressMessages(scripts %>%
                                                  rpl_add_last_run() %>%
                                                  rpl_check_packages() %>%
                                                  rpl_run_scripts(echo = FALSE, ...) %>%
                                                  rpl_write_report() %>%
                                                  rpl_print_summary()))
  list(out = out, txt = txt)
}

test_that("rpl_set_dirs sets the global folders, and switches the archive off with NULL", {
  old <- rpl_set_dirs(report_dir = "my_meta")
  expect_equal(rpl_get_dirs(), list(report_dir = "my_meta",
                                    session_dir = file.path("my_meta", "sessions"),
                                    report_file = NULL))
  rpl_set_dirs(report_dir = "a", session_dir = "b")
  expect_equal(rpl_get_dirs()$session_dir, "b")
  rpl_set_dirs(report_dir = "a", session_dir = NULL)
  expect_null(rpl_get_dirs()$session_dir)
  expect_equal(rpl_get_dirs()$report_dir, "a")
  options(old)
  expect_null(rpl_get_dirs()$report_dir)
})

test_that("the verbs stop when rpl_set_dirs() was not called", {
  dir <- new_dir()
  write_script(dir, "1_1_ok.R")
  scripts <- rpl_list_scripts(dir)
  expect_error(rpl_add_last_run(scripts), "rpl_set_dirs")
  expect_error(rpl_run_scripts(scripts, echo = FALSE), "rpl_set_dirs")
  expect_error(rpl_read_report(), "rpl_set_dirs")
  unlink(dir, recursive = TRUE)
})

test_that("rpl_list_scripts orders by dir_path, then folder and file name, and excludes", {
  dir <- new_dir()
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
  unlink(dir, recursive = TRUE)
})

test_that("rpl_add_last_run adds empty columns when there is no report yet", {
  dir <- new_dir()
  old <- rpl_set_dirs(report_dir = file.path(dir, "code_meta"))
  write_script(file.path(dir, "code"), "1_1_ok.R")
  expect_message(out <- rpl_add_last_run(rpl_list_scripts(file.path(dir, "code"))),
                 "No replication report yet")
  expect_equal(out$has_error_last, NA)
  expect_equal(out$elapsed_last, NA_real_)
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("the pipe runs, writes the report and the archive, and compares with the last run", {
  dir <- new_dir()
  dir_code <- file.path(dir, "code")
  old <- rpl_set_dirs(report_dir = file.path(dir, "code_meta"))
  write_script(dir_code, "1_1_ok.R")
  write_script(dir_code, "1_2_fixed.R", code = "stop('first run fails')")
  write_script(dir_code, "1_3_skip.R", yaml = "run_replicate: FALSE")
  write_script(dir_code, "1_4_broken.R")

  ## run 1: the report folder is created
  res1 <- run_pipe(rpl_list_scripts(dir_code))
  expect_equal(res1$out$filename, c("1_1_ok.R", "1_2_fixed.R", "1_4_broken.R"))
  expect_match(res1$txt, "3 scripts run, 1 with errors", all = FALSE)
  dir_session <- file.path(dir, "code_meta", "sessions", paste0("session_", format(Sys.Date(), "%Y_%m_%d")))
  expect_setequal(list.files(dir_session), paste0(res1$out$filename, "out"))

  ## run 2: one script fixed, one broken
  write_script(dir_code, "1_2_fixed.R")
  write_script(dir_code, "1_4_broken.R", code = "stop('now fails')")
  Sys.sleep(0.01)
  expect_equal(rpl_add_last_run(rpl_list_scripts(dir_code))$has_error_last, c(FALSE, TRUE, NA, FALSE))
  res2 <- run_pipe(rpl_list_scripts(dir_code))
  expect_match(res2$txt, "New errors \\(no error last run\\): 1_4_broken.R", all = FALSE)
  expect_match(res2$txt, "Fixed since last run: 1_2_fixed.R", all = FALSE)

  report <- readr::read_csv(file.path(dir, "code_meta", "replicater_report.csv"), show_col_types = FALSE)
  expect_equal(nrow(report), 6)
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_scripts keeps no .Rout archive when switched off or internal", {
  dir <- new_dir()
  write_script(file.path(dir, "code"), "1_1_ok.R")
  scripts <- rpl_list_scripts(file.path(dir, "code"))

  old <- rpl_set_dirs(report_dir = dir, session_dir = NULL)
  expect_false(rpl_run_scripts(scripts, echo = FALSE)$has_error)
  expect_false(dir.exists(file.path(dir, "sessions")))

  rpl_set_dirs(report_dir = dir)
  expect_false(rpl_run_scripts(scripts, run_function = "internal", echo = FALSE)$has_error)
  expect_false(dir.exists(file.path(dir, "sessions")))
  expect_error(rpl_run_scripts(dplyr::filter(scripts, FALSE)), "No R scripts to run")
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_check_packages lists missing packages of the scripts that will run only", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", code = "library(notAPackageXYZ)")
  write_script(dir, "1_2_b.R", code = "library(notAPackageSKIP)", yaml = "run_replicate: FALSE")
  scripts <- rpl_list_scripts(dir)
  msg <- capture_messages(out <- rpl_check_packages(scripts))
  expect_match(msg, "missing: notAPackageXYZ", all = FALSE)
  expect_false(any(grepl("notAPackageSKIP", msg)))
  expect_identical(out, scripts)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_write_report creates the report folder and keeps Author only when present", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", yaml = c("run_replicate: TRUE", "Author: \"Me\""))
  write_script(dir, "1_2_b.R", yaml = "run_replicate: TRUE")
  old <- rpl_set_dirs(report_dir = file.path(dir, "new_meta"))
  runs <- rpl_run_scripts(rpl_list_scripts(dir), run_function = "internal", echo = FALSE)
  expect_message(rpl_write_report(runs), "Created folder")
  report <- readr::read_csv(file.path(dir, "new_meta", "replicater_report.csv"), show_col_types = FALSE)
  expect_equal(report$Author, c("Me", NA))

  ## without any Author field
  runs_no_author <- dplyr::select(runs, -"Author")
  expect_message(rpl_write_report(runs_no_author, cols_extra = "Author"), "2 rows added")
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("report_file names the report for all verbs, and rpl_read_report reads it", {
  dir <- new_dir()
  dir_code <- file.path(dir, "code")
  write_script(dir_code, "1_1_ok.R")
  write_script(dir_code, "1_2_fails.R", code = "stop('fails')")
  old <- rpl_set_dirs(report_dir = file.path(dir, "code_meta"), report_file = "my_report.csv")
  expect_error(rpl_read_report(), "No replication report at .*my_report.csv")

  run_pipe(rpl_list_scripts(dir_code))
  Sys.sleep(0.01)
  res2 <- run_pipe(rpl_list_scripts(dir_code))
  expect_equal(list.files(file.path(dir, "code_meta"), pattern = "csv$"), "my_report.csv")
  expect_equal(res2$out$has_error_last, c(FALSE, TRUE))

  report <- rpl_read_report()
  expect_equal(nrow(report), 4)
  expect_equal(rpl_read_report(last_run = TRUE)$filename, c("1_1_ok.R", "1_2_fails.R"))
  expect_equal(rpl_read_report(last_run = TRUE)$has_error, c(FALSE, TRUE))
  options(old)
  unlink(dir, recursive = TRUE)
})

test_that("the verbs act in pipe order, despite the lazy %>%", {
  dir <- new_dir()
  write_script(file.path(dir, "code"), "1_1_ok.R")
  old <- rpl_set_dirs(report_dir = file.path(dir, "code_meta"), session_dir = NULL)
  msg <- capture_messages(rpl_list_scripts(file.path(dir, "code")) %>%
                            rpl_add_last_run() %>%
                            rpl_check_packages() %>%
                            rpl_run_scripts(echo = FALSE) %>%
                            rpl_write_report())
  pos <- purrr::map_int(c("No replication report yet", "All packages", "Created folder", "rows added"),
                        ~which(grepl(., msg))[1])
  expect_equal(pos, sort(pos))
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
