#' Resolve the derived-indicator directory (local pipeline, Docker, or env).
derived_dir <- function() {
  env <- Sys.getenv("CYCLISTIC_DERIVED", unset = "")
  candidates <- c(
    if (nzchar(env)) env else NULL,
    "/srv/data/derived",
    tryCatch(file.path(here::here(), "data", "derived"), error = function(e) NULL),
    file.path("..", "data", "derived"),
    file.path("data", "derived")
  )
  for (p in candidates) {
    if (!is.null(p) && dir.exists(p) && file.exists(file.path(p, "member_share.csv"))) {
      return(normalizePath(p))
    }
  }
  stop(
    "Could not find data/derived/*.csv. Run `targets::tar_make()` in the project root ",
    "or set CYCLISTIC_DERIVED."
  )
}

read_indicator <- function(name, dir = derived_dir()) {
  readr::read_csv(file.path(dir, paste0(name, ".csv")), show_col_types = FALSE)
}

programme_colors <- c(Member = "#215C8C", Casual = "#C05621")

SEASON_MONTHS <- list(
  all = 1:12,
  warm = 4:10,
  cold = c(11L, 12L, 1L, 2L, 3L)
)

SEASON_CHOICES <- c(
  "All months" = "all",
  "Apr–Oct (riding season)" = "warm",
  "Nov–Mar (winter)" = "cold"
)

season_label <- function(season) {
  lab <- names(SEASON_CHOICES)[match(season, unname(SEASON_CHOICES))]
  if (length(lab) == 0 || is.na(lab)) "All months" else lab
}

as_programme <- function(x) {
  factor(ifelse(x == "member", "Member", "Casual"), levels = c("Member", "Casual"))
}

to_date <- function(ym) as.Date(paste0(ym, "-01"))

month_num <- function(ym) as.integer(substr(ym, 6, 7))

slice_period <- function(df, years, season = "all") {
  months <- SEASON_MONTHS[[season]]
  if (is.null(months)) months <- 1:12
  dplyr::filter(
    df,
    substr(.data$year_month, 1, 4) %in% years,
    month_num(.data$year_month) %in% months
  )
}

share_by_programme <- function(data, condition) {
  vals <- c(Member = NA_real_, Casual = NA_real_)
  if (is.null(data) || nrow(data) == 0) return(vals)
  out <- data |>
    dplyr::mutate(programme = as_programme(.data$member_casual)) |>
    dplyr::group_by(.data$programme) |>
    dplyr::summarise(
      value = sum(.data$n_trips[{{ condition }}]) / sum(.data$n_trips),
      .groups = "drop"
    )
  vals[as.character(out$programme)] <- out$value
  vals
}

weighted_median_duration <- function(duration_month) {
  vals <- c(Member = NA_real_, Casual = NA_real_)
  if (is.null(duration_month) || nrow(duration_month) == 0) return(vals)
  out <- duration_month |>
    dplyr::mutate(programme = as_programme(.data$member_casual)) |>
    dplyr::group_by(.data$programme) |>
    dplyr::summarise(
      med = stats::weighted.mean(.data$duration_median_min, .data$n_trips),
      .groups = "drop"
    )
  vals[as.character(out$programme)] <- out$med
  vals
}

commute_like_counts <- function(rider_profile) {
  empty <- tibble::tibble(member_casual = character(), n = integer())
  if (is.null(rider_profile) || nrow(rider_profile) == 0) return(empty)
  rider_profile |>
    dplyr::filter(
      .data$day_type == "Weekday",
      .data$time_block %in% c("AM peak", "PM peak"),
      .data$duration_band == "Under 15 min"
    ) |>
    dplyr::group_by(.data$member_casual) |>
    dplyr::summarise(n = sum(.data$n_trips), .groups = "drop")
}

collapse_duration_bins <- function(duration_bins) {
  duration_bins |>
    dplyr::mutate(
      programme = as_programme(.data$member_casual),
      duration_bin = dplyr::recode(
        as.character(.data$duration_bin),
        "1-5" = "1–10", "5-10" = "1–10",
        "10-15" = "10–20", "15-20" = "10–20",
        "20-30" = "20–30",
        "30-45" = "30–45",
        "45-60" = "45–60",
        "60-90" = "60+", "90-120" = "60+", "120+" = "60+"
      ),
      duration_bin = factor(
        .data$duration_bin,
        levels = c("1–10", "10–20", "20–30", "30–45", "45–60", "60+")
      )
    ) |>
    dplyr::group_by(.data$programme, .data$duration_bin) |>
    dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop_last") |>
    dplyr::mutate(share = .data$n_trips / sum(.data$n_trips)) |>
    dplyr::ungroup()
}

label_bike <- function(rideable_type) {
  dplyr::recode(
    rideable_type,
    electric_bike = "Electric bike",
    classic_bike = "Classic bike",
    docked_bike = "Docked bike",
    electric_scooter = "Electric scooter",
    .default = tools::toTitleCase(gsub("_", " ", rideable_type))
  )
}

exclusion_reasons <- function(quality_month) {
  drop_cols <- c("n_in", "n_kept", "n_dropped")
  reason_cols <- setdiff(
    grep("^n_", names(quality_month), value = TRUE),
    c(drop_cols, grep("station_kept$", names(quality_month), value = TRUE))
  )
  quality_month |>
    dplyr::summarise(dplyr::across(dplyr::all_of(reason_cols), sum)) |>
    tidyr::pivot_longer(dplyr::everything(), names_to = "reason", values_to = "n") |>
    dplyr::filter(.data$n > 0) |>
    dplyr::mutate(
      reason = dplyr::recode(
        .data$reason,
        n_missing_ride_id = "Missing ride id",
        n_duplicate_ride_id = "Duplicate ride id",
        n_missing_programme = "Missing member/casual flag",
        n_missing_timestamps = "Unparseable timestamp",
        n_duration_non_positive = "End before start",
        n_duration_too_short = "Under 60 seconds",
        n_duration_too_long = "Over 24 hours"
      )
    )
}

fmt_int <- function(x) {
  if (length(x) == 0 || is.na(x)) "—" else scales::label_comma()(x)
}

fmt_pct <- function(x) {
  if (length(x) == 0 || is.na(x)) "—" else scales::percent(x, accuracy = 0.1)
}

fmt_min <- function(x) {
  if (length(x) == 0 || is.na(x)) "—" else paste0(scales::number(x, accuracy = 0.1), " min")
}

fmt_trips <- function(n) {
  if (length(n) == 0 || is.na(n) || n == 0) "0"
  else if (n >= 1e6) scales::comma(n, scale = 1e-6, accuracy = 0.1, suffix = " million")
  else scales::comma(n, accuracy = 1)
}

date_axis_for <- function(dates) {
  if (length(dates) == 0 || all(is.na(dates))) {
    return(ggplot2::scale_x_date())
  }
  span <- as.numeric(diff(range(dates, na.rm = TRUE)))
  if (is.na(span) || span < 400) {
    ggplot2::scale_x_date(date_breaks = "1 month", date_labels = "%b %Y")
  } else {
    ggplot2::scale_x_date(
      date_breaks = "1 year", date_labels = "%Y",
      expand = ggplot2::expansion(mult = c(0.01, 0.01))
    )
  }
}

#' Consecutive-month groups so winter/summer filters do not draw a line
#' across the months that were dropped.
gap_group <- function(date) {
  d <- as.numeric(date)
  if (length(d) == 0) return(integer())
  cumsum(c(TRUE, diff(d) > 40))
}

theme_monitor <- function() {
  ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      legend.position = "top",
      legend.title = ggplot2::element_blank(),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      panel.grid.minor = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(6, 16, 6, 6),
      plot.caption = ggplot2::element_text(colour = "grey45", hjust = 0, size = 9),
      axis.title = ggplot2::element_text(colour = "grey30", size = ggplot2::rel(0.9))
    )
}

plot_hourly <- function(timing) {
  hourly <- timing |>
    dplyr::filter(!.data$weekday %in% c("Saturday", "Sunday")) |>
    dplyr::mutate(programme = as_programme(.data$member_casual)) |>
    dplyr::group_by(.data$programme, .data$hour) |>
    dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop_last") |>
    dplyr::mutate(share = .data$n_trips / sum(.data$n_trips)) |>
    dplyr::ungroup()

  ggplot2::ggplot(hourly, ggplot2::aes(.data$hour, .data$share, colour = .data$programme)) +
    ggplot2::annotate("rect", xmin = 6, xmax = 9, ymin = -Inf, ymax = Inf,
                      fill = "grey88", alpha = 0.55) +
    ggplot2::annotate("rect", xmin = 16, xmax = 19, ymin = -Inf, ymax = Inf,
                      fill = "grey88", alpha = 0.55) +
    ggplot2::geom_line(linewidth = 1.1) +
    ggplot2::scale_colour_manual(values = programme_colors) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 23, 3),
      labels = function(h) sprintf("%02d:00", h)
    ) +
    ggplot2::labs(
      x = "Hour the trip started", y = "Share of weekday trips",
      caption = "Shaded bands: 06–09 and 16–19."
    ) +
    theme_monitor()
}

plot_signature <- function(weekend, peak, long_trip) {
  signature <- tibble::tibble(
    metric = factor(
      c("Weekend", "Weekday commute window", "Longer than 30 minutes"),
      levels = c("Longer than 30 minutes", "Weekday commute window", "Weekend")
    ) |> rep(each = 2),
    programme = factor(rep(c("Member", "Casual"), 3), levels = c("Member", "Casual")),
    value = c(
      weekend[["Member"]], weekend[["Casual"]],
      peak[["Member"]], peak[["Casual"]],
      long_trip[["Member"]], long_trip[["Casual"]]
    )
  ) |>
    dplyr::filter(!is.na(.data$value))

  ggplot2::ggplot(signature, ggplot2::aes(.data$value, .data$metric, fill = .data$programme)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.72), width = 0.64) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(.data$value, accuracy = 1)),
      position = ggplot2::position_dodge(width = 0.72),
      hjust = -0.12, size = 3.5, colour = "grey20"
    ) +
    ggplot2::scale_fill_manual(values = programme_colors) +
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.22))
    ) +
    ggplot2::labs(x = "Share of the group's trips", y = NULL) +
    theme_monitor()
}

plot_commute_trend <- function(rider_profile) {
  commute_trend <- rider_profile |>
    dplyr::mutate(programme = as_programme(.data$member_casual)) |>
    dplyr::group_by(.data$programme, .data$year_month) |>
    dplyr::summarise(
      share = sum(
        .data$n_trips[.data$day_type == "Weekday" &
                        .data$time_block %in% c("AM peak", "PM peak") &
                        .data$duration_band == "Under 15 min"]
      ) / sum(.data$n_trips),
      .groups = "drop"
    ) |>
    dplyr::mutate(date = to_date(.data$year_month)) |>
    dplyr::arrange(.data$programme, .data$date) |>
    dplyr::group_by(.data$programme) |>
    dplyr::mutate(grp = gap_group(.data$date)) |>
    dplyr::ungroup()

  ggplot2::ggplot(commute_trend, ggplot2::aes(.data$date, .data$share, colour = .data$programme, group = interaction(.data$programme, .data$grp))) +
    ggplot2::geom_line(linewidth = 1.05) +
    ggplot2::scale_colour_manual(values = programme_colors) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, NA)) +
    date_axis_for(commute_trend$date) +
    ggplot2::labs(
      x = NULL, y = "Share of the group's trips",
      caption = "Commute-like = weekday, 06–09 or 16–19, under 15 min."
    ) +
    theme_monitor()
}

plot_duration_bins <- function(duration_bins) {
  dur_dist <- collapse_duration_bins(duration_bins)
  ggplot2::ggplot(dur_dist, ggplot2::aes(.data$duration_bin, .data$share, fill = .data$programme)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.72) +
    ggplot2::scale_fill_manual(values = programme_colors) +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.04))
    ) +
    ggplot2::labs(x = "Trip length (minutes)", y = "Share of trips") +
    theme_monitor()
}

plot_heatmap <- function(timing) {
  heat <- timing |>
    dplyr::mutate(programme = as_programme(.data$member_casual)) |>
    dplyr::group_by(.data$programme, .data$weekday, .data$hour) |>
    dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop_last") |>
    dplyr::mutate(share = .data$n_trips / sum(.data$n_trips)) |>
    dplyr::ungroup() |>
    dplyr::mutate(weekday = factor(.data$weekday, levels = rev(c(
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ))))

  ggplot2::ggplot(heat, ggplot2::aes(.data$hour, .data$weekday, fill = .data$share)) +
    ggplot2::geom_tile() +
    ggplot2::facet_wrap(~programme) +
    ggplot2::scale_fill_viridis_c(
      option = "mako", direction = -1,
      labels = scales::percent_format(accuracy = 0.1),
      name = "Share of the group's trips",
      guide = ggplot2::guide_colourbar(barwidth = 12, barheight = 0.55, title.position = "top")
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 21, 3),
      labels = function(h) sprintf("%02d", h),
      expand = c(0, 0)
    ) +
    ggplot2::scale_y_discrete(expand = c(0, 0)) +
    ggplot2::labs(x = "Hour the trip started", y = NULL) +
    theme_monitor() +
    ggplot2::theme(
      legend.title = ggplot2::element_text(colour = "grey30", size = ggplot2::rel(0.85)),
      panel.spacing = grid::unit(1.1, "lines")
    )
}

plot_volume <- function(programme_month) {
  d <- programme_month |>
    dplyr::mutate(
      programme = as_programme(.data$member_casual),
      date = to_date(.data$year_month)
    ) |>
    dplyr::arrange(.data$programme, .data$date) |>
    dplyr::group_by(.data$programme) |>
    dplyr::mutate(grp = gap_group(.data$date)) |>
    dplyr::ungroup()
  ggplot2::ggplot(d, ggplot2::aes(.data$date, .data$n_trips, colour = .data$programme, group = interaction(.data$programme, .data$grp))) +
    ggplot2::geom_line(linewidth = 1.05) +
    ggplot2::scale_colour_manual(values = programme_colors) +
    ggplot2::scale_y_continuous(labels = scales::label_number(scale = 1e-3, suffix = "k")) +
    date_axis_for(d$date) +
    ggplot2::labs(x = NULL, y = "Trips per month") +
    theme_monitor()
}

plot_member_share <- function(member_share) {
  d <- dplyr::mutate(member_share, date = to_date(.data$year_month)) |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(grp = gap_group(.data$date))
  ggplot2::ggplot(d, ggplot2::aes(.data$date, .data$member_share, group = .data$grp)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$ci_low, ymax = .data$ci_high),
      fill = "#215C8C", alpha = 0.25
    ) +
    ggplot2::geom_line(colour = "#215C8C", linewidth = 1.05) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
    date_axis_for(d$date) +
    ggplot2::labs(
      x = NULL, y = "Member share of trips",
      caption = "Ribbon: Wilson 95% interval. Share of trips, not of people."
    ) +
    theme_monitor()
}

plot_bikes <- function(bike_type) {
  bike_mix <- bike_type |>
    dplyr::mutate(
      programme = as_programme(.data$member_casual),
      bike = label_bike(.data$rideable_type)
    ) |>
    dplyr::group_by(.data$programme, .data$bike) |>
    dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop_last") |>
    dplyr::mutate(share = .data$n_trips / sum(.data$n_trips)) |>
    dplyr::ungroup()

  ggplot2::ggplot(bike_mix, ggplot2::aes(.data$share, stats::reorder(.data$bike, .data$share), fill = .data$programme)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.72), width = 0.62) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(.data$share, accuracy = 1)),
      position = ggplot2::position_dodge(width = 0.72),
      hjust = -0.12, size = 3.4, colour = "grey20"
    ) +
    ggplot2::scale_fill_manual(values = programme_colors) +
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.18))
    ) +
    ggplot2::labs(
      x = "Share of the group's trips", y = NULL,
      caption = "Classic and electric split almost evenly. Docked bikes are a casual-only leftover."
    ) +
    theme_monitor()
}

plot_quality_kept <- function(quality_month) {
  d <- dplyr::mutate(quality_month, date = to_date(.data$year_month)) |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(grp = gap_group(.data$date))
  ggplot2::ggplot(d, ggplot2::aes(.data$date, .data$pct_kept, group = .data$grp)) +
    ggplot2::geom_line(colour = "#215C8C", linewidth = 1.05) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0.9, 1)) +
    date_axis_for(d$date) +
    ggplot2::labs(x = NULL, y = "Share of source records kept") +
    theme_monitor()
}

plot_exclusions <- function(quality_month) {
  reasons <- exclusion_reasons(quality_month) |>
    dplyr::mutate(inside = .data$n > max(.data$n) * 0.45)
  ggplot2::ggplot(reasons, ggplot2::aes(.data$n, stats::reorder(.data$reason, .data$n))) +
    ggplot2::geom_col(fill = "#8C6D46", width = 0.65) +
    ggplot2::geom_text(
      ggplot2::aes(
        label = scales::comma(.data$n),
        hjust = ifelse(.data$inside, 1.12, -0.12),
        colour = ifelse(.data$inside, "white", "grey25")
      ),
      size = 3.6
    ) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_continuous(
      labels = scales::label_number(scale = 1e-3, suffix = "k"),
      expand = ggplot2::expansion(mult = c(0, 0.16))
    ) +
    ggplot2::labs(x = "Records excluded", y = NULL) +
    theme_monitor()
}
