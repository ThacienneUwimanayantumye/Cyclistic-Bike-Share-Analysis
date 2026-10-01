# syntax=docker/dockerfile:1
FROM rocker/r-ver:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev \
    libtiff5-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','bslib','bsicons','dplyr','readr','ggplot2','htmltools','scales','tidyr','here','markdown','lubridate','litedown'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY dashboard /app/dashboard
COPY docs/METHODS.md /app/dashboard/METHODS.md
COPY data/derived /app/data/derived
COPY scripts/start-shiny.sh /app/start-shiny.sh
RUN chmod +x /app/start-shiny.sh

ENV CYCLISTIC_DERIVED=/app/data/derived
ENV PORT=3838
EXPOSE 3838
CMD ["/app/start-shiny.sh"]
