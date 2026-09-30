# Use of agentic AI on this project

This repository was built with **Cursor** (agentic coding assistance) plus human specification and review.

That matches how the Finnish Cancer Registry job description treats Git **and** agentic AI: the tools are part of the workflow, not a substitute for statistical judgement.

## What the agent did

- Scaffolded the `{targets}` pipeline, DuckDB helpers, Shiny layout, tests, Docker, and CI files
- Wired indicator tables and the dashboard to the same derived CSVs
- Iterated on system-library issues for R package installation on macOS

## What was specified and checked by a human

- Business framing: **programme monitoring**, not marketing conversion as the lead story
- Refusal to recast bike-share trips as cancer-screening data
- Indicator definitions (exclusions, 60-second / 24-hour duration rules)
- The person-level limitation (no rider id → no coverage)
- Wilson intervals, STL, and the chi-square *caveat*
- Review of generated R for locale-safe weekdays, schema contracts, and dashboard-on-aggregates only

## What we did not do

- Commit secrets or raw monthly zips
- Generate results without running the pipeline on the real 2021–2025 files
- Hide AI use in the README
