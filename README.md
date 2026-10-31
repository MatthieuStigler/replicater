
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

1.  **Each script** starts with a YAML header written with `#'` lines (as read by `knitr::spin()`). The field `run_replicate: FALSE` excludes a script from the run, for example a script that is too slow or that needs data you cannot share. Scripts without the field are run.

``` r
#' ---
#' Title: "Clean the raw data"
#' Author: "Jane Doe"
#' run_replicate: TRUE
#' ---
```

2.  **A master script**, run from the project root, sets the output folders with `rpl_set_dirs()`, then pipes one verb per step:

| Verb                   | What it does                                                                                       |
|------------------------|----------------------------------------------------------------------------------------------------|
| `rpl_list_scripts()`   | lists the R scripts with their YAML fields, in the order they will run                             |
| `rpl_add_last_run()`   | adds the result of the last run, read from the replication report                                  |
| `rpl_check_packages()` | lists the packages needed by the scripts that are not installed, and can install them              |
| `rpl_run_scripts()`    | runs each script in a new R session and archives its output                                        |
| `rpl_write_report()`   | appends the run to the replication report                                                          |
| `rpl_print_summary()`  | prints the errors, the scripts that broke or got fixed since the last run, and the slowest scripts |

Outside the pipe, `rpl_read_report()` reads the replication report back.

## What is written on disk

`rpl_set_dirs(report_dir = "code_meta")` writes nothing itself: it tells the verbs where to write two outputs, both inside `code_meta/`. There is no default folder: without `rpl_set_dirs()`, the verbs stop before running anything.

1.  **The replication report**, `code_meta/replicater_report.csv`, written by `rpl_write_report()`. A CSV file kept over time: each run adds one row per script, so the file holds the history of all the runs. Main columns:
    - `date`, `time`, `user_node` (<user@machine>) and `session_time` (total time of the scripts): when, by whom and how long;
    - `filename` and `folder`: the script;
    - `has_error`: whether the script failed, and `error`: the error message;
    - `elapsed`: the time taken by the script, in seconds;
    - `run_replicate`, plus the YAML fields given in `cols_extra` (by default `Author`).

    Read it back with `rpl_read_report()` (all runs) or `rpl_read_report(last_run = TRUE)`; at the next run, `rpl_add_last_run()` reads it too. Another name can be given with `rpl_set_dirs(report_dir = "code_meta", report_file = "my_report.csv")`. Without a name, an existing `999_CHECK_RUN_report.csv` (older projects) is used when there is no `replicater_report.csv`.
2.  **The archive of the script outputs**, `code_meta/sessions/session_YYYY_MM_DD/<script>.Rout`, written by `rpl_run_scripts()`. One `.Rout` file per script, with everything the script printed, its warnings and its error, in one folder per day of run (a second run on the same day overwrites it). The archive is on by default. To put it elsewhere: `rpl_set_dirs(report_dir = "code_meta", session_dir = "other/folder")`. To switch it off: `rpl_set_dirs(report_dir = "code_meta", session_dir = NULL)`.

## Example

The package ships 10 small scripts, some of them failing on purpose. Here the two outputs go to a temporary folder.

``` r
library(replicater)  # the replication verbs, and %>%
library(dplyr)       # select(), to show a few columns
```

**1. Set the output folders:**

``` r
dir_meta <- file.path(tempdir(), "code_meta")  # in a project: "code_meta"
rpl_set_dirs(report_dir = dir_meta)            # report and archive will go to dir_meta
```

**2. List the scripts** in the order they will run, with all the fields of their YAML header:

``` r
path_scripts <- system.file("r_scripts_fake", package = "replicater")  # folder of the example scripts
scripts <- rpl_list_scripts(path_scripts)                               # one row per script, in run order
scripts %>%
  select(filename, has_yaml_header, run_replicate, Author)              # show a few columns
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

**3. Run the pipe:**

``` r
runs <- scripts %>%
  rpl_add_last_run() %>%             # no report yet: has_error_last stays NA
  rpl_check_packages() %>%           # lists the missing packages (none here)
  rpl_run_scripts(echo = FALSE) %>%  # runs the 9 scripts not marked run_replicate: FALSE
  rpl_write_report() %>%             # writes dir_meta/replicater_report.csv
  rpl_print_summary()                # prints errors and slowest scripts
#> No replication report yet at /tmp/RtmpCmrIJb/code_meta/replicater_report.csv: no last run to add
#> All packages are installed.
#> .Rout files archived in /tmp/RtmpCmrIJb/code_meta/sessions/session_2026_10_31
#> Replication report: 9 rows added to /tmp/RtmpCmrIJb/code_meta/replicater_report.csv
#> 
#> ## replicater: 9 scripts run, 3 with errors. Time of the scripts without error: <1 Min 
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
#> 1 1_7_messages_annoying.R     1.4 <1 Min
#> 2 1_4_sleep_3_rLoS.R          0.6 <1 Sec
#> 3 1_2_heavy_one_rLoH.R        0.3 <1 Sec
#> 4 1_6_load_package.R          0.2 <1 Sec
#> 5 1_9_no_yaml.R               0.1 <1 Sec
```

**4. The two outputs on disk:**

``` r
## the replication report dir_meta/replicater_report.csv: one row per script and run
rpl_read_report() %>%
  select(date, filename, has_error, error, elapsed)
#> # A tibble: 9 × 5
#>   date       filename                     has_error error                elapsed
#>   <date>     <chr>                        <lgl>     <chr>                  <dbl>
#> 1 2026-10-31 1_1_light_one_rLo.R          FALSE      <NA>                  0.107
#> 2 2026-10-31 1_2_heavy_one_rLoH.R         FALSE      <NA>                  0.261
#> 3 2026-10-31 1_3_2_lightest_error_rLoEr.R TRUE      "Error in log(\"a\"…  NA    
#> 4 2026-10-31 1_3_light_error_rLoE.R       TRUE      "Error in `dplyr::s…  NA    
#> 5 2026-10-31 1_4_sleep_3_rLoS.R           FALSE      <NA>                  0.609
#> 6 2026-10-31 1_6_load_package.R           FALSE      <NA>                  0.202
#> 7 2026-10-31 1_7_messages_annoying.R      FALSE      <NA>                  1.38 
#> 8 2026-10-31 1_8_parse_error.R            TRUE      "Error: unexpected …  NA    
#> 9 2026-10-31 1_9_no_yaml.R                FALSE      <NA>                  0.114

## the archive: one .Rout file per script, in the folder of the day
list.files(file.path(dir_meta, "sessions"), recursive = TRUE)
#> [1] "session_2026_10_31/1_1_light_one_rLo.Rout"         
#> [2] "session_2026_10_31/1_2_heavy_one_rLoH.Rout"        
#> [3] "session_2026_10_31/1_3_2_lightest_error_rLoEr.Rout"
#> [4] "session_2026_10_31/1_3_light_error_rLoE.Rout"      
#> [5] "session_2026_10_31/1_4_sleep_3_rLoS.Rout"          
#> [6] "session_2026_10_31/1_6_load_package.Rout"          
#> [7] "session_2026_10_31/1_7_messages_annoying.Rout"     
#> [8] "session_2026_10_31/1_8_parse_error.Rout"           
#> [9] "session_2026_10_31/1_9_no_yaml.Rout"
```

**5. At the next run**, `rpl_add_last_run()` adds the result of the last run:

``` r
scripts %>%
  rpl_add_last_run() %>%                                       # reads dir_meta/replicater_report.csv
  select(filename, run_replicate, elapsed_last, has_error_last)
#> # A tibble: 10 × 4
#>    filename                     run_replicate elapsed_last has_error_last
#>    <chr>                        <lgl>                <dbl> <lgl>         
#>  1 1_1_light_one_rLo.R          TRUE                 0.107 FALSE         
#>  2 1_2_heavy_one_rLoH.R         TRUE                 0.261 FALSE         
#>  3 1_3_2_lightest_error_rLoEr.R TRUE                NA     TRUE          
#>  4 1_3_light_error_rLoE.R       TRUE                NA     TRUE          
#>  5 1_4_sleep_3_rLoS.R           TRUE                 0.609 FALSE         
#>  6 1_5_SUPER_heavy_norun.R      FALSE               NA     NA            
#>  7 1_6_load_package.R           TRUE                 0.202 FALSE         
#>  8 1_7_messages_annoying.R      NA                   1.38  FALSE         
#>  9 1_8_parse_error.R            TRUE                NA     TRUE          
#> 10 1_9_no_yaml.R                NA                   0.114 FALSE
```

The verbs build on lower level functions, which can also be used on their own: `rpl_list_Rfiles()`, `rpl_check_deps()`, `rpl_install_missing()`, `rpl_run_Rfiles()`, `rpl_showErr()`, `rpl_write()` and `rpl_add_info_last()`.

## In a project

A master script, saved for example as `code_meta/replicate_all.R` and run from the project root:

``` r
#' ---
#' Title: "Rerun all scripts of the project and report errors"
#' run_replicate: FALSE
#' ---
## run_replicate: FALSE above: the master script never runs itself

library(replicater)  # the replication verbs, and %>%

## Where to write (nothing is written by this line, the verbs below use it):
## report:  code_meta/replicater_report.csv
## archive: code_meta/sessions/session_YYYY_MM_DD/<script>.Rout
rpl_set_dirs(report_dir = "code_meta")
## rpl_set_dirs(report_dir = "code_meta", session_dir = NULL)  # same, without the archive

rpl_list_scripts(c("code_setup", "code_analysis"),  # scripts of code_setup first, then of code_analysis
                 exclude = "888") %>%               # skip the helper scripts 888_*, sourced by the others
  rpl_add_last_run() %>%                            # add the result of the last run, from the report
  rpl_check_packages(install = "pak") %>%           # install the missing packages with pak
  rpl_run_scripts() %>%                             # run each script in a new R session, archive its .Rout file
  rpl_write_report() %>%                            # append this run to code_meta/replicater_report.csv
  rpl_print_summary()                               # print errors, new errors, fixed and slowest scripts
```
