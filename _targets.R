library(targets)
library(tarchetypes)

tar_option_set(
  packages = c(
    "cli", "dplyr", "fs", "glue", "lubridate", "purrr", "readr",
    "stringr", "tibble", "tidyr", "DBI", "duckdb"
  ),
  memory = "transient",
  garbage_collection = TRUE,
  error = "stop"
)

tar_source("R")

list(
  tar_files(
    zip_files,
    list_month_zips(path_raw())
  ),
  tar_target(
    month_result,
    process_month_zip(zip_files),
    pattern = map(zip_files),
    iteration = "list"
  ),
  tar_target(programme_month, bind_month_outputs(month_result, "programme_month")),
  tar_target(quality_month, bind_month_outputs(month_result, "quality")),
  tar_target(timing, bind_month_outputs(month_result, "timing")),
  tar_target(duration_month, bind_month_outputs(month_result, "duration")),
  tar_target(bike_type, bind_month_outputs(month_result, "bike_type")),
  tar_target(duration_bins, bind_month_outputs(month_result, "duration_bins")),
  tar_target(member_share, add_member_share_ci(programme_month)),
  tar_target(
    volume_stl,
    {
      vol <- programme_month |>
        dplyr::group_by(.data$year_month) |>
        dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop") |>
        dplyr::arrange(.data$year_month)
      start_ym <- vol$year_month[[1]]
      stl_monthly(
        vol,
        "n_trips",
        as.integer(substr(start_ym, 1, 4)),
        as.integer(substr(start_ym, 6, 7))
      )
    }
  ),
  tar_target(
    chisq_weekend,
    {
      x <- programme_weekend_chisq(timing)
      tibble::tibble(
        statistic = unname(x$statistic),
        df = unname(x$df),
        p_value = unname(x$p_value),
        note = x$note,
        n_member_weekday = x$table["member", "weekday"],
        n_member_weekend = x$table["member", "weekend"],
        n_casual_weekday = x$table["casual", "weekday"],
        n_casual_weekend = x$table["casual", "weekend"]
      )
    }
  ),
  tar_target(
    duckdb_file,
    write_indicator_db(list(
      programme_month = programme_month,
      duration_month = duration_month,
      quality_month = quality_month,
      member_share = member_share
    )),
    format = "file"
  ),
  tar_target(
    sql_member_share,
    query_indicator_db(read_sql_file("member_share_by_month.sql"), duckdb_file)
  ),
  tar_target(
    sql_duration,
    query_indicator_db(read_sql_file("duration_by_programme.sql"), duckdb_file)
  ),
  tar_target(
    sql_quality,
    query_indicator_db(read_sql_file("quality_by_month.sql"), duckdb_file)
  ),
  tar_target(
    derived_files,
    export_derived(list(
      programme_month = programme_month,
      quality_month = quality_month,
      timing = timing,
      duration_month = duration_month,
      bike_type = bike_type,
      duration_bins = duration_bins,
      member_share = member_share,
      volume_stl = volume_stl,
      chisq_weekend = chisq_weekend,
      sql_member_share = sql_member_share,
      sql_duration = sql_duration,
      sql_quality = sql_quality
    )),
    format = "file"
  )
)
