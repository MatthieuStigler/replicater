
<!-- README.md is generated from README.Rmd. Please edit that file -->

# replicater

<!-- badges: start -->

[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental) [![CRAN status](https://www.r-pkg.org/badges/version/replicater)](https://CRAN.R-project.org/package=replicater) <!-- badges: end -->

The goal of replicater is to check that an R project still runs from start to end. It runs every script of the project in a fresh R session, and writes a report with the errors and run time of each script, which can be compared with the previous run.

## Installation

You can install the development version of replicater like so:

``` r
remotes::install_github("MatthieuStigler/replicater", upgrade = "never")
```

## How it works

1.  Each script starts with a YAML header written with `#'` lines (as read by `knitr::spin()`). The field `run_replicate: FALSE` excludes a script from the run, for example a script that is too slow or that needs data you cannot share. Scripts without the field are run.

``` r
#' ---
#' Title: "Clean the raw data"
#' Author: "Jane Doe"
#' run_replicate: TRUE
#' ---
```

2.  A master script lists the scripts, installs the missing packages, runs the scripts in order and appends the result to the report `replication_report.csv`.
3.  On the next run, the report tells which scripts failed or were slow the previous time.

## Example

The package ships 10 small scripts, some of them failing on purpose.

``` r
library(replicater)
library(dplyr)
```

**1. List the scripts**, with all the fields of their YAML header:

``` r
path_scripts <- system.file("r_scripts_fake", package = "replicater")

scripts <- rpl_list_Rfiles(path_scripts)
scripts %>%
  select(filename, number, has_yaml_header, run_replicate, Author)
#> # A tibble: 10 × 5
#>    filename                     number has_yaml_header run_replicate Author  
#>    <chr>                         <dbl> <lgl>           <lgl>         <chr>   
#>  1 1_1_light_one_rLo.R            1.1  TRUE            TRUE          Jane Doe
#>  2 1_2_heavy_one_rLoH.R           1.2  TRUE            TRUE          Jane Doe
#>  3 1_3_2_lightest_error_rLoEr.R   1.32 TRUE            TRUE          Jane Doe
#>  4 1_3_light_error_rLoE.R         1.3  TRUE            TRUE          Jane Doe
#>  5 1_4_sleep_3_rLoS.R             1.4  TRUE            TRUE          Jane Doe
#>  6 1_5_SUPER_heavy_norun.R        1.5  TRUE            FALSE         Jane Doe
#>  7 1_6_load_package.R             1.6  TRUE            TRUE          Jane Doe
#>  8 1_7_messages_annoying.R        1.7  TRUE            NA            Jane Doe
#>  9 1_8_parse_error.R              1.8  TRUE            TRUE          Jane Doe
#> 10 1_9_no_yaml.R                  1.9  FALSE           NA            <NA>
```

**2. Check the packages** used by the scripts. `rpl_check_deps()` returns the missing ones (`NA` when none is missing), to pass to `rpl_install_missing()`:

``` r
pkg_miss <- rpl_check_deps(path_scripts)
```

``` r
rpl_install_missing(pkg_miss)                  # with install.packages()
rpl_install_missing(pkg_miss, method = "pak")  # with pak::pkg_install()
rpl_install_missing(pkg_miss, method = "apt")  # prints the "sudo apt install r-cran-..." command
```

**3. Run the scripts**, each in a new R session (`run_function = "external"`). The `.Rout` file of each script is kept in `tmp_dir`. The script with `run_replicate: FALSE` is skipped:

``` r
dir_session <- file.path(tempdir(), "session_1")
dir.create(dir_session)
out <- rpl_run_Rfiles(scripts, run_function = "external", tmp_dir = dir_session)
```

``` r
out %>%
  select(filename, has_error, elapsed)
#> # A tibble: 9 × 3
#>   filename                     has_error elapsed
#>   <chr>                        <lgl>       <dbl>
#> 1 1_1_light_one_rLo.R          FALSE       0.13 
#> 2 1_2_heavy_one_rLoH.R         FALSE       0.297
#> 3 1_3_2_lightest_error_rLoEr.R TRUE       NA    
#> 4 1_3_light_error_rLoE.R       TRUE       NA    
#> 5 1_4_sleep_3_rLoS.R           FALSE       0.629
#> 6 1_6_load_package.R           FALSE       0.228
#> 7 1_7_messages_annoying.R      FALSE       1.47 
#> 8 1_8_parse_error.R            TRUE       NA    
#> 9 1_9_no_yaml.R                FALSE       0.146
```

**4. Show the errors:**

``` r
rpl_showErr(out)
#> # A tibble: 3 × 2
#>   filename                     error                                            
#>   <chr>                        <chr>                                            
#> 1 1_3_2_lightest_error_rLoEr.R "Error in log(\"a\") : non-numeric argument to m…
#> 2 1_3_light_error_rLoE.R       "Error in `dplyr::select()`: ! Can't select colu…
#> 3 1_8_parse_error.R            "Error: unexpected '@' in \"@\" Execution halted"
#> [1] "Error in log(\"a\") : non-numeric argument to mathematical function Execution halted"             
#> [2] "Error in `dplyr::select()`: ! Can't select columns that don't exist. ✖ Column `lk` doesn't exist."
#> [3] "Error: unexpected '@' in \"@\" Execution halted"
```

**5. Write the report.** Each run is appended to `replication_report.csv` in `dir_path`. On the next run, `rpl_add_info_last()` adds the result of the last run to the list of scripts:

``` r
dir_report <- tempdir()
rpl_write(out, dir_path = dir_report, cols_extra = "Author")

rpl_list_Rfiles(path_scripts) %>%
  rpl_add_info_last(dir_path = dir_report) %>%
  select(filename, run_replicate, elapsed_last, has_error_last)
#> # A tibble: 10 × 4
#>    filename                     run_replicate elapsed_last has_error_last
#>    <chr>                        <lgl>                <dbl> <lgl>         
#>  1 1_1_light_one_rLo.R          TRUE                 0.13  FALSE         
#>  2 1_2_heavy_one_rLoH.R         TRUE                 0.297 FALSE         
#>  3 1_3_2_lightest_error_rLoEr.R TRUE                NA     TRUE          
#>  4 1_3_light_error_rLoE.R       TRUE                NA     TRUE          
#>  5 1_4_sleep_3_rLoS.R           TRUE                 0.629 FALSE         
#>  6 1_5_SUPER_heavy_norun.R      FALSE               NA     NA            
#>  7 1_6_load_package.R           TRUE                 0.228 FALSE         
#>  8 1_7_messages_annoying.R      NA                   1.47  FALSE         
#>  9 1_8_parse_error.R            TRUE                NA     TRUE          
#> 10 1_9_no_yaml.R                NA                   0.146 FALSE
```

## In a project

Put these steps in a master script, run from the project root. Give the master script itself `run_replicate: FALSE` in its YAML header, so it does not run itself:

``` r
library(replicater)
library(dplyr)

scripts <- rpl_list_Rfiles("code", recursive = TRUE) %>%
  rpl_add_info_last(dir_path = "code/code_meta", warn = FALSE)

rpl_check_deps("code") %>%
  rpl_install_missing()

dir_session <- paste0("code/code_meta/session_", Sys.Date())
dir.create(dir_session, recursive = TRUE, showWarnings = FALSE)
out <- rpl_run_Rfiles(scripts, echo = TRUE, run_function = "external",
                      tmp_dir = dir_session)

rpl_showErr(out)
rpl_write(out, dir_path = "code/code_meta", cols_extra = "Author")
```
