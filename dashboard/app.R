library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(ggplot2)
library(htmltools)
library(scales)

source("helpers.R", local = TRUE)

member_share <- read_indicator("member_share")
programme_month <- read_indicator("programme_month")
quality_month <- read_indicator("quality_month")
timing <- read_indicator("timing")
duration_month <- read_indicator("duration_month")
bike_type <- read_indicator("bike_type")
duration_bins <- read_indicator("duration_bins")
rider_profile <- read_indicator("rider_profile")
meta <- read_indicator("metadata")

year_available <- sort(unique(substr(member_share$year_month, 1, 4)))

finding_banner <- function(...) {
  tags$div(
    class = "finding",
    ...
  )
}

ui <- page_navbar(
  title = "Cyclistic Programme Monitor",
  fillable = FALSE,
  navbar_options = navbar_options(collapsible = FALSE),
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#215C8C",
    "navbar-bg" = "#1B3A4B"
  ),
  header = tags$head(tags$style(HTML("
    .finding {
      background: #eef3f7;
      border-left: 4px solid #215C8C;
      padding: 0.85rem 1.1rem;
      margin: 0;
      font-size: 1.02rem;
      line-height: 1.5;
      color: #24323d;
    }
    .finding strong { color: #1B3A4B; }
    .period-chip {
      font-size: 0.85rem;
      color: #5b6b75;
      padding: 0.35rem 0.25rem 0.7rem;
    }
    .bslib-value-box .value-box-grid {
      grid-template-columns: 2.8rem 1fr !important;
    }
    .bslib-value-box .value-box-value {
      font-size: clamp(1.15rem, 1.6vw, 1.75rem) !important;
      white-space: nowrap;
    }
    .bslib-value-box .value-box-showcase { max-width: 2.8rem; }
  "))),
  sidebar = sidebar(
    title = "Filters",
    checkboxGroupInput(
      "years",
      "Years",
      choices = year_available,
      selected = year_available
    ),
    radioButtons(
      "season",
      "Season",
      choices = SEASON_CHOICES,
      selected = "all"
    ),
    actionLink("reset", "Reset to 2021–2025, all months"),
    helpText("Every chart and KPI below uses this window. Indicators are trip-level; Divvy files have no rider id."),
    hr(),
    tags$small(paste("Generated:", meta$generated_at[[1]]))
  ),
  nav_panel(
    "The difference",
    uiOutput("period_chip"),
    layout_columns(
      fill = FALSE,
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = textOutput("kpi_title_casual", inline = TRUE),
        value = textOutput("kpi_share_casual", inline = TRUE),
        showcase = bs_icon("person"),
        theme = value_box_theme(bg = "#C05621", fg = "#fff")
      ),
      value_box(
        title = textOutput("kpi_title_member", inline = TRUE),
        value = textOutput("kpi_share_member", inline = TRUE),
        showcase = bs_icon("person-badge"),
        theme = value_box_theme(bg = "#215C8C", fg = "#fff")
      ),
      value_box(
        title = "Median trip · casual",
        value = textOutput("kpi_med_casual", inline = TRUE),
        showcase = bs_icon("hourglass-split"),
        theme = value_box_theme(bg = "#A85A32", fg = "#fff")
      ),
      value_box(
        title = "Median trip · member",
        value = textOutput("kpi_med_member", inline = TRUE),
        showcase = bs_icon("hourglass"),
        theme = value_box_theme(bg = "#3D7A9E", fg = "#fff")
      )
    ),
    card(finding_banner(uiOutput("finding_text"))),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Members peak twice on weekdays; casual riders peak once in the afternoon"),
        plotOutput("plot_hourly", height = "360px")
      ),
      card(
        card_header("Casual riding is weekend and long; member riding is weekday and short"),
        plotOutput("plot_signature", height = "360px")
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Casual trips that already look like a commute"),
        plotOutput("plot_commute", height = "340px")
      ),
      card(
        card_header("Member trips bunch under 15 minutes; casual trips have a long tail"),
        plotOutput("plot_duration", height = "340px")
      )
    )
  ),
  nav_panel(
    "Week and season",
    uiOutput("period_chip_season"),
    card(
      card_header("Members concentrate on weekday evenings; casual riders spread into weekends"),
      plotOutput("plot_heat", height = "420px")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Casual volume collapses every winter; member volume holds up"),
        plotOutput("plot_volume", height = "320px")
      ),
      card(
        card_header("Members dominate winter; casual riders close the gap each summer"),
        plotOutput("plot_share", height = "320px")
      )
    ),
    card(
      card_header("Bike type does not separate the two groups"),
      plotOutput("plot_bikes", height = "280px")
    )
  ),
  nav_panel(
    "Data quality",
    uiOutput("period_chip_quality"),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Share of source records kept"),
        plotOutput("plot_quality", height = "320px")
      ),
      card(
        card_header("Sub-minute rides (dock glitches) account for most exclusions"),
        plotOutput("plot_exclusions", height = "320px")
      )
    ),
    card(
      card_header("What this can and cannot tell you"),
      uiOutput("scope_text")
    ),
    accordion(
      open = FALSE,
      accordion_panel(
        "Exclusion counts by month",
        div(style = "overflow-x: auto;", tableOutput("quality_table"))
      )
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
  observeEvent(input$reset, {
    updateCheckboxGroupInput(session, "years", selected = year_available)
    updateRadioButtons(session, "season", selected = "all")
  })

  years <- reactive({
    y <- input$years
    if (is.null(y) || !length(y)) year_available else y
  })

  season <- reactive({
    s <- input$season
    if (is.null(s) || !nzchar(s)) "all" else s
  })

  period_label <- reactive({
    yrs <- years()
    yr_txt <- if (length(yrs) == length(year_available)) {
      paste0(year_available[[1]], "–", year_available[[length(year_available)]])
    } else {
      paste(yrs, collapse = ", ")
    }
    paste0(yr_txt, " · ", season_label(season()))
  })

  period_chip_ui <- reactive({
    tags$div(class = "period-chip", "Showing ", tags$strong(period_label()), ".")
  })

  output$period_chip <- renderUI(period_chip_ui())
  output$period_chip_season <- renderUI(period_chip_ui())
  output$period_chip_quality <- renderUI(period_chip_ui())

  share_f <- reactive(slice_period(member_share, years(), season()))
  prog_f <- reactive(slice_period(programme_month, years(), season()))
  qual_f <- reactive(slice_period(quality_month, years(), season()))
  time_f <- reactive(slice_period(timing, years(), season()))
  dur_f <- reactive(slice_period(duration_month, years(), season()))
  bins_f <- reactive(slice_period(duration_bins, years(), season()))
  bike_f <- reactive(slice_period(bike_type, years(), season()))
  profile_f <- reactive(slice_period(rider_profile, years(), season()))

  kpis <- reactive({
    weekend <- share_by_programme(time_f(), weekday %in% c("Saturday", "Sunday"))
    peak <- share_by_programme(
      profile_f(),
      day_type == "Weekday" & time_block %in% c("AM peak", "PM peak")
    )
    long_trip <- share_by_programme(
      bins_f(),
      !duration_bin %in% c("1-5", "5-10", "10-15", "15-20", "20-30")
    )
    med <- weighted_median_duration(dur_f())
    mix <- programme_mix(share_f())
    commute <- commute_like_counts(profile_f())
    casual_n <- commute$n[commute$member_casual == "casual"]
    if (!length(casual_n)) casual_n <- 0
    casual_total <- sum(profile_f()$n_trips[profile_f()$member_casual == "casual"])
    list(
      weekend = weekend,
      peak = peak,
      long_trip = long_trip,
      med = med,
      mix = mix,
      casual_commuter_n = casual_n,
      casual_commuter_share = if (casual_total > 0) casual_n / casual_total else NA_real_
    )
  })

  output$kpi_share_casual <- renderText(fmt_pct(kpis()$mix$share_casual))
  output$kpi_share_member <- renderText(fmt_pct(kpis()$mix$share_member))
  output$kpi_title_casual <- renderText(paste("Casual ·", fmt_trips(kpis()$mix$n_casual), "trips"))
  output$kpi_title_member <- renderText(paste("Member ·", fmt_trips(kpis()$mix$n_member), "trips"))
  output$kpi_med_casual <- renderText(fmt_min(kpis()$med[["Casual"]]))
  output$kpi_med_member <- renderText(fmt_min(kpis()$med[["Member"]]))

  output$finding_text <- renderUI({
    k <- kpis()
    tagList(
      tags$strong("Members commute; casual riders leisure-ride. "),
      sprintf(
        "Of %s cleaned trips, casual riders take %s and members %s. Weekend share %s vs %s; median %s vs %s. ",
        fmt_trips(k$mix$n),
        fmt_pct(k$mix$share_casual),
        fmt_pct(k$mix$share_member),
        fmt_pct(k$weekend[["Casual"]]),
        fmt_pct(k$weekend[["Member"]]),
        fmt_min(k$med[["Casual"]]),
        fmt_min(k$med[["Member"]])
      ),
      tags$strong(fmt_trips(k$casual_commuter_n), " casual trips"),
      " are already short weekday peak-hour rides — the conversion target. Trip-level only: Divvy files have no rider id."
    )
  })

  output$plot_hourly <- renderPlot({
    d <- time_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_hourly(d)
  })
  output$plot_signature <- renderPlot({
    k <- kpis()
    validate(need(any(!is.na(k$weekend)), "No trips in this window."))
    plot_signature(k$weekend, k$peak, k$long_trip)
  })
  output$plot_commute <- renderPlot({
    d <- profile_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_commute_trend(d)
  })
  output$plot_duration <- renderPlot({
    d <- bins_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_duration_bins(d)
  })
  output$plot_heat <- renderPlot({
    d <- time_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_heatmap(d)
  })
  output$plot_volume <- renderPlot({
    d <- prog_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_volume(d)
  })
  output$plot_share <- renderPlot({
    d <- share_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_member_share(d)
  })
  output$plot_bikes <- renderPlot({
    d <- bike_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_bikes(d)
  })
  output$plot_quality <- renderPlot({
    d <- qual_f()
    validate(need(nrow(d) > 0, "No records in this window."))
    plot_quality_kept(d)
  })
  output$plot_exclusions <- renderPlot({
    d <- qual_f()
    validate(need(nrow(d) > 0, "No records in this window."))
    plot_exclusions(d)
  })

  output$scope_text <- renderUI({
    d <- share_f()
    q <- qual_f()
    n_trips <- sum(d$n_trips)
    n_in <- sum(q$n_in)
    drop_rate <- if (n_in > 0) 1 - n_trips / n_in else NA_real_
    tagList(
      tags$p(
        tags$strong("Answered here. "),
        sprintf(
          "How member and casual trips differ in timing, length, day of week, season and bike choice, in %s (%s cleaned trips). %s of %s source records were excluded.",
          period_label(), fmt_int(n_trips), fmt_pct(drop_rate), fmt_int(n_in)
        )
      ),
      tags$p(
        tags$strong("Not answerable from this data. "),
        "Anything about people. Divvy's public files carry no rider identifier, so a rider taking 200 trips and 200 riders taking one trip each are indistinguishable. Every figure here is a share of trips, never a share of riders, and no conversion rate or per-rider frequency can be derived."
      ),
      tags$p(
        tags$strong("Statistical note. "),
        "The member/casual difference in weekend riding is overwhelmingly significant on a chi-square test, but that test assumes independent observations and trips cluster within unobserved riders. The effect sizes on The difference are the meaningful result."
      )
    )
  })

  output$quality_table <- renderTable({
    qual_f() |>
      transmute(
        year_month,
        n_in,
        n_kept,
        n_dropped,
        too_short = n_duration_too_short,
        too_long = n_duration_too_long,
        non_positive = n_duration_non_positive,
        missing_programme = n_missing_programme
      )
  }, digits = 0)
}

shinyApp(ui, server)
