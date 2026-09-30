#' Validate that a monthly extract matches the expected column contract.
validate_month <- function(df, zip_path = NA_character_) {
  missing <- setdiff(EXPECTED_COLUMNS, names(df))
  extra <- setdiff(names(df), EXPECTED_COLUMNS)
  problems <- character()
  if (length(missing)) {
    problems <- c(problems, paste("missing columns:", paste(missing, collapse = ", ")))
  }
  if (nrow(df) == 0L) {
    problems <- c(problems, "zero rows")
  }
  tibble::tibble(
    source_file = basename(zip_path),
    n_rows = nrow(df),
    n_cols = ncol(df),
    extra_columns = if (length(extra)) paste(extra, collapse = ",") else NA_character_,
    ok = length(problems) == 0L,
    problems = if (length(problems)) paste(problems, collapse = "; ") else NA_character_
  )
}
