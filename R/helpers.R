#' Check dependencies in package
#'
#' @param path_scripts path where the scripts are located: folders or files
#' @param ... passed to `renv::dependencies()`, e.g. `quiet = TRUE, errors = "ignored"`
#'   to hide the parse errors of the scripts
#' @export
rpl_check_deps <- function(path_scripts=".", ...){
  ## check packages
  rnv_scripts <- renv::dependencies(path_scripts, ...)
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

#' Install missing packages
#'
#' Install the packages reported missing by `rpl_check_deps()`.
#' @param pkgs Package names, typically the output of `rpl_check_deps()`. `NA` values are dropped.
#' @param method `"install.packages"`, `"pak"` (uses `pak::pkg_install()`), or `"apt"`,
#'   which only prints the `sudo apt install r-cran-...` command for Debian/Ubuntu
#'   (binary packages as provided by r2u), without running it.
#' @param lib Folder where to install the packages. Default `NULL` is the first
#'   folder of `.libPaths()`. Not used by `method = "apt"`.
#' @param ... Passed to `install.packages()` or `pak::pkg_install()`, e.g. `type = "binary"` on Windows.
#' @return The packages to install, invisibly. For `method = "apt"`, the apt command.
#' @examples
#' rpl_install_missing(c("sf", "terra"), method = "apt")
#' \dontrun{
#' pkg_miss <- rpl_check_deps("code")
#' rpl_install_missing(pkg_miss)
#' rpl_install_missing(pkg_miss, lib = "Y:/shared_projects/R_shared_lib", type = "binary")
#' }
#' @export
rpl_install_missing <- function(pkgs, method = c("install.packages", "pak", "apt"),
                                lib = NULL, ...) {
  method <- match.arg(method)
  pkgs <- unique(pkgs[!is.na(pkgs)])
  if(length(pkgs) == 0) {
    message("No packages to install.")
    return(invisible(character()))
  }

  if(method == "apt") {
    if(!is.null(lib)) warning("Argument 'lib' not used when method == 'apt'")
    cmd <- paste("sudo apt install", paste0("r-cran-", tolower(pkgs), collapse = " "))
    message("Run in a terminal:\n", cmd)
    return(invisible(cmd))
  }

  if(is.null(lib)) lib <- .libPaths()[1]
  if(method == "pak") {
    if(!requireNamespace("pak", quietly = TRUE)) stop("Package 'pak' needed for method = 'pak'")
    pak::pkg_install(pkgs, lib = lib, ...)
  } else {
    utils::install.packages(pkgs, lib = lib, ...)
  }

  ## install.packages() only warns when a package fails
  still_missing <- setdiff(pkgs, installed.packages(lib.loc = unique(c(lib, .libPaths())))[, "Package"])
  if(length(still_missing) > 0) warning("Packages still missing: ", paste(still_missing, collapse = ", "))
  invisible(pkgs)
}
