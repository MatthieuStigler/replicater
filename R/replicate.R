################################
### Global folders
################################

#' Set the folders of the report and of the run sessions
#'
#' Called once at the top of the master script. `rpl_list_scripts()`,
#' `rpl_replicate()`, `rpl_write()` and `rpl_add_info_last()` then read and
#' write there. The values are stored in the options `replicater.report_dir`
#' and `replicater.session_dir`.
#' @param report_dir Folder of the report `replication_report.csv`.
#' @param session_dir Folder with one subfolder per run (`session_YYYY_MM_DD`)
#'   holding the `.Rout` file of each script. Default: `<report_dir>/sessions`.
#' @return `rpl_set_dirs()`: the previous options, invisibly, to restore them
#'   with `options()`. `rpl_get_dirs()`: a list with `report_dir` and
#'   `session_dir` (default `report_dir`: `"code_setup"`).
#' @examples
#' old <- rpl_set_dirs(report_dir = "code_meta")
#' rpl_get_dirs()
#' options(old)
#' @export
rpl_set_dirs <- function(report_dir, session_dir = file.path(report_dir, "sessions")) {
  old <- options(replicater.report_dir = report_dir,
                 replicater.session_dir = session_dir)
  invisible(old)
}

#' @rdname rpl_set_dirs
#' @export
rpl_get_dirs <- function() {
  report_dir <- getOption("replicater.report_dir", "code_setup")
  list(report_dir = report_dir,
       session_dir = getOption("replicater.session_dir", file.path(report_dir, "sessions")))
}

################################
### Verbs
################################

#' Replicate a project: list the scripts, then run them
#'
#' The two verbs of a master script, meant to be piped:
#' `rpl_list_scripts()` lists the scripts with their YAML fields and the result
#' of the last run, in the order they will run. The table can then be filtered
#' further with dplyr. `rpl_replicate()` checks the packages, runs the scripts,
#' appends the run to the report and prints a summary. Folders are set
#' beforehand with `rpl_set_dirs()`.
#'
#' Scripts run in the order of `dir_path`, then by folder and file name. With
#' `run_function = "external"`, each script runs in a new R session started
#' from the working directory, and its `.Rout` file is kept in
#' `<session_dir>/session_YYYY_MM_DD`.
#' @param dir_path Folders with the scripts, in the order they should run.
#' @param exclude Regular expressions: scripts whose path matches one of them
#'   are dropped, e.g. `c("888", "OLD")`.
#' @param recursive Look into subfolders?
#' @param ... `rpl_list_scripts()`: passed to `rpl_list_Rfiles()`, e.g.
#'   `keep_field`. `rpl_replicate()`: passed to `rpl_install_missing()`, e.g.
#'   `type = "binary"`.
#' @param scripts Table of scripts, from `rpl_list_scripts()`.
#' @param install How to install missing packages: `"none"` (only report them),
#'   or a `method` of `rpl_install_missing()`.
#' @param lib Folder where to install the packages, see `rpl_install_missing()`.
#' @param run_function `"external"` (a new R session per script) or `"internal"`.
#' @param cols_extra Extra columns to keep in the report, when they exist.
#' @inheritParams rpl_run_Rfiles
#' @return `rpl_list_scripts()`: a table with one row per script.
#'   `rpl_replicate()`: the table of the run, invisibly.
#' @examples
#' old <- rpl_set_dirs(report_dir = tempdir())
#' path_scripts <- system.file("r_scripts_fake", package = "replicater")
#'
#' scripts <- rpl_list_scripts(path_scripts)
#' out <- rpl_replicate(scripts, echo = FALSE)
#'
#' ## second run: the summary compares with the first one
#' out <- rpl_replicate(rpl_list_scripts(path_scripts), echo = FALSE)
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
    select(-"dir_rank") %>%
    rpl_add_info_last(warn = FALSE)
}

#' @rdname rpl_list_scripts
#' @export
rpl_replicate <- function(scripts, install = c("none", "install.packages", "pak", "apt"),
                          lib = NULL, run_function = c("external", "internal"),
                          skip_false = TRUE, echo = TRUE, cols_extra = "Author", ...) {
  install <- match.arg(install)
  run_function <- match.arg(run_function)
  dirs <- rpl_get_dirs()
  time_start <- Sys.time()

  ## scripts to run
  if(skip_false) {
    scripts <- scripts %>%
      filter(!(.data$run_replicate %in% FALSE))
  }
  if(nrow(scripts) == 0) stop("No R scripts to run")

  ## packages of these scripts
  pkg_miss <- rpl_check_deps(scripts$full_path, quiet = TRUE, errors = "ignored")
  if(install != "none") rpl_install_missing(pkg_miss, method = install, lib = lib, ...)

  ## run, keeping the .Rout files in the session folder
  dir_session <- file.path(dirs$session_dir, paste0("session_", format(Sys.Date(), "%Y_%m_%d")))
  if(run_function == "external") dir.create(dir_session, recursive = TRUE, showWarnings = FALSE)
  out <- rpl_run_Rfiles(scripts, echo = echo, skip_false = FALSE,
                        run_function = run_function,
                        tmp_dir = if(run_function == "external") dir_session else NULL)

  ## report
  rpl_write(out, dir_path = dirs$report_dir, cols_extra = intersect(cols_extra, colnames(out)))
  intrnl_print_summary(out, time_start = time_start,
                       file_report = intrnl_dir_to_file(dirs$report_dir),
                       dir_session = if(run_function == "external") dir_session else NULL)
  invisible(out)
}

## summary printed at the end of rpl_replicate()
intrnl_print_summary <- function(out, time_start, file_report, dir_session = NULL) {
  cat("\n## replicater:", nrow(out), "scripts run in", intrnl_time_format(Sys.time() - time_start),
      "with", sum(out$has_error), "errors\n")

  ## compare with the last run
  if("has_error_last" %in% colnames(out)) {
    errors_new <- out$filename[out$has_error & out$has_error_last %in% FALSE]
    errors_fixed <- out$filename[!out$has_error & out$has_error_last %in% TRUE]
    if(length(errors_new) > 0) cat("New errors (no error last run):", paste(errors_new, collapse = ", "), "\n")
    if(length(errors_fixed) > 0) cat("Fixed since last run:", paste(errors_fixed, collapse = ", "), "\n")
  }
  if(any(out$has_error)) {
    cat("\nErrors:\n")
    rpl_showErr(out)
  }

  cat("\nSlowest scripts:\n")
  out %>%
    dplyr::slice_max(.data$elapsed, n = 5, with_ties = FALSE) %>%
    dplyr::transmute(filename = .data$filename,
                     seconds = round(.data$elapsed, 1),
                     time = intrnl_time_format_vec(.data$elapsed)) %>%
    print()

  cat("\nReport:", file_report, "\n")
  if(!is.null(dir_session)) cat(".Rout files:", dir_session, "\n")
}
