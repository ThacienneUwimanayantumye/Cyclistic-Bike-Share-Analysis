SELECT
  member_casual,
  SUM(n_trips) AS n_trips,
  SUM(duration_median_min * n_trips) / NULLIF(SUM(n_trips), 0) AS duration_median_min_weighted,
  MIN(duration_p25_min) AS min_of_monthly_p25,
  MAX(duration_p75_min) AS max_of_monthly_p75
FROM duration_month
GROUP BY member_casual
ORDER BY member_casual;
