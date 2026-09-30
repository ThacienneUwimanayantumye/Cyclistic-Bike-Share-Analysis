library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(ggplot2)
library(htmltools)
library(scales)
library(tidyr)
library(markdown)

source("helpers.R", local = TRUE)

member_share <- read_indicator("member_share")
programme_month <- read_indicator("programme_month")
quality_month <- read_indicator("quality_month")
timing <- read_indicator("timing")
duration_month <- read_indicator("duration_month")
bike_type <- read_indicator("bike_type")
duration_bins <- read_indicator("duration_bins")
volume_stl <- read_indicator("volume_stl")
chisq_weekend <- read_indicator("chisq_weekend")
sql_duration <- read_indicator("sql_duration")
meta <- read_indicator("metadata")

months_available <- sort(unique(member_share$year_month))
year_available <- sort(unique(substr(months_available, 1, 4)))

filter_months <- function(df, years) {
  dplyr::filter(df, substr(.data$year_month, 1, 4) %in% years)
}

ui <- page_navbar(
  title = "Cyclistic Programme Monitor",
  fillable = FALSE,
  navbar_options = navbar_options(collapsible = FALSE),
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#215C8C",
    "navbar-bg" = "#163A58"
  ),
  header = tags$div(
    class = "px-3 pt-2 text-muted",
    style = "font-size: 0.9rem;",
    "Event-level monitoring of annual members vs casual riders (Chicago Divvy, 2021–2025). ",
    "Not a person-level coverage estimate."
  ),
  sidebar = sidebar(
    title = "Reporting period",
    checkboxGroupInput(
      "years",
      "Years",
      choices = year_available,
      selected = year_available
    ),
    helpText("Indicators are pre-aggregated. Raw trip files never enter this app."),
    hr(),
    tags$small(paste("Generated:", meta$generated_at[[1]]))
  ),
  nav_panel(
    "Overview",
    layout_columns(
      fill = FALSE,
      value_box(
        title = "Trips in selection",
        value = textOutput("kpi_trips", inline = TRUE),
        showcase = bs_icon("bicycle"),
        theme = "primary"
      ),
      value_box(
        title = "Member trip share",
        value = textOutput("kpi_share", inline = TRUE),
        showcase = bs_icon("person-badge"),
        theme = "secondary"
      ),
      value_box(
        title = "Records dropped (quality)",
        value = textOutput("kpi_drop", inline = TRUE),
        showcase = bs_icon("shield-exclamation"),
        theme = "warning"
      )
    ),
    card(
      card_header("Member trip share by month (Wilson 95% interval)"),
      plotOutput("plot_share", height = "380px")
    ),
    card(
      card_header("How to read this"),
      p(
        "The share is the proportion of ", tags$em("trips"),
        " taken by annual members. Divvy files have no rider identifier, so this is not ",
        "programme coverage of unique people. Interval bars are Wilson score intervals ",
        "on the trip-level binomial share."
      )
    )
  ),
  nav_panel(
    "Trends",
    card(
      card_header("Monthly trip volume by programme"),
      plotOutput("plot_volume", height = "360px")
    ),
    card(
      card_header("Seasonal-trend decomposition (total trips)"),
      plotOutput("plot_stl", height = "420px")
    )
  ),
  nav_panel(
    "When people ride",
    layout_columns(
      card(
        card_header("Members: weekday × hour"),
        plotOutput("heat_member", height = "400px")
      ),
      card(
        card_header("Casual riders: weekday × hour"),
        plotOutput("heat_casual", height = "400px")
      )
    ),
    card(
      card_header("Weekend contrast (descriptive)"),
      verbatimTextOutput("chisq_text")
    )
  ),
  nav_panel(
    "Duration",
    layout_columns(
      card(
        card_header("Median duration (minutes) by month"),
        plotOutput("plot_duration", height = "360px")
      ),
      card(
        card_header("Duration distribution (analytic extract)"),
        plotOutput("plot_dur_bins", height = "360px")
      )
    ),
    card(
      card_header("SQL summary (DuckDB)"),
      tableOutput("sql_dur_table")
    )
  ),
  nav_panel(
    "Bike type",
    card(
      card_header("Trip mix by bicycle type and programme"),
      plotOutput("plot_bikes", height = "400px")
    )
  ),
  nav_panel(
    "Data quality",
    card(
      card_header("Drop rate and missing start station among kept trips"),
      plotOutput("plot_quality", height = "380px")
    ),
    card(
      card_header("Exclusion counts by month"),
      div(style = "overflow-x: auto;", tableOutput("quality_table"))
    )
  ),
  nav_panel(
    "Methods",
    card(
      includeMarkdown(
        if (file.exists("METHODS.md")) "METHODS.md" else file.path("..", "docs", "METHODS.md")
      )
    )
  )
)

server <- function(input, output, session) {
  years <- reactive({
    y <- input$years
    if (is.null(y) || !length(y)) year_available else y
  })

  share_f <- reactive(filter_months(member_share, years()))
  prog_f <- reactive(filter_months(programme_month, years()))
  qual_f <- reactive(filter_months(quality_month, years()))
  time_f <- reactive(filter_months(timing, years()))
  dur_f <- reactive(filter_months(duration_month, years()))
  bins_f <- reactive(filter_months(duration_bins, years()))
  bike_f <- reactive(filter_months(bike_type, years()))
  stl_f <- reactive(filter_months(volume_stl, years()))

  output$kpi_trips <- renderText({
    fmt_int(sum(share_f()$n_trips))
  })
  output$kpi_share <- renderText({
    d <- share_f()
    fmt_pct(sum(d$n_member) / sum(d$n_trips))
  })
  output$kpi_drop <- renderText({
    d <- qual_f()
    fmt_pct(sum(d$n_dropped) / sum(d$n_in))
  })

  output$plot_share <- renderPlot({
    d <- share_f()
    p <- ggplot(d, aes(x = year_month, y = member_share)) +
      geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = "#215C8C", alpha = 0.2, group = 1) +
      geom_line(aes(group = 1), colour = "#215C8C") +
      geom_point(colour = "#215C8C", size = 1.4) +
      scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
      labs(x = NULL, y = "Member trip share") +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 8))
    p
  })

  output$plot_volume <- renderPlot({
    d <- prog_f()
    p <- ggplot(d, aes(year_month, n_trips, colour = member_casual, group = member_casual)) +
      geom_line() +
      geom_point(size = 1.2) +
      scale_colour_manual(values = programme_colors, name = NULL) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips") +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 8))
    p
  })

  output$plot_stl <- renderPlot({
    d <- stl_f() |>
      tidyr::pivot_longer(c("observed", "trend", "seasonal", "remainder"),
                          names_to = "component", values_to = "value")
    p <- ggplot(d, aes(year_month, value, group = 1)) +
      geom_line(colour = "#215C8C") +
      facet_wrap(~component, ncol = 1, scales = "free_y") +
      labs(x = NULL, y = NULL) +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 7))
    p
  })

  heatmap_plot <- function(programme) {
    d <- time_f() |>
      dplyr::filter(.data$member_casual == programme) |>
      dplyr::group_by(.data$weekday, .data$hour) |>
      dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop")
    d$weekday <- factor(d$weekday, levels = c(
      "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ))
    p <- ggplot(d, aes(hour, weekday, fill = n_trips)) +
      geom_tile() +
      scale_fill_gradient(low = "#F4F7FA", high = if (programme == "member") "#215C8C" else "#C05621") +
      scale_x_continuous(breaks = seq(0, 23, 2)) +
      labs(x = "Hour of day", y = NULL, fill = "Trips") +
      theme_monitor()
    p
  }

  output$heat_member <- renderPlot(heatmap_plot("member"))
  output$heat_casual <- renderPlot(heatmap_plot("casual"))

  output$chisq_text <- renderText({
    x <- chisq_weekend[1, ]
    paste0(
      "2×2 table of trips: programme × weekend.\n",
      "Chi-square = ", round(x$statistic, 1), " on ", x$df, " df, p = ",
      format.pval(x$p_value, eps = 1e-16), "\n",
      "Member weekday/weekend: ", fmt_int(x$n_member_weekday), " / ",
      fmt_int(x$n_member_weekend), "\n",
      "Casual weekday/weekend: ", fmt_int(x$n_casual_weekday), " / ",
      fmt_int(x$n_casual_weekend), "\n\n",
      x$note
    )
  })

  output$plot_duration <- renderPlot({
    d <- dur_f()
    p <- ggplot(d, aes(year_month, duration_median_min, colour = member_casual, group = member_casual)) +
      geom_line() +
      geom_point(size = 1.2) +
      scale_colour_manual(values = programme_colors, name = NULL) +
      labs(x = NULL, y = "Median duration (minutes)") +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 8))
    p
  })

  output$plot_dur_bins <- renderPlot({
    d <- bins_f() |>
      dplyr::group_by(.data$member_casual, .data$duration_bin) |>
      dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop") |>
      dplyr::group_by(.data$member_casual) |>
      dplyr::mutate(share = n_trips / sum(n_trips))
    p <- ggplot(d, aes(duration_bin, share, fill = member_casual)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = programme_colors, name = NULL) +
      scale_y_continuous(labels = percent_format()) +
      labs(x = "Duration (minutes)", y = "Share of trips") +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    p
  })

  output$sql_dur_table <- renderTable({
    sql_duration
  })

  output$plot_bikes <- renderPlot({
    d <- bike_f() |>
      dplyr::group_by(.data$member_casual, .data$rideable_type) |>
      dplyr::summarise(n_trips = sum(.data$n_trips), .groups = "drop")
    p <- ggplot(d, aes(rideable_type, n_trips, fill = member_casual)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = programme_colors, name = NULL) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips") +
      theme_monitor()
    p
  })

  output$plot_quality <- renderPlot({
    d <- qual_f() |>
      dplyr::mutate(drop_rate = n_dropped / n_in)
    p <- ggplot(d, aes(year_month, group = 1)) +
      geom_line(aes(y = drop_rate, colour = "Drop rate")) +
      geom_line(aes(y = pct_missing_start_station, colour = "Missing start station (kept)")) +
      scale_colour_manual(values = c("Drop rate" = "#7B2D26", "Missing start station (kept)" = "#215C8C"), name = NULL) +
      scale_y_continuous(labels = percent_format()) +
      labs(x = NULL, y = NULL) +
      theme_monitor() +
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 8))
    p
  })

  output$quality_table <- renderTable({
    qual_f() |>
      dplyr::transmute(
        year_month,
        n_in = n_in,
        n_kept = n_kept,
        n_dropped = n_dropped,
        too_short = n_duration_too_short,
        too_long = n_duration_too_long,
        non_positive = n_duration_non_positive,
        missing_programme = n_missing_programme
      )
  }, digits = 0)
}

shinyApp(ui, server)
