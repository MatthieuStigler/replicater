## Copied from matPkg (R/99_run_check.R), with mat_ renamed into rpl_

################################
### Internal utilities
################################

intrnl_report_default <- "replication_report.csv"
intrnl_report_old <- "999_CHECK_RUN_report.csv"

## path of the report: report_file if given, else the default name, else the old
## 999 name when only that file exists (keeps the history of older projects)
intrnl_dir_to_file <- function(dir, report_file = NULL) {
  files <- paste(dir, c(report_file, intrnl_report_default, intrnl_report_old), sep = "/") %>%
    str_replace("//", "/")
  if(!is.null(report_file)) return(files[1])
  if(!file.exists(files[1]) && file.exists(files[2])) files[2] else files[1]
}

intrnl_cols_need <- c("session", "session_time",
                     "user_node",
                     "filename", "folder", "subfolder",
                     "error", "has_error",
                     "elapsed", "memory_used_mb",
                     "user.self", "sys.self", "user.child",
                     "sys.child", "ext", "number_char", "number", "error_parse",
                     "has_error_parse", "has_yaml_header", "run_replicate",
                     "date", "time")

## folder without leading "./", to match "./code_setup" with "code_setup"
intrnl_folder_key <- function(folder) str_replace(as.character(folder), "^\\./", "")

## YAML field as logical (TRUE, FALSE or NA), warning about other values
intrnl_field_to_lgl <- function(x, filename, field = "run_replicate") {
  one_lgl <- function(v) if(length(v) == 1 && is.atomic(v)) as.logical(v) else NA
  x_lgl <- if(is.list(x)) map_lgl(x, one_lgl) else as.logical(x)
  x_given <- if(is.list(x)) !map_lgl(x, ~length(.) == 0 || (length(.) == 1 && is.na(.))) else !is.na(x)
  x_bad <- x_given & is.na(x_lgl)
  if(any(x_bad)) {
    warning("YAML field '", field, "' should be TRUE or FALSE, other values are read as NA in: ",
            paste(filename[x_bad], collapse = ", "), call. = FALSE)
  }
  x_lgl
}

## old report and new rows with different columns (older report format, other cols_extra):
## bind them as text, after renaming has_yaml and dropping the old runMat columns when empty
intrnl_report_merge <- function(file_out, df_new) {
  df_old <- readr::read_csv(file_out, col_types = readr::cols(.default = "c"))
  if("has_yaml" %in% colnames(df_old) && !"has_yaml_header" %in% colnames(df_old)) {
    df_old <- rename(df_old, has_yaml_header = "has_yaml")
  }
  cols_old_empty <- intersect(c("has_runMat", "runMat_val"), colnames(df_old)) %>%
    purrr::keep(~all(is.na(df_old[[.]])))
  message("Report ", basename(file_out), " has other columns than the new rows: rewriting it with the columns of both")

  dplyr::bind_rows(select(df_old, -tidyselect::all_of(cols_old_empty)),
                   mutate(df_new, dplyr::across(tidyselect::everything(), as.character))) %>%
    select(tidyselect::all_of(colnames(df_new)), tidyselect::everything())
}


intrnl_time_format <- function(x) {
  if(is.na(x)) return(NA_character_)

  # Convert difftime safely to seconds
  if (inherits(x, "difftime")) {
    x <- as.numeric(x, units = "secs")
  }
  if(x<1) return("<1 Sec")

  mins <-  x/60
  if(mins<1) return("<1 Min")

  if(mins >60) {
    H <- mins %/% 60
    Min <- mins %% 60
    H_Min <- paste0(H, ":", stringr::str_pad(round(Min),width = 2, pad = "0"))
    return(paste0(H_Min, " Hour"))
  }
  dig <- ifelse(mins<5, 1,0)
  return(paste(round(mins, dig), "Min"))
}

intrnl_time_format_vec <- function(x) sapply(x, intrnl_time_format)
intrnl_err_to_chr <- function(x){
  if(inherits(x, "condition")){
    res <- rlang::with_options(crayon.enabled = FALSE,
                               rlang::cnd_message(x, prefix = TRUE))
  } else {
    backtrace_line <- grepl("Backtrace", x)
    end <- if(any(backtrace_line)) which(backtrace_line)-1 else length(x)
    res <- paste(x[1:end], collapse = " ")
  }
  res
}

#' Read YAML header to list
#' @param file_path The file path
#' @noRd
rpl_parse_yaml <- function(file_path){
  ## remove #' to have standard YAMl header
  input_lines <- readLines(file_path, warn=FALSE)
  if(length(input_lines) == 0) return(list()) ## empty script: no header
  input_lines <- knitr::spin(text = input_lines, knit = FALSE)
  tmp <- tempfile()
  writeLines(input_lines, tmp)

  ## now use rmarkdown::yaml_front_matter
  rmarkdown::yaml_front_matter(tmp)
}


################################
### Step 1: list R scripts
################################


#' @param dir_path directory of files
#' @param no_old Avoid scripts in directory old?
#' @param recursive Look into recursive folders?
#' @param keep_field YAML fields to return even when no script has them (filled
#'   with `NA`). All YAML fields found in the scripts are returned anyway, and
#'   `run_replicate` always is.
#' @param check_numbers Whether to check if numbers are ambiguous?
#' @export
#' @rdname rpl_run_Rfiles
rpl_list_Rfiles <- function(dir_path="code_setup", no_old = TRUE, recursive=FALSE,
                            keep_field=NULL,
                            check_numbers= TRUE) {

  dir_df <- rpl_list_dir(dir_path, pattern="\\.R$", add_ext = TRUE, recursive = recursive) %>%
    mutate(full_path = str_replace_all(.data$full_path, "//", "/"),
           folder = dirname(.data$full_path),
           subfolder = basename(dirname(.data$full_path)))

  ## get yaml
  res <- dir_df %>%
    mutate(number_char = str_extract(.data$filename, "([0-9]+_)+") %>%
             str_replace("_$", ""),
           number = .data$number_char %>%
             str_replace("_", "\\.") %>%
             str_replace_all("_", "") %>%
             as.numeric(),
           yaml = map(.data$full_path, ~purrr::safely(rpl_parse_yaml)(.)))

  ## check numbers
  if(check_numbers && anyDuplicated(res$number) & !all(is.na(res$number))){
    warning("Ambiguous numbers! Check with:\n
        add_count(number, subfolder, name = 'n_num') %>%
        filter(n_num>1) %>%
        arrange(subfolder, number) %>%
        select(filename, folder, subfolder, number_char, number)")
  }

  ## process yaml
  safely_clean <- function(x) {
    if(!is.null(x$error)){
      x$error <- intrnl_err_to_chr(x$error)
    }
    x
  }
  ## unnest
  res_yaml_df <- res %>%
    dplyr::mutate(yaml = purrr::map(.data$yaml, safely_clean)) %>%
    tidyr::unnest_wider("yaml")

  ## check if any yaml header
  if(!all(is.na(res_yaml_df$result))) {
    res_yaml_df <- res_yaml_df%>%
      tidyr::unnest_wider("result")
  }
  ## YAML fields: run_replicate, then all fields found, then keep_field (added if missing)
  fields_all <- res$yaml %>%
    map(~names(.$result)) %>%
    unlist() %>%
    c("run_replicate", ., keep_field) %>%
    unique()
  fields_miss <- setdiff(fields_all, colnames(res_yaml_df))
  res_yaml_df <- res_yaml_df %>%
    tibble::add_column(!!!rlang::rep_named(fields_miss, list(NA))) %>%
    mutate(run_replicate = intrnl_field_to_lgl(.data$run_replicate, .data$filename),
           yaml=  purrr::transpose(res$yaml) %>% purrr::pluck("result"),
           has_yaml_header=map_lgl(.data$yaml, ~ !rlang::is_empty(.)))

  if(!"error" %in% colnames(res_yaml_df)){
    res_yaml_df <- res_yaml_df %>%
      mutate(has_error_parse=FALSE,
             error_parse=NA_character_)
  } else {
    res_yaml_df <- res_yaml_df %>%
      mutate(has_error_parse=map_lgl(.data$error, ~!is.null(.) &!is.na(.)),
             error_parse=map2_chr(.data$error, .data$has_error_parse,
                                  ~dplyr::if_else(.y,
                                                 as.character(.x),
                                                 NA_character_)))
  }

  vars <- c("filename", "ext", "folder", "subfolder", "number_char", "number",
            "yaml", "error_parse", "has_error_parse", "has_yaml_header",
            "full_path", fields_all)
  res_yaml_df <- res_yaml_df %>%
    select(tidyselect::all_of(vars)) %>%
    dplyr::relocate("full_path", .after = tidyselect::everything())

  if(no_old) res_yaml_df <-  res_yaml_df %>%
    filter(!stringr::str_detect(.data$full_path,
                                stringr::regex("old.*/", ignore_case = TRUE)))
  res_yaml_df
}


#' Run all scripts of a project and report errors
#'
#' List R scripts with their YAML header (`rpl_list_Rfiles()`), run them
#' (`rpl_run_Rfiles()`), show errors (`rpl_showErr()`) and write a report
#' `replication_report.csv` (`rpl_write()`).
#'
#' A script can be excluded from the run with the field `run_replicate: FALSE`
#' in its YAML header.
#'
#' These functions were copied from the `mat_99_*` functions of the package matPkg.
#' @param echo print which file done, and gc?
#' @param skip_false Skip the scripts with `run_replicate: FALSE` in their YAML
#'   header? Scripts without the field are run.
#' @param run_function use either source (internal) or R CMD BATCH (external)
#' @param tmp_dir temporary dir to hold file when using `run_function="external"`
#' @param run_cmd_vanilla when `run_function="external"`, should `--vanilla` be added?
#' @examples
#' library(replicater)
#' library(readr)
#'
#' ## read
#' path_rscripts <- system.file("r_scripts_fake", package = "replicater")
#' path_temp <- tempdir()
#' dir_dat <- rpl_list_Rfiles(path_rscripts)
#' dir_dat
#'
#' ## run
#' out <- rpl_run_Rfiles(dir_dat)
#' out
#' rpl_showErr(out)
#'
#' ## save
#' rpl_write(out, dir = path_temp)
#'
#' ## check output
#' read_csv(paste(path_temp, "replication_report.csv", sep="/"), col_types = cols())
#'
#' ## re-write
#' rpl_write(out, dir = path_temp)
#' read_csv(paste(path_temp, "replication_report.csv", sep="/"), col_types = cols())
#' @export
rpl_run_Rfiles <- function(scripts_file, echo=FALSE, skip_false=TRUE,
                           run_function=c("internal", "external"), tmp_dir=NULL, run_cmd_vanilla = FALSE) {

  run_function <- match.arg(run_function)
  if(!is.null(tmp_dir)) {
    tmp_dir <- normalizePath(tmp_dir, mustWork = FALSE)
    if(run_function=="internal") warning("Argument 'tmp_dir' not relevant when run_function=='internal'")
  }
  run_function <- switch(run_function,
                         "internal"= function(x) source_throw(x, echo =echo),
                         "external"= function(x) source_rcmd_batch(x, echo = echo, tmp_dir=tmp_dir, cmd_vanilla=run_cmd_vanilla))

  if(skip_false && "run_replicate" %in% colnames(scripts_file)) {
    scripts_file <- scripts_file %>%
      filter(!(.data$run_replicate %in% FALSE))
    if(nrow(scripts_file)==0) stop("All R scripts have 'run_replicate: FALSE', set argument 'skip_false=FALSE' ?")
  }

  ## prep out data
  vars_out <- c("filename", "has_error", "error",
                "elapsed", "memory_used_mb",
                "user.self", "sys.self", "user.child", "sys.child")

  ## now RUN
  out <- scripts_file %>%
    mutate(try = map(.data$full_path, ~run_function(.))) %>%
    mutate(error=map(.data$try, ~.[["error"]]),
           has_error= map_lgl(.data$error, ~!is.null(.)),
           error=map_chr(.data$error, ~ifelse(is.null(.), NA, intrnl_err_to_chr(.))),
           timing = map2(.data$try, .data$has_error, ~if(.y) df_null else .x$result)) %>%
    unnest("timing") %>%
    dplyr::relocate(tidyselect::any_of(vars_out))

  ## small check
  if(!"memory_used_mb" %in% colnames(out)) {
    out <- mutate(out, memory_used_mb=NA) %>%
      dplyr::relocate(tidyselect::all_of(vars_out))
  }
  out
}

## utilities
df_null <-  data.frame("user.self" = NA, "sys.self" = NA, "elapsed" = NA, "user.child" = NA, "sys.child" = NA)


#' As character for bytes
#'
#' Simply copied from pryr:::print.bytes
#' @noRd
intrnl_bytes_to_chr <- function(x, digits = 1, unit=NULL) {

  if(is.null(unit)) {
    power <- min(floor(log(abs(x), 1000)), 4)
    unit <- c("B", "kB", "MB", "GB", "TB")[power+1]
  } else {
    unit <- match.arg(unit, choices=c("B", "kB", "MB", "GB", "TB"))
  }
  x <-  intrnl_bytes_to_num(x, unit=unit)
  formatted <- map_chr(x, ~format(signif(., digits = digits), big.mark = ",",
                     scientific = FALSE))
  paste(formatted,  unit)
}

#' As numeric for bytes, add argument unit
#'
#' @noRd
intrnl_bytes_to_num <- function(x, unit = c("B", "kB", "MB", "GB", "TB")) {
  unit <-  match.arg(unit)
  power <-  match(unit, c("B", "kB", "MB", "GB", "TB")) -1
  as.numeric(x/(1000^power))
}


#' @export
#' @rdname rpl_run_Rfiles
rpl_showErr <- function(scripts_file_runned) {
  df_probs <- scripts_file_runned %>%
    dplyr::filter(.data$has_error)

  print(df_probs %>%
    dplyr::select("filename", "error") )

  print(df_probs %>%
          dplyr::pull(.data$error))
}

#' @param scripts_file file of R scripts with path to run, from `rpl_list_Rfiles()`
#' @param scripts_file_runned data from `rpl_run_Rfiles()`
#' @param append Append to the existing report (default when it exists) or overwrite it?
#'   When the existing report has other columns (older replicater version, other
#'   `cols_extra`), it is rewritten with the columns of both.
#' @param cols_extra Extra columns to keep
#' @param report_file Name of the report file in `dir_path`. The default `NULL`
#'   uses `replication_report.csv`, or `999_CHECK_RUN_report.csv` when only that
#'   older file exists.
#' @export
#' @rdname rpl_run_Rfiles
rpl_write <- function(scripts_file_runned, dir_path=rpl_get_dirs()$report_dir,
                      append=NULL, cols_extra = NULL, report_file = NULL) {
  file_out <- intrnl_dir_to_file(dir_path, report_file)
  if(is.null(append)) append <- TRUE
  append <- append && file.exists(file_out)
  today <- Sys.Date() %>% as.character()
  user <- paste(Sys.info()[c("user", "nodename")], collapse = "@")

  ## add session info, etc
  df_new <- scripts_file_runned %>%
    dplyr::select_if(~!is.list(.)) %>%
    mutate(session = today,
           session = dplyr::if_else(duplicated(.data$session), "", .data$session),
           session_time = sum(.data$elapsed, na.rm=TRUE) %>%
             intrnl_time_format_vec(),
           date = today,
           time = Sys.time() %>% as.character(),
           folder = dirname(.data$full_path),
           subfolder = basename(dirname(.data$full_path)),
           user_node =user) %>%
    select(tidyselect::all_of(c(intrnl_cols_need, cols_extra)))

  ## existing report with other columns: rewrite it whole
  if(append) {
    cols_old <- colnames(readr::read_csv(file_out, n_max = 0, col_types = readr::cols()))
    if(!identical(cols_old, colnames(df_new))) {
      df_new <- intrnl_report_merge(file_out, df_new)
      append <- FALSE
    }
  }

  readr::write_csv(df_new, file_out, append=append)

}

#' @param warn Should it warn if file is actually missing?
#' @details `rpl_add_info_last()` matches scripts on `filename` and `folder`
#' (ignoring a leading `./`), so list the scripts from the same place across runs.
#' @export
#' @rdname rpl_run_Rfiles
rpl_add_info_last <- function(scripts_file_runned, dir_path=rpl_get_dirs()$report_dir, warn=TRUE,
                              report_file = NULL) {
  file_out <- intrnl_dir_to_file(dir_path, report_file)

  if(file.exists(file_out)) {
    df_out <- readr::read_csv(file_out, col_types = readr::cols()) %>%
      filter(.data$time==max(.data$time)) %>%
      dplyr::transmute(filename = .data$filename,
                       folder_key = intrnl_folder_key(.data$folder),
                       elapsed_last = .data$elapsed,
                       has_error_last = .data$has_error)

    ## join on a separate key, so folder stays as it is (e.g. a factor)
    scripts_file_runned <- scripts_file_runned %>%
      mutate(folder_key = intrnl_folder_key(.data$folder)) %>%
      left_join(df_out, by = c("filename", "folder_key")) %>%
      select(-"folder_key")
  } else {
    if(warn) warning("File not already there!")
  }
  scripts_file_runned
}
