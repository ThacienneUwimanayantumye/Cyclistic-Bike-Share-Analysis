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

pal <- c(member = "#215C8C", casual = "#C05621")
theme_set(
  theme_minimal(base_size = 14) +
    theme(
      legend.position = "top",
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = 16),
      plot.background = element_rect(fill = "white", colour = NA)
    )
)

member_share <- read_csv(file.path(derived, "member_share.csv"), show_col_types = FALSE)
programme_month <- read_csv(file.path(derived, "programme_month.csv"), show_col_types = FALSE)
member_share$date <- as.Date(paste0(member_share$year_month, "-01"))
programme_month$date <- as.Date(paste0(programme_month$year_month, "-01"))

p_share <- ggplot(member_share, aes(date, member_share)) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = "#215C8C", alpha = 0.22) +
  geom_line(colour = "#215C8C", linewidth = 0.9) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "Member share of trips, 2021–2025",
    subtitle = "Wilson 95% interval · event-level, not unique riders",
    x = NULL, y = NULL
  )

p_vol <- ggplot(programme_month, aes(date, n_trips, colour = member_casual)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = pal, name = NULL) +
  scale_y_continuous(labels = comma) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "Monthly trip volume by programme",
    x = NULL, y = NULL
  )

ggsave(file.path(img_dir, "member-share.png"), p_share, width = 11, height = 4.2, dpi = 140, bg = "white")
ggsave(file.path(img_dir, "volume.png"), p_vol, width = 11, height = 4.2, dpi = 140, bg = "white")
message("Wrote preview images to ", img_dir)
