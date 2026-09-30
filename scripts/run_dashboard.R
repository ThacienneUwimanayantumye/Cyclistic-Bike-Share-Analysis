#!/usr/bin/env Rscript
root <- normalizePath(file.path(".."), mustWork = FALSE)
if (file.exists("dashboard/app.R")) {
  app_dir <- "dashboard"
} else if (file.exists("app.R")) {
  app_dir <- "."
} else {
  app_dir <- file.path("..", "dashboard")
}
message("Starting dashboard at ", normalizePath(app_dir))
shiny::runApp(app_dir, launch.browser = TRUE)
