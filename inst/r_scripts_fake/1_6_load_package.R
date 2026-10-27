#' ---
#' Title: "Load a apackage"
#' Author: "Jane Doe"
#' Date: 2019-03-11
#' run_replicate: TRUE
#' ---


################################
#'## Read data
################################

library(plyr)
df <- rename(iris, c("disp" = "Sepal.Length"))
