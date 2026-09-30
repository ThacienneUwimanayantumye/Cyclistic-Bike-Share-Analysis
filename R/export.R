#' Export small derived tables for the dashboard and report.

export_derived <- function(tables, out_dir = path_derived()) {
  fs::dir_create(out_dir)
  paths <- character()
  for (nm in names(tables)) {
    path <- file.path(out_dir, paste0(nm, ".csv"))
    readr::write_csv(tables[[nm]], path)
    paths <- c(paths, path)
  }
  meta <- tibble::tibble(
    generated_at = as.character(Sys.time()),
    n_tables = length(tables),
    table_names = paste(names(tables), collapse = ",")
  )
  meta_path <- file.path(out_dir, "metadata.csv")
  readr::write_csv(meta, meta_path)
  c(paths, meta_path)
}

load_derived <- function(name, derived_dir = path_derived()) {
  path <- file.path(derived_dir, paste0(name, ".csv"))
  if (!file.exists(path)) {
    stop("Derived table not found: ", path, ". Run targets::tar_make() first.")
  }
  readr::read_csv(path, show_col_types = FALSE)
}
