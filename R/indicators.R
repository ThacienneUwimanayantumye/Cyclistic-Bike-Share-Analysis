#' Month-level indicator tables (the published data product).
#'
#' These are event-level (trips), not person-level (unique riders).

summarise_programme_month <- function(kept) {
  kept |>
    dplyr::count(.data$year_month, .data$member_casual, name = "n_trips")
}

summarise_timing <- function(kept) {
  kept |>
    dplyr::count(
      .data$year_month, .data$member_casual, .data$weekday, .data$hour,
      name = "n_trips"
    )
}

summarise_duration <- function(kept) {
  kept |>
    dplyr::group_by(.data$year_month, .data$member_casual) |>
    dplyr::summarise(
      n_trips = dplyr::n(),
      duration_mean_min = mean(.data$duration_min),
      duration_median_min = stats::median(.data$duration_min),
      duration_p25_min = stats::quantile(.data$duration_min, 0.25, names = FALSE),
      duration_p75_min = stats::quantile(.data$duration_min, 0.75, names = FALSE),
      .groups = "drop"
    )
}

summarise_bike_type <- function(kept) {
  kept |>
    dplyr::count(
      .data$year_month, .data$member_casual, .data$rideable_type,
      name = "n_trips"
    )
}

#' Histogram bins of duration (minutes) for dashboard distributions.
summarise_duration_bins <- function(kept, breaks = c(1, 5, 10, 15, 20, 30, 45, 60, 90, 120, Inf)) {
  labels <- c(
    "1-5", "5-10", "10-15", "15-20", "20-30", "30-45", "45-60", "60-90", "90-120", "120+"
  )
  kept |>
    dplyr::mutate(
      duration_bin = cut(
        .data$duration_min,
        breaks = breaks,
        labels = labels,
        include.lowest = TRUE,
        right = FALSE
      )
    ) |>
    dplyr::count(.data$year_month, .data$member_casual, .data$duration_bin, name = "n_trips")
}

#' Process one monthly zip into indicator slices (raw trips are not retained).
process_month_zip <- function(zip_path) {
  year_month <- period_from_zip(zip_path)
  cli::cli_inform("Processing {basename(zip_path)}")
  raw <- read_month_zip(zip_path)
  validation <- validate_month(raw, zip_path)
  if (!isTRUE(validation$ok[[1]])) {
    stop("Schema validation failed for ", zip_path, ": ", validation$problems[[1]])
  }
  cleaned <- clean_month(raw, year_month)
  list(
    year_month = year_month,
    source_file = basename(zip_path),
    validation = validation,
    quality = cleaned$quality,
    programme_month = summarise_programme_month(cleaned$kept),
    timing = summarise_timing(cleaned$kept),
    duration = summarise_duration(cleaned$kept),
    bike_type = summarise_bike_type(cleaned$kept),
    duration_bins = summarise_duration_bins(cleaned$kept)
  )
}

bind_month_outputs <- function(month_list, element) {
  purrr::map_dfr(month_list, element)
}
