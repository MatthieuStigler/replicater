#' ---
#' Title: "Heavy code"
#' Author: "Jane Doe"
#' Date: 2019-03-11
#' run_replicate: FALSE
#' ---


################################
#'## Read data
################################

heavy_vec <- rnorm(20000000, mean = 1)
# heavy_vec <- rnorm(10000000, mean = 1)
lobstr::obj_size(heavy_vec)
mean(heavy_vec)

