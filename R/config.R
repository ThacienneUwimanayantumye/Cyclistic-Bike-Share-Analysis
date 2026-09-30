#' Project paths and analysis constants.
#'
#' Trip-level Divvy files are treated as a *programme monitoring* extract:
#' each ride is an event, not a person. Duration caps follow a documented
#' quality protocol rather than ad-hoc filters.

project_root <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    tryCatch(here::here(), error = function(e) getwd())
  } else {
    getwd()
  }
}

path_raw <- function() file.path(project_root(), "data", "raw")
path_processed <- function() file.path(project_root(), "data", "processed")
path_derived <- function() file.path(project_root(), "data", "derived")
path_sql <- function() file.path(project_root(), "inst", "sql")

EXPECTED_COLUMNS <- c(
  "ride_id", "rideable_type", "started_at", "ended_at",
  "start_station_name", "start_station_id", "end_station_name", "end_station_id",
  "start_lat", "start_lng", "end_lat", "end_lng", "member_casual"
)

PROGRAMME_LEVELS <- c("member", "casual")

WEEKDAY_LEVELS <- c(
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
)

#' Minimum ride length kept in the analytic extract (seconds).
#' Sub-minute records are treated as false starts / dock glitches.
DURATION_MIN_SEC <- 60L

#' Maximum ride length kept in the analytic extract (seconds).
#' 24 hours matches a typical "not returned" quality rule.
DURATION_MAX_SEC <- 24L * 3600L

ZIP_PATTERN <- "^20[0-9]{4}-divvy-tripdata\\.zip$"

trip_csv_spec <- function() {
  readr::cols(
    ride_id = readr::col_character(),
    rideable_type = readr::col_character(),
    started_at = readr::col_character(),
    ended_at = readr::col_character(),
    start_station_name = readr::col_character(),
    start_station_id = readr::col_character(),
    end_station_name = readr::col_character(),
    end_station_id = readr::col_character(),
    start_lat = readr::col_double(),
    start_lng = readr::col_double(),
    end_lat = readr::col_double(),
    end_lng = readr::col_double(),
    member_casual = readr::col_character()
  )
}
