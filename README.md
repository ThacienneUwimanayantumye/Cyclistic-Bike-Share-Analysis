# Cyclistic Bike-Share Analysis

## Project Overview

This project analyzes how Cyclistic's bike-share system in Chicago is utilized by both **annual members** and **casual riders**. The insights aim to support the marketing team's initiative to convert casual riders into annual members by understanding their usage patterns and preferences.

---

## Data

The analysis uses publicly available historical ride data from Cyclistic, covering the **second quarter of 2019 to the first quarter of 2020**. The dataset, provided by Motivate International Inc. under a public data license, includes details about ride IDs, start and end times, stations, ride durations, and user types (member or casual).

---

## Methods

### Tools and Libraries
- **Programming Language**: R
- **Libraries**:
  - `tidyverse` for data manipulation
  - `lubridate` for date attribute handling
  - `ggplot2` for visualizations

### Workflow
1. **Data Collection**:
   - Consolidated multiple quarterly datasets into a single cohesive dataset.
2. **Data Cleaning**:
   - Standardized column names.
   - Removed irrelevant columns (e.g., latitude, longitude).
   - Addressed data inconsistencies (e.g., standardized ride IDs and user types).
   - Filtered out negative ride durations and quality control records.
3. **Feature Engineering**:
   - Created new columns: ride duration (`ride_length`) and date attributes (day, month, year, weekday).
4. **Descriptive Analysis**:
   - Computed metrics (mean, median, min, max ride durations) for members vs. casual riders.
   - Explored ride patterns by weekday for both user types.
5. **Visualization**:
   - Created bar charts to visualize:
     - Number of rides by user type and weekday.
     - Average ride duration by user type and weekday.

### Output
A summary CSV file containing aggregated ride data for further analysis.

---

## Key Findings

1. **Ride Duration**:
   - The average ride duration for casual riders is significantly longer than that of members.
   - Members display consistent usage patterns with shorter, functional trips.
2. **Weekly Trends**:
   - Members primarily ride on weekdays, while casual riders favor weekends.
   - Members show stable daily usage patterns, whereas casual rider usage peaks on weekends.
3. **Opportunities**:
   - Casual riders present a growth opportunity for weekday commuting.

---

## Recommendations

1. **Target Casual Riders**:
   - Develop marketing campaigns promoting the benefits of annual memberships for weekday commutes.
   - Highlight cost savings and convenience for frequent riders.
2. **Weekday Campaigns**:
   - Encourage weekday usage through promotional offers for casual riders.
   - Partner with local businesses for joint promotions targeting commuters.

---

## Usage

To replicate or extend this analysis:
1. Download Cyclistic ride data from [Cyclistic Data Portal](https://divvy-tripdata.s3.amazonaws.com/index.html).
2. Install R and the required libraries (`tidyverse`, `lubridate`, `ggplot2`).
3. Follow the analysis steps provided in the `Cyclistic_project.R` script.

---

## License

Motivate International Inc. provided the dataset used for this project under its [Data License Agreement](https://divvybikes.com/data-license-agreement).
