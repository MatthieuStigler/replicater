test_that("intrnl_time_format formats durations", {
  expect_equal(intrnl_time_format_vec(c(0.5, 30, 150, 600, 3900)),
               c("<1 Sec", "<1 Min", "2.5 Min", "10 Min", "1:05 Hour"))
  expect_equal(intrnl_time_format(NA), NA_character_)
  expect_equal(intrnl_time_format(as.difftime(2, units = "mins")), "2 Min")
})

test_that("intrnl_bytes_to_num and intrnl_bytes_to_chr convert units", {
  expect_equal(intrnl_bytes_to_num(2e6, unit = "MB"), 2)
  expect_equal(intrnl_bytes_to_chr(2e6, unit = "MB"), "2 MB")
  expect_equal(intrnl_bytes_to_chr(2e9), "2 GB")
})

test_that("intrnl_err_to_chr cuts character errors at the backtrace", {
  expect_equal(intrnl_err_to_chr(c("Error: oops", "more", "Backtrace:", "x")), "Error: oops more")
  expect_match(intrnl_err_to_chr(simpleError("oops")), "oops")
})

test_that("rpl_enframe_wide makes a one row tibble", {
  out <- rpl_enframe_wide(c(1, 2), names = c("a", "b"))
  expect_equal(out, tibble::tibble(a = 1, b = 2))
  expect_equal(colnames(rpl_enframe_wide(c(1, 2))), c("col_1", "col_2"))
})
