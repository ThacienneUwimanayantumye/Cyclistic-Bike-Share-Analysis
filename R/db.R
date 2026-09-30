#' DuckDB helpers: persist indicator tables and run packaged SQL.

duckdb_path <- function() {
  file.path(path_processed(), "cyclistic_indicators.duckdb")
}

write_indicator_db <- function(tables, db_file = duckdb_path()) {
  fs::dir_create(dirname(db_file))
  if (file.exists(db_file)) {
    unlink(db_file)
  }
  wal <- paste0(db_file, ".wal")
  if (file.exists(wal)) unlink(wal)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_file)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  purrr::iwalk(tables, function(df, name) {
    DBI::dbWriteTable(con, name, df, overwrite = TRUE)
  })
  db_file
}

read_sql_file <- function(filename) {
  paste(readLines(file.path(path_sql(), filename), warn = FALSE), collapse = "\n")
}

query_indicator_db <- function(sql, db_file = duckdb_path()) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_file, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  tibble::as_tibble(DBI::dbGetQuery(con, sql))
}
