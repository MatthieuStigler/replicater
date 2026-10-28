
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

2.  A master script sets the folders of the report (`rpl_set_dirs()`), then pipes two verbs: `rpl_list_scripts()` lists the scripts in the order they will run, and `rpl_replicate()` installs the missing packages, runs the scripts and appends the run to the report `replication_report.csv`.
3.  On the next run, the scripts that failed or got fixed since the previous run are reported.

## Example

The package ships 10 small scripts, some of them failing on purpose.

``` r
library(replicater)
library(dplyr)
```

**1. Set the folders** of the report and of the `.Rout` files (here a temporary folder; in a project, e.g. `"code_meta"`):

``` r
rpl_set_dirs(report_dir = tempdir())
```

**2. List the scripts** in the order they will run, with all the fields of their YAML header. The table can be filtered further with dplyr before running:

``` r
path_scripts <- system.file("r_scripts_fake", package = "replicater")

scripts <- rpl_list_scripts(path_scripts)
scripts %>%
  select(filename, has_yaml_header, run_replicate, Author)
#> # A tibble: 10 × 4
#>    filename                     has_yaml_header run_replicate Author  
#>    <chr>                        <lgl>           <lgl>         <chr>   
#>  1 1_1_light_one_rLo.R          TRUE            TRUE          Jane Doe
#>  2 1_2_heavy_one_rLoH.R         TRUE            TRUE          Jane Doe
#>  3 1_3_2_lightest_error_rLoEr.R TRUE            TRUE          Jane Doe
#>  4 1_3_light_error_rLoE.R       TRUE            TRUE          Jane Doe
#>  5 1_4_sleep_3_rLoS.R           TRUE            TRUE          Jane Doe
#>  6 1_5_SUPER_heavy_norun.R      TRUE            FALSE         Jane Doe
#>  7 1_6_load_package.R           TRUE            TRUE          Jane Doe
#>  8 1_7_messages_annoying.R      TRUE            NA            Jane Doe
#>  9 1_8_parse_error.R            TRUE            TRUE          Jane Doe
#> 10 1_9_no_yaml.R                FALSE           NA            <NA>
```

**3. Run the scripts**, each in a new R session. The script with `run_replicate: FALSE` is skipped. The run is appended to the report, and a summary is printed:

``` r
out <- scripts %>%
  rpl_replicate(echo = FALSE)
#> All packages are installed.
#> 
#> ## replicater: 9 scripts run in <1 Min with 3 errors
#> 
#> Errors:
#> # A tibble: 3 × 2
#>   filename                     error                                            
#>   <chr>                        <chr>                                            
#> 1 1_3_2_lightest_error_rLoEr.R "Error in log(\"a\") : non-numeric argument to m…
#> 2 1_3_light_error_rLoE.R       "Error in `dplyr::select()`: ! Can't select colu…
#> 3 1_8_parse_error.R            "Error: unexpected '@' in \"@\" Execution halted"
#> [1] "Error in log(\"a\") : non-numeric argument to mathematical function Execution halted"             
#> [2] "Error in `dplyr::select()`: ! Can't select columns that don't exist. ✖ Column `lk` doesn't exist."
#> [3] "Error: unexpected '@' in \"@\" Execution halted"                                                  
#> 
#> Slowest scripts:
#> # A tibble: 5 × 3
#>   filename                seconds time  
#>   <chr>                     <dbl> <chr> 
#> 1 1_7_messages_annoying.R     1.5 <1 Min
#> 2 1_4_sleep_3_rLoS.R          0.6 <1 Sec
#> 3 1_2_heavy_one_rLoH.R        0.3 <1 Sec
#> 4 1_6_load_package.R          0.2 <1 Sec
#> 5 1_1_light_one_rLo.R         0.1 <1 Sec
#> 
#> Report: /tmp/Rtmphu9Wvw/replication_report.csv 
#> .Rout files: /tmp/Rtmphu9Wvw/sessions/session_2026_10_27
```

**4. Next time**, `rpl_list_scripts()` adds the result of the last run:

``` r
rpl_list_scripts(path_scripts) %>%
  select(filename, run_replicate, elapsed_last, has_error_last)
#> # A tibble: 10 × 4
#>    filename                     run_replicate elapsed_last has_error_last
#>    <chr>                        <lgl>                <dbl> <lgl>         
#>  1 1_1_light_one_rLo.R          TRUE                 0.123 FALSE         
#>  2 1_2_heavy_one_rLoH.R         TRUE                 0.282 FALSE         
#>  3 1_3_2_lightest_error_rLoEr.R TRUE                NA     TRUE          
#>  4 1_3_light_error_rLoE.R       TRUE                NA     TRUE          
#>  5 1_4_sleep_3_rLoS.R           TRUE                 0.621 FALSE         
#>  6 1_5_SUPER_heavy_norun.R      FALSE               NA     NA            
#>  7 1_6_load_package.R           TRUE                 0.217 FALSE         
#>  8 1_7_messages_annoying.R      NA                   1.48  FALSE         
#>  9 1_8_parse_error.R            TRUE                NA     TRUE          
#> 10 1_9_no_yaml.R                NA                   0.117 FALSE
```

`rpl_replicate()` chains functions that can also be used on their own: `rpl_check_deps()` and `rpl_install_missing()` (packages), `rpl_run_Rfiles()` (run), `rpl_showErr()` (errors), `rpl_write()` (report) and `rpl_add_info_last()` (previous run).

## In a project

A master script, run from the project root, e.g. `code_meta/replicate_all.R`. Its own `run_replicate: FALSE` makes sure it never runs itself:

``` r
#' ---
#' Title: "Rerun all scripts of the project and report errors"
#' run_replicate: FALSE
#' ---

library(replicater)
library(dplyr)

rpl_set_dirs(report_dir = "code_meta")

scripts <- rpl_list_scripts(c("code_setup", "code_analysis"), exclude = "888")

out <- scripts %>%
  rpl_replicate(install = "pak")
```
