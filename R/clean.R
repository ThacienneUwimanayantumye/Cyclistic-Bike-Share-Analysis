#' Parse Divvy timestamps that mix `YYYY-MM-DD HH:MM:SS` and fractional seconds.
parse_trip_time <- function(x) {
  suppressWarnings(lubridate::ymd_hms(x, quiet = TRUE, truncated = 3))
}

normalise_programme <- function(x) {
  x <- trimws(tolower(as.character(x)))
  dplyr::case_when(
    x %in% c("member", "subscriber") ~ "member",
    x %in% c("casual", "customer") ~ "casual",
    TRUE ~ NA_character_
  )
}

normalise_bike_type <- function(x) {
  x <- trimws(tolower(as.character(x)))
  dplyr::case_when(
    x %in% c("classic_bike", "classic") ~ "classic_bike",
    x %in% c("electric_bike", "electric", "ebike") ~ "electric_bike",
    x %in% c("docked_bike", "docked") ~ "docked_bike",
    x %in% c("electric_scooter", "scooter") ~ "electric_scooter",
    is.na(x) | x == "" ~ NA_character_,
    TRUE ~ "other"
  )
}

#' Clean one monthly extract and attach exclusion reasons.
#'
#' Records that fail hard rules are dropped from the analytic extract but
#' counted in the quality table. Missing station names are *not* a drop
#' reason: dockless / GPS-only electric trips are valid events.
clean_month <- function(df, year_month) {
  raw_n <- nrow(df)
  out <- df |>
    dplyr::mutate(
      year_month = year_month,
      ride_id = trimws(.data$ride_id),
      member_casual = normalise_programme(.data$member_casual),
      rideable_type = normalise_bike_type(.data$rideable_type),
      started_at = parse_trip_time(.data$started_at),
      ended_at = parse_trip_time(.data$ended_at),
      duration_sec = as.numeric(difftime(.data$ended_at, .data$started_at, units = "secs")),
      missing_ride_id = is.na(.data$ride_id) | .data$ride_id == "",
      missing_programme = is.na(.data$member_casual),
      missing_timestamps = is.na(.data$started_at) | is.na(.data$ended_at),
      duration_non_positive = !is.na(.data$duration_sec) & .data$duration_sec <= 0,
      duration_too_short = !is.na(.data$duration_sec) & .data$duration_sec > 0 &
        .data$duration_sec < DURATION_MIN_SEC,
      duration_too_long = !is.na(.data$duration_sec) & .data$duration_sec > DURATION_MAX_SEC
    )

  dup <- duplicated(out$ride_id) & !out$missing_ride_id
  out$duplicate_ride_id <- dup

  out$drop_reason <- dplyr::case_when(
    out$missing_ride_id ~ "missing_ride_id",
    out$duplicate_ride_id ~ "duplicate_ride_id",
    out$missing_programme ~ "missing_programme",
    out$missing_timestamps ~ "missing_timestamps",
    out$duration_non_positive ~ "duration_non_positive",
    out$duration_too_short ~ "duration_too_short",
    out$duration_too_long ~ "duration_too_long",
    TRUE ~ NA_character_
  )

  kept <- out |>
    dplyr::filter(is.na(.data$drop_reason)) |>
    dplyr::mutate(
      weekday = factor(
        WEEKDAY_LEVELS[as.POSIXlt(.data$started_at)$wday + 1L],
        levels = WEEKDAY_LEVELS
      ),
      hour = as.integer(lubridate::hour(.data$started_at)),
      is_weekend = .data$weekday %in% c("Saturday", "Sunday"),
      missing_start_station = is.na(.data$start_station_name) | .data$start_station_name == "",
      missing_end_station = is.na(.data$end_station_name) | .data$end_station_name == "",
      duration_min = .data$duration_sec / 60
    )

  quality <- tibble::tibble(
    year_month = year_month,
    n_in = raw_n,
    n_kept = nrow(kept),
    n_dropped = raw_n - nrow(kept),
    n_missing_ride_id = sum(out$drop_reason == "missing_ride_id", na.rm = TRUE),
    n_duplicate_ride_id = sum(out$drop_reason == "duplicate_ride_id", na.rm = TRUE),
    n_missing_programme = sum(out$drop_reason == "missing_programme", na.rm = TRUE),
    n_missing_timestamps = sum(out$drop_reason == "missing_timestamps", na.rm = TRUE),
    n_duration_non_positive = sum(out$drop_reason == "duration_non_positive", na.rm = TRUE),
    n_duration_too_short = sum(out$drop_reason == "duration_too_short", na.rm = TRUE),
    n_duration_too_long = sum(out$drop_reason == "duration_too_long", na.rm = TRUE),
    n_missing_start_station_kept = sum(kept$missing_start_station),
    n_missing_end_station_kept = sum(kept$missing_end_station),
    pct_kept = ifelse(raw_n > 0, n_kept / n_in, NA_real_),
    pct_missing_start_station = ifelse(n_kept > 0, n_missing_start_station_kept / n_kept, NA_real_)
  )

  list(kept = kept, quality = quality, n_in = raw_n)
}
