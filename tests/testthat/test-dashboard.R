test_that("slice_period keeps the requested years and season months", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  df <- tibble::tibble(
    year_month = c("2021-01", "2021-07", "2022-01", "2022-07"),
    n_trips = 1:4
  )

  winter_2021 <- slice_period(df, "2021", "cold")
  expect_equal(winter_2021$year_month, "2021-01")

  warm <- slice_period(df, c("2021", "2022"), "warm")
  expect_equal(warm$year_month, c("2021-07", "2022-07"))
})

test_that("programme_mix is the share of all trips, not weekend trips", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  share <- tibble::tibble(
    year_month = c("2021-01", "2021-02"),
    n_member = c(70, 30),
    n_casual = c(20, 80)
  )
  mix <- programme_mix(share)
  expect_equal(mix$n, 200)
  expect_equal(mix$share_member, 0.5)
  expect_equal(mix$share_casual, 0.5)
})

test_that("calendar_month_profile is a seasonal shape, not a 60-month series", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  df <- tibble::tibble(
    year_month = c("2021-01", "2021-07", "2022-01", "2022-07"),
    member_casual = c("member", "member", "casual", "casual"),
    n_trips = c(10, 90, 20, 80)
  )
  profile <- calendar_month_profile(df)
  member <- profile[profile$programme == "Member", ]
  expect_equal(as.character(member$month[member$month %in% c("Jan", "Jul")]), c("Jan", "Jul"))
  expect_equal(member$share[member$month == "Jan"], 0.1)
  expect_equal(member$share[member$month == "Jul"], 0.9)

  mix <- calendar_month_mix(df)
  jan <- mix[mix$month == "Jan", ]
  expect_equal(jan$share[jan$programme == "Member"], 10 / 30)
  expect_equal(jan$share[jan$programme == "Casual"], 20 / 30)
})

test_that("commute_like_by_month pools counts, not monthly shares", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  df <- tibble::tibble(
    year_month = c("2021-01", "2021-07", "2022-01", "2021-01"),
    member_casual = c("casual", "casual", "casual", "casual"),
    day_type = c("Weekday", "Weekday", "Weekday", "Weekend"),
    time_block = c("AM peak", "PM peak", "AM peak", "AM peak"),
    duration_band = c("Under 15 min", "Under 15 min", "Under 15 min", "Under 15 min"),
    n_trips = c(10, 90, 5, 400)
  )
  out <- commute_like_by_month(df)
  jan <- out$n_trips[out$month == "Jan" & out$programme == "Casual"]
  jul <- out$n_trips[out$month == "Jul" & out$programme == "Casual"]
  expect_equal(jan, 15)
  expect_equal(jul, 90)
})

test_that("share_by_programme returns member and casual shares", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  timing <- tibble::tibble(
    member_casual = c("member", "member", "casual", "casual"),
    weekday = c("Monday", "Saturday", "Monday", "Sunday"),
    n_trips = c(80, 20, 50, 50)
  )

  weekend <- share_by_programme(timing, weekday %in% c("Saturday", "Sunday"))
  expect_equal(unname(weekend[["Member"]]), 0.2)
  expect_equal(unname(weekend[["Casual"]]), 0.5)
})

test_that("gap_group breaks a winter-filtered series at the summer hole", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  dates <- as.Date(c("2021-01-01", "2021-02-01", "2021-03-01", "2021-11-01", "2021-12-01"))
  expect_equal(gap_group(dates), c(1, 1, 1, 2, 2))
})

test_that("collapse_duration_bins groups the long tail into 60+", {
  src <- file.path(testthat::test_path(), "..", "..", "dashboard", "helpers.R")
  sys.source(src, envir = environment())

  bins <- tibble::tibble(
    member_casual = "member",
    duration_bin = c("1-5", "5-10", "60-90", "120+"),
    n_trips = c(40, 40, 10, 10)
  )
  out <- collapse_duration_bins(bins)
  expect_equal(out$share[out$duration_bin == "1–10"], 0.8)
  expect_equal(out$share[out$duration_bin == "60+"], 0.2)
})
