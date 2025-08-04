#' Check dependencies in package
#'
#' @param path_scripts path where the scripts are located
rpl_check_deps <- function(path_scripts="."){
  ## check packages
  rnv_scripts <- renv::dependencies(path_scripts)
  all_pkgs <- unique(rnv_scripts$Package)

  ## check installed
  inst_pkgs <- installed.packages()[, "Package"]
  missing <- setdiff(all_pkgs, inst_pkgs)
  if(length(missing) > 0){
    message("The following packages are missing: ", paste(missing, collapse = ", "))
  } else {
    missing <- NA_character_
    message("All packages are installed.")
  }
  missing
}
