#' List monthly Divvy zip archives in a directory.
list_month_zips <- function(raw_dir = path_raw()) {
  files <- fs::dir_ls(raw_dir, type = "file", fail = FALSE)
  files <- files[grepl(ZIP_PATTERN, basename(files))]
  sort(unname(as.character(files)))
}

csv_name_in_zip <- function(zip_path) {
  listing <- utils::unzip(zip_path, list = TRUE)
  names_in <- listing$Name
  csvs <- names_in[grepl("\\.csv$", names_in, ignore.case = TRUE)]
  csvs <- csvs[!grepl("__MACOSX", csvs)]
  csvs <- csvs[!startsWith(basename(csvs), "._")]
  if (length(csvs) != 1L) {
    stop("Expected one CSV in ", zip_path, ", found: ", paste(csvs, collapse = ", "))
  }
  csvs[[1]]
}

#' Read a monthly trip zip into a tibble (all columns as the contract types).
read_month_zip <- function(zip_path) {
  csv_name <- csv_name_in_zip(zip_path)
  td <- tempfile("divvy")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, files = csv_name, exdir = td, junkpaths = FALSE)
  f <- file.path(td, csv_name)
  if (!file.exists(f)) {
    found <- fs::dir_ls(td, recurse = TRUE, glob = "*.csv")
    found <- found[!grepl("__MACOSX", found)]
    if (length(found) != 1L) {
      stop("Could not extract CSV from ", zip_path)
    }
    f <- found[[1]]
  }
  readr::read_csv(f, col_types = trip_csv_spec(), progress = FALSE)
}

period_from_zip <- function(zip_path) {
  ym <- sub("^([0-9]{6})-.*$", "\\1", basename(zip_path))
  sprintf("%s-%s", substr(ym, 1, 4), substr(ym, 5, 6))
}
