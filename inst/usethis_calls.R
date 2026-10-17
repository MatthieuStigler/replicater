library(usethis)

usethis::use_package("renv")


usethis::use_import_from("utils", "installed.packages")

usethis::use_test()

## functions copied from matPkg (mat_99_* -> rpl_*)
for(pkg in c("callr", "dplyr", "knitr", "lobstr", "magrittr", "purrr", "readr",
             "rlang", "rmarkdown", "stringr", "tibble", "tidyr", "tidyselect", "tools")) {
  usethis::use_package(pkg)
}
usethis::use_package("ggplot2", type = "Suggests")
