SELECT
  year_month,
  SUM(n_trips) AS n_trips,
  SUM(CASE WHEN member_casual = 'member' THEN n_trips ELSE 0 END) AS n_member,
  SUM(CASE WHEN member_casual = 'casual' THEN n_trips ELSE 0 END) AS n_casual,
  SUM(CASE WHEN member_casual = 'member' THEN n_trips ELSE 0 END) * 1.0
    / NULLIF(SUM(n_trips), 0) AS member_share
FROM programme_month
GROUP BY year_month
ORDER BY year_month;
