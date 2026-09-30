library(testthat)
root <- normalizePath("..")
Sys.setenv(TESTTHAT_pkg = "cyclisticmonitor")
testthat::test_dir(
  file.path(root, "tests", "testthat"),
  stop_on_failure = TRUE
)
