#' Wilson score interval for a binomial proportion.
#'
#' Used for member/casual *trip share* (event-level). This is not a coverage
#' estimate for unique persons.
#'
#' @param x number of successes
#' @param n number of trials
#' @param conf confidence level
#' @return tibble with estimate, ci_low, ci_high
wilson_ci <- function(x, n, conf = 0.95) {
  x <- as.numeric(x)
  n <- as.numeric(n)
  out <- tibble::tibble(
    n = n,
    x = x,
    estimate = ifelse(n > 0, x / n, NA_real_),
    ci_low = NA_real_,
    ci_high = NA_real_
  )
  ok <- is.finite(n) & n > 0 & is.finite(x) & x >= 0 & x <= n
  if (!any(ok)) {
    return(out)
  }
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- out$estimate[ok]
  nn <- n[ok]
  denom <- 1 + z^2 / nn
  centre <- (p + z^2 / (2 * nn)) / denom
  margin <- z * sqrt(p * (1 - p) / nn + z^2 / (4 * nn^2)) / denom
  out$ci_low[ok] <- pmax(0, centre - margin)
  out$ci_high[ok] <- pmin(1, centre + margin)
  out
}

#' Add Wilson intervals to a monthly programme-mix table.
add_member_share_ci <- function(monthly_counts, conf = 0.95) {
  totals <- monthly_counts |>
    dplyr::group_by(.data$year_month) |>
    dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop")
  members <- monthly_counts |>
    dplyr::filter(.data$member_casual == "member") |>
    dplyr::select("year_month", n_member = "n_trips")
  out <- dplyr::left_join(totals, members, by = "year_month") |>
    dplyr::mutate(
      n_member = dplyr::coalesce(.data$n_member, 0),
      n_casual = .data$n_trips - .data$n_member
    )
  ci <- wilson_ci(out$n_member, out$n_trips, conf = conf)
  dplyr::bind_cols(
    out,
    dplyr::select(ci, member_share = "estimate", "ci_low", "ci_high")
  )
}

#' Seasonal-trend decomposition of a monthly series.
stl_monthly <- function(df, value_col, start_year, start_month) {
  y <- df[[value_col]]
  ts_y <- stats::ts(y, start = c(start_year, start_month), frequency = 12)
  fit <- stats::stl(ts_y, s.window = "periodic", robust = TRUE)
  tibble::tibble(
    year_month = df$year_month,
    observed = as.numeric(ts_y),
    seasonal = as.numeric(fit$time.series[, "seasonal"]),
    trend = as.numeric(fit$time.series[, "trend"]),
    remainder = as.numeric(fit$time.series[, "remainder"])
  )
}

#' 2x2 association of programme vs weekend (descriptive only).
#'
#' Trips are not independent person-level observations. Pearson's chi-square
#' is reported as a descriptive contrast, not a population inference.
programme_weekend_chisq <- function(timing_counts) {
  tab <- timing_counts |>
    dplyr::mutate(
      is_weekend = .data$weekday %in% c("Saturday", "Sunday")
    ) |>
    dplyr::group_by(.data$member_casual, .data$is_weekend) |>
    dplyr::summarise(n = sum(.data$n_trips), .groups = "drop") |>
    tidyr::pivot_wider(
      names_from = "is_weekend", values_from = "n", values_fill = 0
    )
  mat <- as.matrix(tab[, c("FALSE", "TRUE"), drop = FALSE])
  rownames(mat) <- tab$member_casual
  colnames(mat) <- c("weekday", "weekend")
  test <- stats::chisq.test(mat)
  list(
    table = mat,
    statistic = unname(test$statistic),
    df = unname(test$parameter),
    p_value = unname(test$p.value),
    note = "Trips are clustered within riders; p-values are descriptive only."
  )
}
