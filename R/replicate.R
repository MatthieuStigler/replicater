################################
### Global folders
################################

#' Set the folders and name of the replication report and of the output archive
#'
#' Called once at the top of the master script. The verbs of the replication
#' pipe (see [rpl_list_scripts()]) and [rpl_read_report()] then read and write
#' there:
#' * the **replication report** `<report_dir>/<report_file>`, by default
#'   `<report_dir>/replicater_report.csv`, one row per script and run,
#'   appended run after run;
#' * the **archive of the script outputs**
#'   `<session_dir>/session_YYYY_MM_DD/<script>.Rout`.
#'
#' The values are stored in the options `replicater.report_dir`,
#' `replicater.session_dir` and `replicater.report_file`. Nothing is written
#' on disk by `rpl_set_dirs()` itself. There is no default folder: the verbs
#' that read or write the report stop when `rpl_set_dirs()` was not called.
#' @param report_dir Folder of the replication report.
#' @param session_dir Folder of the archive of the script outputs: one subfolder
#'   per run (`session_YYYY_MM_DD`) holding the `.Rout` file of each script.
#'   Default: `<report_dir>/sessions`. `NULL` switches the archive off (the
#'   `.Rout` files then go to a temporary folder).
#' @param report_file Name of the replication report. Default `NULL`:
#'   `replicater_report.csv`, or `999_CHECK_RUN_report.csv` when only that
#'   older file exists in `report_dir`.
#' @return `rpl_set_dirs()`: the previous options, invisibly, to restore them
#'   with `options()`. `rpl_get_dirs()`: a list with `report_dir`,
#'   `session_dir` and `report_file`, all `NULL` when `rpl_set_dirs()` was not
#'   called.
#' @examples
#' old <- rpl_set_dirs(report_dir = "code_meta")
#' rpl_get_dirs()
#'
#' ## no archive of the .Rout files
#' rpl_set_dirs(report_dir = "code_meta", session_dir = NULL)
#'
#' ## another name for the report
#' rpl_set_dirs(report_dir = "code_meta", report_file = "my_report.csv")
#' rpl_get_dirs()
#' options(old)
#' @export
rpl_set_dirs <- function(report_dir, session_dir = file.path(report_dir, "sessions"),
                         report_file = NULL) {
  ## FALSE stands for "no archive", as an option set to NULL would be removed
  old <- options(replicater.report_dir = report_dir,
                 replicater.session_dir = if(is.null(session_dir)) FALSE else session_dir,
                 replicater.report_file = report_file)
  invisible(old)
}

#' @rdname rpl_set_dirs
#' @export
rpl_get_dirs <- function() {
  report_dir <- getOption("replicater.report_dir")
  session_dir <- getOption("replicater.session_dir", FALSE)
  list(report_dir = report_dir,
       session_dir = if(isFALSE(session_dir)) NULL else session_dir,
       report_file = getOption("replicater.report_file"))
}

## path of the replication report, from the global settings
intrnl_report_path <- function() {
  dirs <- rpl_get_dirs()
  intrnl_dir_to_file(dirs$report_dir, dirs$report_file)
}

#' Read the replication report
#'
#' Reads the replication report written by [rpl_write_report()], at the place
#' set with [rpl_set_dirs()].
#' @param last_run Keep only the rows of the last run?
#' @return A table with one row per script and run.
#' @examples
#' old <- rpl_set_dirs(report_dir = file.path(tempdir(), "code_meta"))
#' path_scripts <- system.file("r_scripts_fake", package = "replicater")
#' rpl_list_scripts(path_scripts) %>%
#'   rpl_run_scripts(echo = FALSE) %>%
#'   rpl_write_report()
#'
#' rpl_read_report()
#' rpl_read_report(last_run = TRUE)
#' options(old)
#' @export
rpl_read_report <- function(last_run = FALSE) {
  file_report <- intrnl_report_path()
  if(!file.exists(file_report)) stop("No replication report at ", file_report)
  report <- intrnl_read_report(file_report)
  if(last_run) report <- filter(report, .data$time == max(.data$time))
  report
}

################################
### Pipe verbs
################################

#' Replication pipe: list, check, run and report the scripts of a project
#'
#' Verbs meant to be piped in a master script, each doing one step:
#' 1. `rpl_list_scripts()` lists the R scripts with all their YAML fields, in
#'    the order they will run.
#' 2. `rpl_add_last_run()` adds the result of the last run (`has_error_last`,
#'    `elapsed_last`), read from the replication report.
#' 3. `rpl_check_packages()` lists the packages used by the scripts that are
#'    not installed, and optionally installs them.
#' 4. `rpl_run_scripts()` runs each script and keeps its `.Rout` file in the
#'    archive `<session_dir>/session_YYYY_MM_DD/`.
#' 5. `rpl_write_report()` appends the run to the replication report
#'    `<report_dir>/replicater_report.csv`.
#' 6. `rpl_print_summary()` prints the errors, the scripts that broke or got
#'    fixed since the last run, and the slowest scripts.
#'
#' The two folders are set beforehand with [rpl_set_dirs()]. Scripts run in the
#' order of `dir_path`, then by folder and file name, each in a new R session
#' started from the working directory (`run_function = "external"`). Scripts
#' with `run_replicate: FALSE` in their YAML header are listed but not checked
#' nor run.
#' @param dir_path Folders with the scripts, in the order they should run.
#' @param exclude Regular expressions: scripts whose path matches one of them
#'   are dropped, e.g. `c("888", "OLD")`.
#' @param recursive Look into subfolders?
#' @param ... `rpl_list_scripts()`: passed to [rpl_list_Rfiles()], e.g.
#'   `keep_field`. `rpl_check_packages()`: passed to [rpl_install_missing()],
#'   e.g. `type = "binary"`.
#' @param scripts Table of scripts, from `rpl_list_scripts()`.
#' @param install How to install missing packages: `"none"` (only list them),
#'   or a `method` of [rpl_install_missing()].
#' @param lib Folder where to install the packages, see [rpl_install_missing()].
#' @param run_function `"external"` (a new R session per script, with a `.Rout`
#'   file) or `"internal"` (in the current session, no `.Rout` file).
#' @param runs Table of the run, from `rpl_run_scripts()`.
#' @param cols_extra Extra columns to keep in the report, when they exist.
#' @inheritParams rpl_run_Rfiles
#' @return `rpl_list_scripts()`, `rpl_add_last_run()` and `rpl_run_scripts()`:
#'   a table with one row per script. `rpl_check_packages()`,
#'   `rpl_write_report()` and `rpl_print_summary()`: their input, invisibly.
#' @examples
#' library(replicater)
#' old <- rpl_set_dirs(report_dir = file.path(tempdir(), "code_meta"))
#' path_scripts <- system.file("r_scripts_fake", package = "replicater")
#'
#' rpl_list_scripts(path_scripts) %>%
#'   rpl_add_last_run() %>%
#'   rpl_check_packages() %>%
#'   rpl_run_scripts(echo = FALSE) %>%
#'   rpl_write_report() %>%
#'   rpl_print_summary()
#' options(old)
#' @export
rpl_list_scripts <- function(dir_path, exclude = NULL, recursive = TRUE, ...) {
  dir_path <- str_replace(dir_path, "/+$", "")
  scripts <- rpl_list_Rfiles(dir_path, recursive = recursive, ...)

  if(!is.null(exclude)) {
    scripts <- scripts %>%
      filter(!str_detect(.data$full_path, paste(exclude, collapse = "|")))
  }

  ## position of the folder in dir_path
  dir_rank <- purrr::map_int(scripts$full_path, ~which(startsWith(., paste0(dir_path, "/")))[1])

  scripts %>%
    mutate(dir_rank = dir_rank) %>%
    dplyr::arrange(.data$dir_rank, .data$folder, .data$filename) %>%
    select(-"dir_rank")
}

#' @rdname rpl_list_scripts
#' @export
rpl_add_last_run <- function(scripts) {
  force(scripts) ## run the previous verbs of the pipe first (lazy %>%)
  dirs <- rpl_get_dirs()
  file_report <- intrnl_report_path()
  if(!file.exists(file_report)) {
    message("No replication report yet at ", file_report, ": no last run to add")
    return(mutate(scripts, elapsed_last = NA_real_, has_error_last = NA))
  }
  rpl_add_info_last(scripts, dir_path = dirs$report_dir, warn = FALSE,
                    report_file = dirs$report_file)
}

#' @rdname rpl_list_scripts
#' @export
rpl_check_packages <- function(scripts, install = c("none", "install.packages", "pak", "apt"),
                               lib = NULL, ...) {
  force(scripts) ## run the previous verbs of the pipe first (lazy %>%)
  install <- match.arg(install)
  paths <- scripts$full_path[intrnl_to_run(scripts)]
  pkg_miss <- rpl_check_deps(paths, quiet = TRUE, errors = "ignored")
  if(install != "none") rpl_install_missing(pkg_miss, method = install, lib = lib, ...)
  invisible(scripts)
}

#' @rdname rpl_list_scripts
#' @export
rpl_run_scripts <- function(scripts, run_function = c("external", "internal"),
                            skip_false = TRUE, echo = TRUE) {
  force(scripts) ## run the previous verbs of the pipe first (lazy %>%)
  run_function <- match.arg(run_function)
  if(nrow(scripts) == 0) stop("No R scripts to run")
  intrnl_report_path() ## stops before the run when rpl_set_dirs() was not called

  ## archive folder of the run, for the .Rout files
  session_dir <- rpl_get_dirs()$session_dir
  dir_session <- NULL
  if(run_function == "external" && !is.null(session_dir)) {
    dir_session <- file.path(session_dir, paste0("session_", format(Sys.Date(), "%Y_%m_%d")))
    dir.create(dir_session, recursive = TRUE, showWarnings = FALSE)
  }

  runs <- rpl_run_Rfiles(scripts, echo = echo, skip_false = skip_false,
                         run_function = run_function, tmp_dir = dir_session)
  if(!is.null(dir_session)) message(".Rout files archived in ", dir_session)
  runs
}

#' @rdname rpl_list_scripts
#' @export
rpl_write_report <- function(runs, cols_extra = "Author") {
  force(runs) ## run the previous verbs of the pipe first (lazy %>%)
  dirs <- rpl_get_dirs()
  file_report <- intrnl_report_path() ## stops when rpl_set_dirs() was not called
  if(!dir.exists(dirs$report_dir)) {
    dir.create(dirs$report_dir, recursive = TRUE)
    message("Created folder ", dirs$report_dir)
  }
  rpl_write(runs, dir_path = dirs$report_dir, cols_extra = intersect(cols_extra, colnames(runs)),
            report_file = dirs$report_file)
  message("Replication report: ", nrow(runs), " rows added to ", file_report)
  invisible(runs)
}

#' @rdname rpl_list_scripts
#' @export
rpl_print_summary <- function(runs) {
  force(runs) ## run the previous verbs of the pipe first (lazy %>%)
  cat("\n## replicater:", nrow(runs), "scripts run,", sum(runs$has_error), "with errors.",
      "Time of the scripts without error:", intrnl_time_format(sum(runs$elapsed, na.rm = TRUE)), "\n")

  ## compare with the last run
  if("has_error_last" %in% colnames(runs)) {
    errors_new <- runs$filename[runs$has_error & runs$has_error_last %in% FALSE]
    errors_fixed <- runs$filename[!runs$has_error & runs$has_error_last %in% TRUE]
    if(length(errors_new) > 0) cat("New errors (no error last run):", paste(errors_new, collapse = ", "), "\n")
    if(length(errors_fixed) > 0) cat("Fixed since last run:", paste(errors_fixed, collapse = ", "), "\n")
  }
  if(any(runs$has_error)) {
    cat("\nErrors:\n")
    rpl_showErr(runs)
  }

  cat("\nSlowest scripts:\n")
  runs %>%
    dplyr::slice_max(.data$elapsed, n = 5, with_ties = FALSE) %>%
    dplyr::transmute(filename = .data$filename,
                     seconds = round(.data$elapsed, 1),
                     time = intrnl_time_format_vec(.data$elapsed)) %>%
    print()
  invisible(runs)
}

## scripts to run: all except run_replicate: FALSE
intrnl_to_run <- function(scripts) {
  if(!"run_replicate" %in% colnames(scripts)) return(rep(TRUE, nrow(scripts)))
  !(scripts$run_replicate %in% FALSE)
}
