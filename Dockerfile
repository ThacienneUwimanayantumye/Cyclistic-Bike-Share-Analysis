# syntax=docker/dockerfile:1
FROM rocker/r-ver:4.4.2

# rocker/r-ver:4.4.2 is Ubuntu 24.04. Use Posit binary CRAN so sass/bslib/shiny
# are not compiled from source. `make` is required if a source fallback happens.
RUN apt-get update && apt-get install -y --no-install-recommends \
    make g++ \
    libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev \
    libtiff5-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CRAN=https://packagemanager.posit.co/cran/__linux__/noble/latest

RUN R --vanilla -e "options(repos = c(CRAN = Sys.getenv('CRAN'))); pkgs <- c('sass','bslib','shiny','bsicons','dplyr','readr','ggplot2','htmltools','scales','tidyr','here','markdown','lubridate','litedown'); install.packages(pkgs); missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]; if (length(missing)) stop('Failed to install: ', paste(missing, collapse = ', '))"

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
