source_all_r <- function() {
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  r_files <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
  for (f in r_files) sys.source(f, envir = globalenv())
}

source_all_r()

test_that("Wilson interval is centred on the sample proportion", {
  ci <- wilson_ci(50, 100)
  expect_equal(ci$estimate, 0.5)
  expect_lt(ci$ci_low, 0.5)
  expect_gt(ci$ci_high, 0.5)
  expect_gte(ci$ci_low, 0)
  expect_lte(ci$ci_high, 1)
})

test_that("Wilson interval handles n = 0", {
  ci <- wilson_ci(0, 0)
  expect_true(is.na(ci$estimate))
})

test_that("schema validation fails on missing columns", {
  df <- tibble::tibble(ride_id = "x")
  v <- validate_month(df, "dummy.zip")
  expect_false(v$ok)
  expect_match(v$problems, "missing columns")
})

test_that("clean_month drops quality failures and keeps valid trips", {
  raw <- readr::read_csv(
    testthat::test_path("fixtures", "tiny_month.csv"),
    col_types = trip_csv_spec(),
    progress = FALSE
  )
  cleaned <- clean_month(raw, "2021-01")
  expect_equal(cleaned$quality$n_in, nrow(raw))
  expect_equal(cleaned$quality$n_kept, 3L)
  expect_setequal(cleaned$kept$ride_id, c("KEEP001", "KEEP002", "KEEP003"))
  expect_true("KEEP002" %in% cleaned$kept$ride_id)
  expect_true(any(cleaned$kept$missing_start_station))
  expect_equal(
    cleaned$kept$member_casual[cleaned$kept$ride_id == "KEEP003"],
    "member"
  )
  expect_equal(cleaned$quality$n_duration_too_short, 1)
  expect_equal(cleaned$quality$n_duration_non_positive, 1)
  expect_equal(cleaned$quality$n_duration_too_long, 1)
  expect_equal(cleaned$quality$n_missing_programme, 1)
  expect_equal(cleaned$quality$n_missing_ride_id, 1)
})

test_that("rider_profile classifies day type, time block and duration band", {
  kept <- tibble::tibble(
    year_month = "2021-01",
    member_casual = c("member", "member", "casual", "casual"),
    weekday = c("Tuesday", "Saturday", "Tuesday", "Sunday"),
    hour = c(8L, 13L, 17L, 22L),
    duration_min = c(9, 40, 12, 20)
  )
  out <- summarise_rider_profile(kept)

  expect_equal(sum(out$n_trips), nrow(kept))
  expect_setequal(as.character(out$day_type), c("Weekday", "Weekend"))

  commute <- dplyr::filter(
    out,
    day_type == "Weekday",
    time_block %in% c("AM peak", "PM peak"),
    duration_band == "Under 15 min"
  )
  expect_equal(sum(commute$n_trips), 2L)
  expect_setequal(commute$member_casual, c("member", "casual"))

  # Saturday 13:00 / 40 min and Sunday 22:00 / 20 min are the two weekend rows.
  weekend <- dplyr::arrange(dplyr::filter(out, day_type == "Weekend"), member_casual)
  expect_equal(as.character(weekend$time_block), c("Off-peak", "Midday"))
  expect_equal(as.character(weekend$duration_band), c("15-30 min", "Over 30 min"))
})

test_that("period_from_zip parses Divvy filenames", {
  expect_equal(period_from_zip("data/raw/202105-divvy-tripdata.zip"), "2021-05")
})

test_that("member share CI aggregates monthly counts", {
  counts <- tibble::tibble(
    year_month = c("2021-01", "2021-01", "2021-02", "2021-02"),
    member_casual = c("member", "casual", "member", "casual"),
    n_trips = c(80, 20, 70, 30)
  )
  share <- add_member_share_ci(counts)
  expect_equal(share$member_share[share$year_month == "2021-01"], 0.8)
  expect_equal(nrow(share), 2)
})
