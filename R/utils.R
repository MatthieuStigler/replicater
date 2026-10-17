## Copied from matPkg (R/list_directories.R and R/data.R), with mat_ renamed into rpl_

intrl_URLdecode_vec <- function(x) Vectorize(utils::URLdecode)(x)

#' List files in a directory
#'
#' @param path dir path
#' @param pattern,recursive passed to list.files
#' @param add_ext Add column with extension?
#' @param \ldots Additional arguments to \code{\link{list.files}}
#' @noRd
rpl_list_dir <- function(path, pattern = ".R", recursive = TRUE, add_ext = FALSE, ...) {

  ## check
  if(any(str_detect(path, "%20"))) path <- intrl_URLdecode_vec(path)
  if(!any(file.exists(path))) stop("Missing folder?")

  ## read
  li <- list.files(path, full.names = TRUE, pattern=pattern, recursive = recursive, ...)

  ## process
  res <- tibble(full_path=li) %>%
    mutate(filename= basename(.data$full_path))
  if(add_ext) res <-  res %>%
    mutate(ext = tools::file_ext(.data$filename))

  ## return
  res %>%
    dplyr::relocate("full_path", .after = everything())

}

#' Convert a named vector into a one-row tibble
#'
#' @param x vector
#' @param names optional names
#' @noRd
rpl_enframe_wide <- function(x, names=NULL){
  x_names <- if(!is.null(names)) names else  names(x)
  if(is.null(x_names)) x_names <- paste("col", 1:length(x), sep="_")
  if(any(x_names=="")) x_names[x_names==""] <- paste("col", which(x_names==""), sep="_")
  names(x) <- x_names
  x %>%
    tibble::enframe() %>%
    tidyr::pivot_wider(names_from = "name",
                       values_from="value", names_sort=FALSE)
}
