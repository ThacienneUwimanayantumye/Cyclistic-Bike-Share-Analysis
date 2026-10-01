# syntax=docker/dockerfile:1
# rocker/shiny already has shiny, bslib, sass, and fs as binaries.
# Do not use R --vanilla for package installs: that drops the HTTP User-Agent
# Posit needs, so Package Manager would fall back to source tarballs.
FROM rocker/shiny:4.4.2

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev \
    libtiff5-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error --skipinstalled --ncpus -1 \
    dplyr readr ggplot2 scales tidyr here bsicons lubridate markdown litedown

WORKDIR /app
COPY dashboard /app/dashboard
COPY docs/METHODS.md /app/dashboard/METHODS.md
COPY data/derived /app/data/derived
COPY scripts/start-shiny.sh /app/start-shiny.sh
RUN chmod +x /app/start-shiny.sh && sed -i 's/\r$//' /app/start-shiny.sh

ENV CYCLISTIC_DERIVED=/app/data/derived
ENV PORT=3838
EXPOSE 3838
CMD ["/bin/sh", "/app/start-shiny.sh"]
