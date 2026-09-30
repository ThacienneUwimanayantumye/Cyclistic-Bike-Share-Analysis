SELECT
  year_month,
  n_in,
  n_kept,
  n_dropped,
  n_dropped * 1.0 / NULLIF(n_in, 0) AS drop_rate,
  pct_missing_start_station
FROM quality_month
ORDER BY year_month;
