## Adapted from matPkg (tests/testthat/test-999_source.R)
path_rscripts <- system.file("r_scripts_fake", package = "replicater")
files_err <- c("1_3_2_lightest_error_rLoEr.R", "1_3_light_error_rLoE.R", "1_8_parse_error.R")
files_ok <- c("1_1_light_one_rLo.R", "1_4_sleep_3_rLoS.R")

dir_dat <- rpl_list_Rfiles(path_rscripts)

test_that("rpl_list_Rfiles reads all scripts and their YAML", {
  expect_equal(nrow(dir_dat), 10)
  expect_true(all(c("filename", "number", "has_yaml_header", "run_replicate", "full_path",
                    "Author", "custom_field2") %in% colnames(dir_dat)))
  expect_equal(dir_dat$has_yaml_header, dir_dat$filename != "1_9_no_yaml.R")
  expect_equal(dir_dat$number[dir_dat$filename == "1_3_2_lightest_error_rLoEr.R"], 1.32)
  expect_equal(sum(dir_dat$run_replicate, na.rm = TRUE), 7)
  expect_equal(dir_dat$filename[dir_dat$run_replicate %in% FALSE], "1_5_SUPER_heavy_norun.R")
})

test_that("rpl_run_Rfiles internal detects errors", {
  out_int <- rpl_run_Rfiles(dir_dat)
  expect_equal(nrow(out_int), 9)
  expect_false("1_5_SUPER_heavy_norun.R" %in% out_int$filename)
  expect_true(all(out_int$has_error[out_int$filename %in% files_err]))
  expect_false(any(out_int$has_error[out_int$filename %in% files_ok]))
  expect_false(anyNA(out_int$elapsed[!out_int$has_error]))
})

test_that("rpl_run_Rfiles external detects errors and writes .Rout files", {
  dir_temp <- tempfile()
  dir.create(dir_temp)
  out_ext <- rpl_run_Rfiles(dir_dat, run_function = "external", tmp_dir = dir_temp)
  expect_true(all(out_ext$has_error[out_ext$filename %in% files_err]))
  expect_false(any(out_ext$has_error[out_ext$filename %in% files_ok]))
  expect_setequal(list.files(dir_temp), paste0(out_ext$filename, "out"))
  unlink(dir_temp, recursive = TRUE)

  ## vanilla
  out_van <- rpl_run_Rfiles(dir_dat |> dplyr::filter(filename %in% files_ok),
                            run_function = "external", run_cmd_vanilla = TRUE)
  expect_false(any(out_van$has_error))
})

test_that("rpl_write appends to the report", {
  dir_temp <- tempfile()
  dir.create(dir_temp)
  out_ext <- rpl_run_Rfiles(dir_dat |> dplyr::filter(filename %in% c(files_ok, files_err)),
                            run_function = "external")
  rpl_write(out_ext, dir_path = dir_temp, cols_extra = "Author")
  rpl_write(out_ext, dir_path = dir_temp, cols_extra = "Author")
  report <- readr::read_csv(file.path(dir_temp, "replicater_report.csv"), show_col_types = FALSE)
  expect_equal(nrow(report), 2 * nrow(out_ext))
  expect_equal(colnames(report), c(intrnl_cols_need, "Author"))
  expect_output(rpl_showErr(out_ext), "1_8_parse_error.R")

  ## add info from last run
  dat_last <- rpl_add_info_last(dir_dat, dir_path = dir_temp)
  expect_equal(nrow(dat_last), nrow(dir_dat))
  expect_equal(dat_last$has_error_last[match(c(files_ok, files_err), dat_last$filename)],
               rep(c(FALSE, TRUE), c(length(files_ok), length(files_err))))
  expect_warning(rpl_add_info_last(dir_dat, dir_path = tempfile()), "File not already there")
  unlink(dir_temp, recursive = TRUE)
})

test_that("rpl_run_Rfiles argument checks", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", yaml = "run_replicate: FALSE")
  dat <- rpl_list_Rfiles(dir)
  expect_error(rpl_run_Rfiles(dat), "All R scripts have 'run_replicate: FALSE'")
  expect_warning(rpl_run_Rfiles(dat, skip_false = FALSE, tmp_dir = dir),
                 "not relevant")
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_Rfiles internal does not leak objects into the global env", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", code = "rpl_obj_test_leak <- 1")
  out <- rpl_run_Rfiles(rpl_list_Rfiles(dir))
  expect_false(out$has_error)
  expect_false(exists("rpl_obj_test_leak", envir = globalenv()))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_Rfiles internal and external agree on errors", {
  dir <- new_dir()
  write_script(dir, "1_1_ok.R")
  write_script(dir, "1_2_stop.R", code = "stop('custom stop')")
  write_script(dir, "1_3_missing_pkg.R", code = "library(notAPackageXYZ)")
  dat <- rpl_list_Rfiles(dir)
  out_int <- rpl_run_Rfiles(dat)
  out_ext <- rpl_run_Rfiles(dat, run_function = "external")
  expect_equal(out_int$has_error, c(FALSE, TRUE, TRUE))
  expect_equal(out_ext$has_error, c(FALSE, TRUE, TRUE))
  expect_match(out_int$error[2], "custom stop")
  expect_match(out_ext$error[2], "custom stop")
  expect_match(out_ext$error[3], "notAPackageXYZ")
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_Rfiles external reports each way a script can end", {
  dir <- new_dir()
  write_script(dir, "1_1_ok.R")
  write_script(dir, "1_2_stop.R", code = "stop('boom')")
  write_script(dir, "1_3_quit_status_1.R", code = "quit(save = 'no', status = 1)")
  write_script(dir, "1_4_quit_status_0.R", code = "quit(save = 'no', status = 0)")
  out <- rpl_run_Rfiles(rpl_list_Rfiles(dir), run_function = "external")

  expect_equal(out$has_error, c(FALSE, TRUE, TRUE, FALSE))
  expect_match(out$error[2], "boom")
  expect_equal(out$error[3], "Script stopped with exit status 1")
  expect_equal(is.na(out$elapsed), c(FALSE, TRUE, TRUE, FALSE))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_run_Rfiles external reports killed scripts", {
  skip_on_os("windows")
  dir <- new_dir()
  write_script(dir, "1_1_killed.R", code = "tools::pskill(Sys.getpid(), tools::SIGKILL)")
  expect_warning(out <- rpl_run_Rfiles(rpl_list_Rfiles(dir), run_function = "external"),
                 "Script killed")
  expect_true(out$has_error)
  expect_equal(out$error, "KILLED")
  unlink(dir, recursive = TRUE)
})

test_that("rpl_write overwrites with append = FALSE", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R")
  out <- rpl_run_Rfiles(rpl_list_Rfiles(dir))
  rpl_write(out, dir_path = dir)
  rpl_write(out, dir_path = dir, append = FALSE)
  report <- readr::read_csv(file.path(dir, "replicater_report.csv"), show_col_types = FALSE)
  expect_equal(nrow(report), 1)

  ## append = TRUE on a missing file still writes the header
  rpl_write(out, dir_path = dir, append = TRUE, report_file = "other_report.csv")
  report_other <- readr::read_csv(file.path(dir, "other_report.csv"), show_col_types = FALSE)
  expect_equal(nrow(report_other), 1)
  expect_equal(colnames(report_other), intrnl_cols_need)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_write continues an old 999 report and aligns its columns", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R", code = "stop('old run fails')")
  out <- rpl_run_Rfiles(rpl_list_Rfiles(dir))

  ## old report: has_yaml, empty runMat columns, no run_replicate
  rpl_write(out, dir_path = dir)
  report_old <- readr::read_csv(file.path(dir, "replicater_report.csv"), col_types = readr::cols(.default = "c")) |>
    dplyr::rename(has_yaml = "has_yaml_header") |>
    dplyr::mutate(has_runMat = NA, runMat_val = NA) |>
    dplyr::select(-"run_replicate")
  readr::write_csv(report_old, file.path(dir, "999_CHECK_RUN_report.csv"))
  file.remove(file.path(dir, "replicater_report.csv"))

  Sys.sleep(0.01)
  write_script(dir, "1_1_a.R")
  expect_message(rpl_write(rpl_run_Rfiles(rpl_list_Rfiles(dir)), dir_path = dir),
                 "rewriting it")
  expect_false(file.exists(file.path(dir, "replicater_report.csv")))
  report <- readr::read_csv(file.path(dir, "999_CHECK_RUN_report.csv"), show_col_types = FALSE)
  expect_equal(colnames(report), intrnl_cols_need)
  expect_equal(report$has_error, c(TRUE, FALSE))
  expect_equal(report$has_yaml_header, c(TRUE, TRUE))

  ## next run appends to the aligned report, and the last run is read back
  rpl_write(out, dir_path = dir)
  expect_equal(nrow(readr::read_csv(file.path(dir, "999_CHECK_RUN_report.csv"), show_col_types = FALSE)), 3)
  expect_equal(rpl_add_info_last(out, dir_path = dir)$has_error_last, TRUE)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_add_info_last uses only the last run", {
  dir <- new_dir()
  dir_scripts <- file.path(dir, "code")
  write_script(dir_scripts, "1_1_a.R", code = "stop('first run fails')")
  write_script(dir_scripts, "1_2_b.R")
  dat <- rpl_list_Rfiles(dir_scripts)

  ## run 1: 1_1_a.R fails
  rpl_write(rpl_run_Rfiles(dat), dir_path = dir)
  Sys.sleep(0.01)

  ## run 2: 1_1_a.R fixed
  write_script(dir_scripts, "1_1_a.R")
  rpl_write(rpl_run_Rfiles(dat), dir_path = dir)

  out <- rpl_add_info_last(dat, dir_path = dir)
  expect_equal(nrow(out), 2)
  expect_equal(out$has_error_last, c(FALSE, FALSE))
  expect_true(all(c("elapsed_last", "has_error_last") %in% colnames(out)))
  unlink(dir, recursive = TRUE)
})

test_that("rpl_add_info_last matches scripts with the same name in different folders", {
  dir <- new_dir()
  write_script(file.path(dir, "code_setup"), "1_1_clean.R", code = "stop('setup fails')")
  write_script(file.path(dir, "code_analysis"), "1_1_clean.R")
  dat <- rpl_list_Rfiles(dir, recursive = TRUE, check_numbers = FALSE)
  rpl_write(rpl_run_Rfiles(dat), dir_path = dir)

  out <- rpl_add_info_last(dat, dir_path = dir)
  expect_equal(nrow(out), 2)
  expect_equal(out$has_error_last[out$subfolder == "code_setup"], TRUE)
  expect_equal(out$has_error_last[out$subfolder == "code_analysis"], FALSE)
  unlink(dir, recursive = TRUE)
})

test_that("rpl_add_info_last works on rpl_run_Rfiles() output", {
  dir <- new_dir()
  write_script(dir, "1_1_a.R")
  out_run <- rpl_run_Rfiles(rpl_list_Rfiles(dir))
  rpl_write(out_run, dir_path = dir)

  out <- rpl_add_info_last(out_run, dir_path = dir)
  expect_equal(nrow(out), 1)
  expect_true(all(c("elapsed", "has_error", "elapsed_last", "has_error_last") %in% colnames(out)))
  expect_false(out$has_error_last)

  ## folder as factor, as in the 991 script after fct_relevel()
  out_fct <- rpl_add_info_last(dplyr::mutate(out_run, folder = factor(folder)), dir_path = dir)
  expect_false(out_fct$has_error_last)
  expect_true(is.factor(out_fct$folder))
  unlink(dir, recursive = TRUE)
})
