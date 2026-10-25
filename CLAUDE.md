# replicater: open issues and planned changes

State as of 2026-10-17. replicater currently holds `rpl_list_Rfiles()`, `rpl_run_Rfiles()`, `rpl_showErr()`, `rpl_write()`, `rpl_add_info_last()` (copied from matPkg `mat_99_*`) and `rpl_check_deps()`.

## 1. Open GitHub issues

1. **#2 991 script never reads the previous report** (to fix). In `defBias_replicate/code_setup/code_meta/991_rerun_ALL.R`, the "Add previous info" block reads `code_meta/999_CHECK_RUN_report.csv`, but the report is written to `code_setup/code_meta/`. So `has_error_run_before` is never created. Fixing only the path is not enough: the join turns the factor `folder` into character, and `arrange(folder, filename)` would then run `./code_analysis` before `./code_setup`. Fix: correct both paths and move `fct_relevel()` after the join (as in the BRA 998 script), or replace the block with `rpl_add_info_last(dat_files, dir_path = "code_setup/code_meta", warn = FALSE)`, which keeps the factor order (column then called `has_error_last`). The bug is in the project script, not in the package, but it is a direct argument for the unified master file of section 2.
2. **#1 Feature: add function to install missing packages.** Today each project does it its own way: 991 installs Windows binaries into `Y:/shared_projects/R_shared_lib/<R version>`, the BRA 998 prints a `sudo apt install r-cran-...` line. A `rpl_install_missing()` could take the output of `rpl_check_deps()` and a method (`"install.packages"`, `"apt"`, `"pak"`), with an optional `lib` path.

## 2. Unified master file (open question)

Goal: one common master file instead of one hand edited copy per project. How to do it is not decided yet.

### 2.1 Current situation: two copies that drifted apart

| | defBias `991_rerun_ALL.R` | BRA `998_code_check_scripts.R` |
|---|---|---|
| Scripts folder (`dir_path`) | `"."` | `"CODE"` |
| Report written to | `code_setup/code_meta/` | `CODE/` |
| Previous report read from | `code_meta/` (wrong, issue #2) | `CODE/` |
| YAML fields kept | `run_replicate`, `Author` | `run_replicate`, `run_replicate_heavy`, `Author` |
| Package check | inline copy of `mat_99_check_deps()`, installs to `Y:` | `rpl_check_deps()`, switched off with `& FALSE` |
| Excluded scripts | `code_meta` folder, `888`, `OLD` | `888`, `OLD`, `archived`, plus ad hoc `filter_out()` on file names and numbers |
| Folder order | `fct_relevel()` before the join (lost after it) | `fct_relevel()` after the join |
| Extra steps | none | sources `0_5_archive_output.R` before the run, lists slow scripts, checks duplicated numbers, sends errors to GitHub on `maticloud` |
| Run call | external, `runMat_true_only = FALSE`, `tmp_dir` session folder | same |

Common skeleton of both files:

1. List scripts with their YAML header (`rpl_list_Rfiles()`).
2. Add the result of the previous run (`rpl_add_info_last()`).
3. Check and install missing packages (`rpl_check_deps()`, issue #1).
4. Filter the scripts to run (YAML field, excluded patterns, folder order).
5. Run them (`rpl_run_Rfiles()`), saving the `.Rout` files in a session folder.
6. Show errors (`rpl_showErr()`) and write the report (`rpl_write()`).
7. Read back the last session and print errors and slow scripts.
8. Optionally, post the errors to a GitHub issue (section 5).

### 2.2 Options

1. **Template file**: ship a master script in `inst/templates/` and a `rpl_use_master()` that copies it into a project (like `usethis`). Simple, but each copy can drift again, which is how 991 and 998 diverged.
2. **One wrapper function**: e.g. `rpl_replicate(dir_path, report_dir, exclude, keep_field, folder_order, github_issue = NULL)` doing steps 1 to 8; the master file shrinks to a few lines and project specific filters become arguments (or a user supplied filter function).
3. **Config file per project**: e.g. a `replicater.yml` at the project root read by option 2, so the master file is the same in every project.

Suggestion (to discuss): option 2, possibly with option 3 later. A fix like issue #2 is then made once in the package instead of in every copy.

## 3. Remove idiosyncrasies of my own workflow

### 3.1 `runMat` and the columns built on it

Names to change (proposals, not decided):

| Current | Where | Proposal |
|---|---|---|
| YAML field `runMat` | scripts, `rpl_list_Rfiles()` | `run_replicate`, already used by both projects |
| `has_runMat` | column | drop, or `has_run_replicate` |
| `runMat_val` | column | drop: use the `run_replicate` column itself (`NA` when missing) |
| `runMat_true_only` | argument of `rpl_run_Rfiles()` | e.g. `skip_false = TRUE`, running every script except those with `run_replicate: FALSE`, which is what both projects do by hand |
| `has_yaml` | column | e.g. `has_yaml_header` |

Things to update with the rename:

1. `intrnl_cols_need` requires `has_runMat` and `runMat_val`. That is why both master files do `mutate(has_runMat = NA, runMat_val = NA)` before writing, with the comment "fix as function is not flexible". The new column list should drop them.
2. Old reports (`999_CHECK_RUN_report.csv` in both projects, several sessions each) use the old column names; reading them must keep working, or a one off migration is needed.
3. The fake scripts in `inst/r_scripts_fake/` use `runMat` and `Author: "Matthieu"`.
4. This also settles matPkg issue #58 ("should return NA for runMat_val if has_runMat=FALSE").

### 3.2 Remove the 999 mark

1. The report name `999_CHECK_RUN_report.csv` is hard coded in `intrnl_dir_to_file()`. Proposal: a neutral default (e.g. `replication_report.csv`) plus a `report_file` argument, and fall back to the old name when it exists so the history of existing projects is not lost.
2. Package files `R/99_run_check.R` and `R/999_source.R` → e.g. `R/run_check.R` and `R/source_scripts.R`.
3. Help page title "Run-check files 999 machinery" → e.g. "Run all scripts of a project and report errors".
4. On the project side (not the package): driver names `991_`, `998_`, `999_` and the folders `code_meta_replicate` / `CODE_meta_replicate`.

## 4. Number parsing (matPkg issue #69, still applies)

`rpl_list_Rfiles()` turns `5_10_c.R` into 5.1, the same number as `5_1_a.R`, so it raises "Ambiguous numbers" and sorts `5_10` before `5_2`. Checked on 2026-10-17. Fix idea: keep the parts as integers (`5`, `10`) and order on them instead of building a decimal number.

## 5. Post errors to GitHub with the gh CLI

Source: `BRA_IndirectSuppliers_GITHUB/CODE/999_code_check_investigate_errors.R`, called at the end of the BRA 998 when the machine is `maticloud`. Also look at `/home/matifou/Dropbox/Documents/Uni/GSEM/Projects/NASS_projects/defBias_replicate/code_setup/code_meta/992_send_issue_to_github.R`, which is probably the most advanced version (there are several such files in multiple projects). What it does:

1. Reads the report and keeps the last session.
2. Builds a summary (who ran it, on which machine, number of files, run time) and a `knitr::kable()` table of the errors.
3. Finds the issue titled "Non reproducible/error-prone code" with `gh issue list`; stops if it is missing.
4. If there are errors: reopens the issue if it is closed and adds the error table as a comment (`gh issue comment --body-file`).
5. Always replaces the issue body with the latest summary (`gh issue edit --body-file`).

To turn into a package function, e.g. `rpl_report_github(report, issue_title, repo = NULL, mentions = NULL)`:

1. Remove the hard coded parts: issue title, the author to GitHub handle map (`"Matthieu" = "@MatthieuStigler"`, `"Sam" = "@sam-a-levy"`), the text "(California time)", the `CODE/999_...` path, and the `maticloud` condition (leave that to the master file).
2. Do not use `--json` (decided 2026-10-25). Keep the tab output of `gh issue list` (number, state, title, labels, updated) and match the exact title between tab characters with `fixed()`. Note: on this machine plain `gh issue view` currently fails ("Projects (classic) is being deprecated"), so avoid `gh issue view`.
3. Create the issue (`gh issue create`) instead of stopping when it does not exist.
4. Check that gh is installed (`Sys.which("gh")`) and logged in (`gh auth status`) before calling it, and use `system2()` with an argument vector rather than `paste()`. Every gh call goes through a helper that stops when the exit status is non-zero (`gh_run()` in defBias `992_send_issue_to_github.R`, decided 2026-10-25), so a failed list never looks like "no issue" and opens a duplicate.
5. The comment table uses `dat_probs` (errors cut at 2000 characters) while the rest uses `dat_probs2`; keep a single table with an optional `max_chars` argument.
6. Several issues with the same title (decided 2026-10-25, defBias `992_send_issue_to_github.R`): use the open one, and among open ones the lowest number; if none is open, the lowest closed one. Print a message listing all matches and the one used. Other duplicates are left alone, so they can be closed by hand.

## 6. Other matPkg issues to review

Issues opened on matPkg about these functions, not reviewed yet unless stated:

1. #56 "999: does not clean memory well" (internal runs).
2. #67 "999: plot save issue "Error in grid.Call.graphics", "invalid font type"".
3. #64 "bug in mat_99_list_Rfiles, see project BR_smallholder_innov_deforest".
4. #61 "mat_99_list_Rfiles: error when no yaml": no longer errors, a folder with no YAML header at all works (checked 2026-10-17).
5. #46 "clean path function, for example in999".
6. #44 "mat_99_add_info_last": now ported as `rpl_add_info_last()`.
7. #42 "999: few changes" and #25 "999 printing".
8. #49 "mat_99_check_there_update: update folder/subfolder": `mat_99_check_there_update()` was not ported.

## 7. Differences with matPkg (as of 2026-10-17)

1. Fixed in both packages: the `--vanila` typo in `source_rcmd_batch()`, and the inverted `if_else()` that left `error_parse` always `NA`.
2. replicater only: external runs check the exit status (`quit(status = 1)` was reported as success); `rpl_add_info_last()` matches on `filename` and `folder`, keeps a factor `folder` and accepts `rpl_run_Rfiles()` output.
3. Not ported: `mat_99_check_there_update()`, `mat_99_arrange_by_last()`, the deprecated wrappers and `as.data.frame.proc_time()`.
