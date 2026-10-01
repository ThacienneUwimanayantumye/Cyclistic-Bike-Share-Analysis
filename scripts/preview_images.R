# Generate README preview images from derived indicator tables.
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(scales)
})

root <- if (requireNamespace("here", quietly = TRUE)) here::here() else getwd()
derived <- file.path(root, "data", "derived")
img_dir <- file.path(root, "docs", "images")
dir.create(img_dir, recursive = TRUE, showWarnings = FALSE)

pal <- c(Member = "#215C8C", Casual = "#C05621")
theme_set(
  theme_minimal(base_size = 14) +
    theme(
      legend.position = "top",
      legend.title = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(colour = "grey30", margin = margin(b = 8)),
      plot.background = element_rect(fill = "white", colour = NA)
    )
)

as_programme <- function(x) {
  factor(ifelse(x == "member", "Member", "Casual"), levels = c("Member", "Casual"))
}

timing <- read_csv(file.path(derived, "timing.csv"), show_col_types = FALSE)
rider_profile <- read_csv(file.path(derived, "rider_profile.csv"), show_col_types = FALSE)
duration_bins <- read_csv(file.path(derived, "duration_bins.csv"), show_col_types = FALSE)

share_by_programme <- function(data, condition) {
  data |>
    mutate(programme = as_programme(member_casual)) |>
    group_by(programme) |>
    summarise(value = sum(n_trips[{{ condition }}]) / sum(n_trips), .groups = "drop") |>
    tibble::deframe()
}

weekend <- share_by_programme(timing, weekday %in% c("Saturday", "Sunday"))
peak <- share_by_programme(
  rider_profile,
  day_type == "Weekday" & time_block %in% c("AM peak", "PM peak")
)
long_trip <- share_by_programme(
  duration_bins,
  !duration_bin %in% c("1-5", "5-10", "10-15", "15-20", "20-30")
)

hourly <- timing |>
  filter(!weekday %in% c("Saturday", "Sunday")) |>
  mutate(programme = as_programme(member_casual)) |>
  group_by(programme, hour) |>
  summarise(n_trips = sum(n_trips), .groups = "drop_last") |>
  mutate(share = n_trips / sum(n_trips)) |>
  ungroup()

p_hourly <- ggplot(hourly, aes(hour, share, colour = programme)) +
  annotate("rect", xmin = 6, xmax = 9, ymin = -Inf, ymax = Inf, fill = "grey88", alpha = 0.5) +
  annotate("rect", xmin = 16, xmax = 19, ymin = -Inf, ymax = Inf, fill = "grey88", alpha = 0.5) +
  geom_line(linewidth = 1.1) +
  scale_colour_manual(values = pal) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = seq(0, 23, 3), labels = function(h) sprintf("%02d:00", h)) +
  labs(
    title = "Members ride the commute; casual riders ride the afternoon",
    subtitle = "Weekday trips by hour of day, 2021-2025. Shaded bands are the 06-09 and 16-19 commute windows.",
    x = "Hour the trip started", y = "Share of the group's weekday trips"
  )

signature <- tibble::tibble(
  metric = factor(
    rep(c("Ridden at a weekend", "Ridden in a weekday commute window", "Longer than 30 minutes"), each = 2),
    levels = c("Longer than 30 minutes", "Ridden in a weekday commute window", "Ridden at a weekend")
  ),
  programme = factor(rep(c("Member", "Casual"), 3), levels = c("Member", "Casual")),
  value = c(
    weekend[["Member"]], weekend[["Casual"]],
    peak[["Member"]], peak[["Casual"]],
    long_trip[["Member"]], long_trip[["Casual"]]
  )
)

p_signature <- ggplot(signature, aes(value, metric, fill = programme)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  geom_text(
    aes(label = percent(value, accuracy = 1)),
    position = position_dodge(width = 0.7), hjust = -0.2, size = 4.2, colour = "grey25"
  ) +
  scale_fill_manual(values = pal) +
  scale_x_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Casual riding is weekend and long; member riding is weekday and short",
    subtitle = "Share of each group's 27.7 million cleaned trips, 2021-2025",
    x = "Share of the group's trips", y = NULL
  )

ggsave(file.path(img_dir, "hourly-profile.png"), p_hourly,
       width = 11, height = 4.6, dpi = 140, bg = "white")
ggsave(file.path(img_dir, "usage-signature.png"), p_signature,
       width = 11, height = 4.2, dpi = 140, bg = "white")
message("Wrote preview images to ", img_dir)
