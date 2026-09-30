# Cyclistic Programme Monitor

Reproducible **R pipeline**, **SQL-backed indicators**, and **Shiny dashboard** for monitoring how annual members and casual riders use Chicago’s Cyclistic / Divvy system (2021–2025).

This repository is a **portfolio data product**: the domain is bike-share; the engineering matches programme-monitoring work (quality rules, indicator dictionary, partitioned processing, dashboard on aggregates). It is not a cancer-screening analysis.

## Why this exists

Finnish Cancer Registry / EUCanScreen-style work needs people who can:

- turn messy longitudinal files into a **maintainable pipeline**
- publish **documented indicators** (numerator, denominator, exclusions)
- put **data quality** next to the headline numbers
- ship a **dashboard** that never loads microdata
- keep the work **reproducible** (lockfile, tests, Docker, Git)

That is what this repo is built to demonstrate, using public Divvy trip files.

## Architecture

```
data/raw/*.zip          (gitignored monthly extracts)
        │
        ▼
  {targets} pipeline    ingest → validate → clean → indicators
        │
        ├─ DuckDB        data/processed/cyclistic_indicators.duckdb
        ├─ SQL           inst/sql/*.sql
        ├─ derived CSV   data/derived/*.csv          ← dashboard + report
        └─ quality table drop reasons by month
```

Each month is processed with the same function; only summaries are stacked. Raw trips never enter Shiny.

## Indicators (short)

| Indicator | Grain | Note |
|---|---|---|
| Trip volume | month × programme | Event counts, not unique people |
| Member trip share | month | Wilson 95% interval |
| Timing | weekday × hour | Commute vs weekend leisure |
| Duration | month × programme | **Median** and IQR, not mean-only |
| Bike type | month × programme × type | Classic / electric / docked |
| Quality | month | Drop rate and missing stations |

Full specification: [`docs/METHODS.md`](docs/METHODS.md).

**Hard limitation:** there is no rider id. Member share is a share of *trips*. Interpreting it as coverage of persons would be a statistical error; the methods page says so explicitly.

## How to run

### 1. Data

Place `YYYYMM-divvy-tripdata.zip` files (2021-01 through 2025-12) in `data/raw/`. Source: [divvy-tripdata](https://divvy-tripdata.s3.amazonaws.com/index.html).

### 2. Pipeline

```r
install.packages(c("targets", "tarchetypes", "tidyverse", "duckdb", "DBI",
                   "shiny", "bslib", "bsicons", "here", "testthat", "markdown"))
targets::tar_make()
```

Or: `Rscript scripts/run_pipeline.R`

### 3. Dashboard

```r
shiny::runApp("dashboard")
```

Or: `Rscript scripts/run_dashboard.R`

### 4. Tests

```r
testthat::test_dir("tests/testthat")
```

### 5. Methods report

```bash
quarto render analysis/report.qmd
```

### Docker (dashboard on derived tables)

```bash
docker build -t cyclistic-monitor .
docker run --rm -p 3838:3838 cyclistic-monitor
```

## Repository map

| Path | Role |
|---|---|
| `R/` | Pipeline functions (ingest, validate, clean, indicators, SQL, stats) |
| `_targets.R` | Orchestration graph |
| `inst/sql/` | DuckDB queries on indicator tables |
| `data/derived/` | Published aggregates for the app and report |
| `dashboard/` | Shiny monitoring app |
| `docs/METHODS.md` | Indicator dictionary |
| `analysis/report.qmd` | Quarto methods + findings |
| `tests/` | Unit tests on cleaning rules and Wilson intervals |
| `AI.md` | How agentic AI was used on this repo |

## Statistical stance

- Wilson intervals on trip shares  
- STL seasonal-trend split of monthly volume  
- Chi-square on programme × weekend **labelled as descriptive** (trips are clustered)  
- No fake epidemiology (no incidence, no person-years, no “screening coverage”)

## License and data

Code: MIT. Trip data remain subject to Motivate’s license and are not redistributed in git as raw zips.
