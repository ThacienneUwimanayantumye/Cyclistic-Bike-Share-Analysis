#!/bin/sh
# Render injects PORT. Local Docker defaults to 3838.
set -e
PORT="${PORT:-3838}"
export PORT
exec R --vanilla -e "shiny::runApp('/app/dashboard', host = '0.0.0.0', port = as.integer(Sys.getenv('PORT', '3838')))"
