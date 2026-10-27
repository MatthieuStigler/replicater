## write a fake R script, with YAML header lines `yaml` (NULL for no header)
write_script <- function(dir, name, code = "1+1", yaml = "run_replicate: TRUE") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  header <- if(is.null(yaml)) NULL else c("#' ---", paste("#'", yaml), "#' ---")
  writeLines(c(header, code), file.path(dir, name))
}

## new empty temp dir
new_dir <- function() {
  dir <- tempfile("rpl_test_")
  dir.create(dir)
  dir
}
