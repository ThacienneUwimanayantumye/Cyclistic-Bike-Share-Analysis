#!/usr/bin/env Rscript
if (!requireNamespace("targets", quietly = TRUE)) {
  stop("Install the targets package, then re-run.")
}
targets::tar_make()
