library(shiny)
library(bslib)
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
    .hero-finding {
      padding: 0.1rem 0.05rem 0.15rem;
      margin: 0 0 0.85rem;
      color: #24323d;
    }
    .hero-finding .kicker {
      margin: 0 0 0.35rem;
      font-size: 0.78rem;
      font-weight: 650;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #5b6b75;
    }
    .hero-finding h2 {
      margin: 0 0 0.55rem;
      font-size: clamp(1.3rem, 2.2vw, 1.7rem);
      font-weight: 650;
      line-height: 1.25;
      color: #1B3A4B;
    }
    .hero-finding p {
      margin: 0;
      font-size: 1.05rem;
      line-height: 1.55;
      max-width: 72rem;
    }
    .hero-finding .caveat {
      margin-top: 0.55rem;
      font-size: 0.86rem;
      color: #5b6b75;
    }
    .kpi-row {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 0.85rem;
      margin: 0.15rem 0 0.35rem;
    }
    .kpi-card {
      border-radius: 0.5rem;
      padding: 0.95rem 1.05rem 1.05rem;
      min-height: 7.4rem;
    }
    .kpi-card.casual { background: #C05621; color: #fff; }
    .kpi-card.member { background: #215C8C; color: #fff; }
    .kpi-card.pool {
      background: #f4f7fa;
      color: #1B3A4B;
      border: 1px solid #d5dee6;
    }
    .kpi-label {
      font-size: 0.75rem;
      font-weight: 650;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      opacity: 0.88;
    }
    .kpi-value {
      font-size: clamp(1.2rem, 1.9vw, 1.6rem);
      font-weight: 650;
      line-height: 1.2;
      margin: 0.28rem 0 0.4rem;
    }
    .kpi-meta { font-size: 0.84rem; line-height: 1.4; opacity: 0.92; }
    .period-chip {
      font-size: 0.85rem;
      color: #5b6b75;
      padding: 0.35rem 0.25rem 0.7rem;
    }
    @media (max-width: 900px) {
      .kpi-row { grid-template-columns: 1fr; }
    }
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
    uiOutput("finding_text"),
    uiOutput("kpi_strip"),
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
        card_header("Commute-like casual trips show up in summer, not winter"),
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
        card_header("Casual riders pile into summer; members ride all year"),
        plotOutput("plot_season", height = "320px")
      ),
      card(
        card_header("Winter trips are mostly members; summer trips split more evenly"),
        plotOutput("plot_month_mix", height = "320px")
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

  output$finding_text <- renderUI({
    k <- kpis()
    tags$div(
      class = "hero-finding",
      tags$p(class = "kicker", period_label()),
      tags$h2("Members commute; casual riders leisure-ride."),
      tags$p(
        sprintf(
          "Of %s cleaned trips, casual riders take %s and members %s. Weekend share %s vs %s; median %s vs %s. ",
          fmt_trips(k$mix$n),
          fmt_pct0(k$mix$share_casual),
          fmt_pct0(k$mix$share_member),
          fmt_pct0(k$weekend[["Casual"]]),
          fmt_pct0(k$weekend[["Member"]]),
          fmt_min(k$med[["Casual"]]),
          fmt_min(k$med[["Member"]])
        ),
        tags$strong(fmt_trips(k$casual_commuter_n), " casual trips"),
        " are already short weekday peak-hour rides — the conversion target."
      ),
      tags$p(class = "caveat", "Trip-level only: Divvy files have no rider id.")
    )
  })

  output$kpi_strip <- renderUI({
    k <- kpis()
    HTML(kpi_strip_html(
      k$mix, k$weekend, k$med, k$casual_commuter_n, k$casual_commuter_share
    ))
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
    plot_commute_pool(d)
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
  output$plot_season <- renderPlot({
    d <- prog_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_season_profile(d)
  })
  output$plot_month_mix <- renderPlot({
    d <- prog_f()
    validate(need(nrow(d) > 0, "No trips in this window."))
    plot_month_mix(d)
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
