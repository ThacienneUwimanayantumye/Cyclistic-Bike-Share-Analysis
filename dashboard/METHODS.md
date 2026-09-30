# Indicator dictionary and methods

This document is the specification for **Cyclistic Programme Monitor**. Indicators are defined the way a screening-statistics team would specify a published table: numerator, denominator, grain, and exclusions.

The domain is Chicago Divvy / Cyclistic bike-share (2021–2025). The *product design* (pipeline → quality report → indicator store → dashboard) is what is meant to transfer to public-health monitoring work. This is **not** a cancer-screening analysis.

## Unit of analysis

| Item | Definition |
|---|---|
| Event | One trip (`ride_id`) |
| Programme | `member` (annual membership) or `casual` (single-ride / day pass) |
| Period | Calendar month `YYYY-MM` of `started_at` |
| Person | **Not observed.** Files contain no rider identifier. Do not interpret trip counts as unique participants or coverage. |

## Source

Public monthly archives from [divvy-tripdata](https://divvy-tripdata.s3.amazonaws.com/index.html), Motivate International Inc., under the [Divvy data license](https://divvybikes.com/data-license-agreement).

Local path: `data/raw/YYYYMM-divvy-tripdata.zip` (not in git).

## Column contract

Expected fields: `ride_id`, `rideable_type`, `started_at`, `ended_at`, station names/ids, start/end coordinates, `member_casual`.

A month that is missing a contract column **fails the pipeline**. Extra columns are allowed and ignored.

Historical labels `Subscriber` / `Customer` are mapped to `member` / `casual`.

## Exclusions (hard rules)

A trip is dropped from the analytic extract if any of the following hold. Counts of each reason are published in `quality_month`.

| Code | Rule |
|---|---|
| `missing_ride_id` | Empty ride id |
| `duplicate_ride_id` | Duplicate id within the month (first copy kept) |
| `missing_programme` | Programme not member/casual after recode |
| `missing_timestamps` | `started_at` or `ended_at` unparseable |
| `duration_non_positive` | End ≤ start |
| `duration_too_short` | 0 < duration < 60 seconds (false start / glitch) |
| `duration_too_long` | Duration > 24 hours (likely not returned) |

**Not an exclusion:** missing station name or id. Dockless electric trips often have GPS-only locations. Missing start station among *kept* trips is a quality indicator, not a drop rule.

## Indicators

### 1. Monthly programme volume

- **Name:** `programme_month`
- **Grain:** month × programme
- **Numerator:** count of kept trips
- **Denominator:** none (count)

### 2. Member trip share

- **Name:** `member_share`
- **Grain:** month
- **Numerator:** kept trips with programme = member
- **Denominator:** all kept trips in the month
- **Uncertainty:** Wilson score 95% interval for a binomial proportion
- **Caveat:** event-level; clustered within unobserved riders

### 3. Timing (weekday × hour)

- **Name:** `timing`
- **Grain:** month × programme × weekday × hour of `started_at`
- **Use:** commute vs leisure pattern monitoring

### 4. Duration

- **Name:** `duration_month`
- **Grain:** month × programme
- **Statistics:** mean, median, 25th and 75th percentiles of duration in minutes, after exclusions
- **Primary reported statistic:** median (mean is retained but not treated as the headline)

### 5. Bike type mix

- **Name:** `bike_type`
- **Grain:** month × programme × `rideable_type` (`classic_bike`, `electric_bike`, `docked_bike`, `electric_scooter`, `other`)

### 6. Quality

- **Name:** `quality_month`
- **Grain:** month
- **Metrics:** n in, n kept, n dropped by reason, share of kept trips with missing start station

## Statistical methods

1. **Wilson score interval** on member trip share (not a normal approximation; better near 0/1).
2. **STL** (periodic seasonal window, robust) on the monthly total trip series, to separate seasonality from trend.
3. **Pearson chi-square** on a 2×2 table of programme × weekend, computed from *trip counts*. This is a descriptive contrast. Trips are not independent people; p-values must not be read as evidence about a super-population of riders.

No person-level epidemiological measures (coverage, incidence, interval detection) are computed, because the keys do not exist.

## Pipeline architecture

Monthly zip files are processed independently (same code, local file). Only indicator tables are combined. Raw microdata are not loaded into the dashboard. That partition-then-aggregate pattern is the analogue of sharing summary tables rather than pooled records.

Storage:

- DuckDB: `data/processed/cyclistic_indicators.duckdb` (gitignored)
- Dashboard inputs: `data/derived/*.csv`
- SQL used for selected summaries: `inst/sql/`

Orchestration: `{targets}` (`_targets.R`).

## Re-running

```r
targets::tar_make()
shiny::runApp("dashboard")
```

See the repository README for Docker and tests.
