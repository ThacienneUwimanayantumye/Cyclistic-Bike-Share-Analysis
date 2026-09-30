#' Resolve the derived-indicator directory (local pipeline, Docker, or env).
derived_dir <- function() {
  env <- Sys.getenv("CYCLISTIC_DERIVED", unset = "")
  candidates <- c(
    if (nzchar(env)) env else NULL,
    "/srv/data/derived",
    tryCatch(file.path(here::here(), "data", "derived"), error = function(e) NULL),
    file.path("..", "data", "derived"),
    file.path("data", "derived")
  )
  for (p in candidates) {
    if (!is.null(p) && dir.exists(p) && file.exists(file.path(p, "member_share.csv"))) {
      return(normalizePath(p))
    }
  }
  stop(
    "Could not find data/derived/*.csv. Run `targets::tar_make()` in the project root ",
    "or set CYCLISTIC_DERIVED."
  )
}

read_indicator <- function(name, dir = derived_dir()) {
  readr::read_csv(file.path(dir, paste0(name, ".csv")), show_col_types = FALSE)
}

programme_colors <- c(member = "#215C8C", casual = "#C05621")

theme_monitor <- function() {
  ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      legend.position = "top",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      axis.text.x = ggplot2::element_text(angle = 0)
    )
}

fmt_int <- function(x) scales::label_comma()(x)
fmt_pct <- function(x) scales::percent(x, accuracy = 0.1)
