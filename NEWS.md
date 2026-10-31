# replicater 0.2

on 2026-10-28

* Replication pipe for the master script, one verb per step: `rpl_list_scripts()` (scripts in run order: order of `dir_path`, then folder and file name), `rpl_add_last_run()`, `rpl_check_packages()`, `rpl_run_scripts()`, `rpl_write_report()` and `rpl_print_summary()` (errors, new errors, fixed scripts, slowest scripts). `%>%` is re-exported.
* `rpl_set_dirs()` sets once the folder and name of the replication report and the folder of the archive of the `.Rout` files (`session_dir = NULL` switches the archive off, `report_file` changes the report name). `rpl_read_report()` reads the report back.
* `rpl_write()` and `rpl_add_info_last()`: `dir_path` defaults to the folder set by `rpl_set_dirs()` (still `"code_setup"` when not set).
* `rpl_add_info_last()` matches `./code_setup` with `code_setup`, and keeps `folder` as it is.
* `rpl_check_deps()`: `...` passed to `renv::dependencies()`, e.g. `quiet = TRUE, errors = "ignored"`.
* Fix: `rpl_run_Rfiles(echo = FALSE)` still printed for external runs.
* Fix: an empty script was reported as a YAML parse error.
* `rpl_install_missing()`: install the packages found by `rpl_check_deps()`, with `install.packages()` or pak, or print the `sudo apt install r-cran-...` command (#1).
* Remove the names specific to my own workflow (breaking changes):
  * YAML field `runMat` replaced by `run_replicate`. Columns `has_runMat` and `runMat_val` dropped: use the `run_replicate` column itself (`NA` when the field is missing). Column `has_yaml` renamed `has_yaml_header`.
  * `rpl_run_Rfiles()`: argument `runMat_true_only` replaced by `skip_false = TRUE`, which runs every script except those with `run_replicate: FALSE` (before: only the scripts with `runMat: TRUE`).
  * `rpl_list_Rfiles()` returns all the YAML fields. `keep_field` now only adds fields that no script has (as `NA`).
  * Report renamed `replication_report.csv`, with a new argument `report_file` in `rpl_write()` and `rpl_add_info_last()`. An existing `999_CHECK_RUN_report.csv` is still used when there is no `replication_report.csv`.
  * Files `R/99_run_check.R` and `R/999_source.R` renamed `R/run_check.R` and `R/source_scripts.R`.
* `rpl_write()`: when the existing report has other columns (old report format, other `cols_extra`), it is rewritten with the columns of both, instead of appending rows under the wrong header. `append = TRUE` on a missing file now writes the header.

# replicater 0.1

on 2026-10-17

* Import the whole 999 replicate infrastructure from matPkg
* Fix some bugs there

# replicater 0.0.0.9000

on 2025...

* rpl_check_deps(): wrapper for renv::dependencies()


