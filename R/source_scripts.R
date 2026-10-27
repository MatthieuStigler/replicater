## Copied from matPkg (R/999_source.R)

#' @param debug internal to show more
#' @noRd
source_throw <- function(path, echo=TRUE, all.names=TRUE, debug=FALSE) {
  if(echo) cat(paste("\nDoing file: ", basename(path), "\n"))
  gc()
  mem_before <- lobstr::mem_used()
  env_random <-  new.env(parent = .GlobalEnv)
  ## main line: source file, measuring time and memory!
  time_before <- Sys.time()
  if(!debug){
    sys <- purrr::safely(~system.time(suppressMessages(sys.source(., envir = env_random,
                                                                  keep.source=FALSE,
                                                                  keep.parse.data=FALSE))))(path)
  } else {
    print(.packages())
    sys <- purrr::safely(~system.time(sys.source(., envir = env_random,
                                                 keep.source=FALSE,
                                                 keep.parse.data=FALSE)))(path)
  }
  time_after <- Sys.time()
  mem_after <- lobstr::mem_used()
  ls_env <- ls(envir = env_random, all.names = all.names)


  ## errors:
  has_error <- !is.null(sys$error)

  ## clean
  ## this will remove the ".last_plot" from ggplot, see https://stackoverflow.com/questions/64654252/r-deleting-ggplot2-object-does-not-free-space-possible-memory-leakage
  if(isNamespaceLoaded("ggplot2")) ggplot2::set_last_plot(NULL)
  rm(list = ls_env, envir = env_random)
  rm(env_random)
  gc()

  # memory count
  mem_final <- lobstr::mem_used()
  mems_info <- c(mem_before=mem_before, mem_after=mem_after,
                 mem_diff=mem_after-mem_before,
                 mem_final=mem_final)
  if(echo) {
    mems_info_char <- intrnl_bytes_to_chr(x=mems_info, unit="MB")
    mems_info_char2 <- paste(stringr::str_remove(names(mems_info), "mem_"), mems_info_char, sep=": ")
    cat("\t-Memory: ", paste(mems_info_char2, collapse = ", "), "\n")
    cat("\t-Approx time: ", intrnl_time_format(time_after-time_before), "\n")
    if(has_error){
      cat("\t-ERROR: ", intrnl_err_to_chr(sys$error), "\n")
    }
    cat(paste("\t-Done with file", path, "\n"))
  }
  if(!has_error) {
    sys$result <- t(data.matrix(sys$result)) %>%
      as.data.frame() %>%
      as_tibble() %>%
      mutate(memory_used_mb = intrnl_bytes_to_num(mems_info["mem_diff"], unit = "MB")) %>%
      mutate_at(c("memory_used_mb", "elapsed"), round, 1)
  }
  sys
}


source_rcmd_batch <- function(path, echo=TRUE, tmp_dir=NULL, cmd_vanilla = FALSE){

  if(echo) cat(paste("\nDoing file: ", basename(path), "\n"))

  ## run file external
  if(is.null(tmp_dir)) tmp_dir <- tempdir()
  tmp_file <- file.path(tmp_dir, paste0(basename(path), "out"))
  cmd_args <- c("--no-save", "--no-restore",
                if(cmd_vanilla) "--vanilla" else NULL)
  time_before <- Sys.time()
  out <- callr::rcmd_safe("BATCH",
                          cmdargs = c(cmd_args,
                                      infile  = path,
                                      outfile = tmp_file))
  time_after <- Sys.time()

  ## read
  out_file <- readLines(tmp_file)
  proc_line <- grepl("proc.time\\(\\)$", out_file)
  has_normal_end <- any(proc_line) && out$status == 0
  res <- list(result=NULL, error=NULL)

  if(has_normal_end){
    ok_lines <- out_file[which(proc_line):length(out_file)]
    time_line <- ok_lines[grepl("([0-9]+ )+", ok_lines)]
    times <- stringr::str_extract_all(time_line, "[0-9\\.]+")[[1]] %>% as.numeric()
    res$result <- rpl_enframe_wide(times, names = c("user.self", "sys.self", "elapsed")) %>%
      mutate(user.child=NA_real_, sys.child=NA_real_,  memory_used_mb=NA_real_)
  } else {
    error_line_pos <- grepl("^Error(:| in)", out_file)
    if(all(!error_line_pos)) {
      was_killed <- any(grepl("^Killed$", utils::tail(out_file)))
      if(was_killed) {
        res$error <- "KILLED"
        warning("Script killed!")
      } else if(out$status != 0) {
        res$error <- paste("Script stopped with exit status", out$status)
      } else {
        warning("Unknown reason for script to stop, without error/kill")
        res$error <- "UNDETECTED ERROR"
      }
      error_lines_short <- res$error
    } else {
      backtrace_line_pos <- grepl("^Backtrace:", out_file)
      if(!any(backtrace_line_pos)) backtrace_line_pos[length(out_file)+1] <- TRUE
      error_lines_short <- out_file[which(error_line_pos):(which(backtrace_line_pos)-1)]
      error_lines_all <- out_file[which(error_line_pos):length(out_file)]
      res$error <- error_lines_all
    }
  }

  if(echo) {
    cat("\t-Memory: no info\n")
    cat("\t-Approx time: ", intrnl_time_format(time_after-time_before), "\n")
    if(!has_normal_end){
      cat("\t-ERROR: ", error_lines_short, "\n")
    }
    cat(paste("\t-Done with file", path, "\n"))
  }

  res
}
