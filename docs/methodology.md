# Methodology & Data Workflow

## 1. Data Source

| | |
|---|---|
| **Subject** | Airbnb short-term let listings, hosts, calendar/availability, and reviews for **Edinburgh, Scotland, UK** |
| **Format** | Listing-level, host-level, calendar-level, and review-level CSV extracts |
| **Snapshot dates** | 23 June 2026 and 2 July 2026 (two scrape snapshots, used for forward-looking availability) |
| **Historical review coverage** | Full calendar years 2015–2025 (used for year-over-year and seasonality analysis) |

> ⚠️ **Action needed:** Insert the exact source name, publisher, access URL, and licence/attribution terms here (e.g. *Inside Airbnb — insideairbnb.com — CC BY 4.0 / "Creative Commons" terms*, or your organization's licensed data vendor). This project's field naming conventions (`room_type`, `review_scores_rating`, `availability_365`, `host_id`, neighbourhood boundary names) follow common open Airbnb-data conventions — confirm and cite the precise provider before publishing this repository publicly.

## 2. Workflow Overview

```
┌─────────────────────┐
│ 1. Raw Data Extract  │  Listings, hosts, calendar (daily availability),
│                      │  and reviews CSVs for Edinburgh
└─────────┬────────────┘
          │
          ▼
┌─────────────────────┐
│ 2. Staging Load      │  Load raw files into MySQL staging tables
│  (01_staging_load.sql)│ as-is, with minimal transformation, to preserve
│                      │  an auditable copy of source data
└─────────┬────────────┘
          │
          ▼
┌─────────────────────┐
│ 3. Data Modelling    │  Clean data types, standardize categorical values
│ (02_build_model.sql) │  (e.g. room_type, host_size_band), deduplicate,
│                      │  handle nulls (e.g. missing price), and build:
│                      │    • fact_listings
│                      │    • dim_host
│                      │    • dim_neighbourhood
│                      │    • monthly review & availability rollups
└─────────┬────────────┘
          │
          ▼
┌─────────────────────┐
│ 4. Business Analysis │  4-chapter analytical SQL story answering
│(03_edinburgh_story.sql)  defined business questions (see BRD),
│                      │  plus a reusable analytical view:
│                      │    vw_neighbourhood_scorecard
└─────────┬────────────┘
          │
          ▼
┌─────────────────────┐
│ 5. Visualization     │  Tableau connects to MySQL (live or extract)
│                      │  and builds a 3-page dashboard:
│                      │    Overview → Area → Host
└─────────┬────────────┘
          │
          ▼
┌─────────────────────┐
│ 6. Insight Delivery  │  Findings summarized in README.md and BRD.md
│                      │  for stakeholder consumption
└──────────────────────┘
```

## 3. Analytical Approach

The analysis is organized as a four-chapter narrative, mirroring how the business questions build on one another:

1. **Chapter 1 — How big is the market?** Establishes headline scale metrics (listings, hosts, room-type mix, ratings, Superhost share, price completeness).
2. **Chapter 2 — Where is the supply?** Moves from a market-wide view to a geographic one, ranking neighbourhoods by listing share and building a persisted scorecard view for repeat use.
3. **Chapter 3 — When does demand peak?** Introduces the time dimension — a seasonality index normalized so 1.00 represents an average month — plus forward-looking availability, carefully excluding incomplete months to avoid recency bias.
4. **Chapter 4 — Who runs the market?** Segments hosts by portfolio size to reveal how listing share compares to revenue share, and cross-references STL licence number presence by segment.

## 4. Key SQL Techniques Used

- **Conditional aggregation** — e.g. `ROUND(100 * AVG(room_type = 'Entire home/apt'), 1)` to turn categorical shares into percentages without subqueries.
- **Window functions** — `SUM(...) OVER ()`, cumulative `SUM(...) OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)`, and `RANK() OVER (ORDER BY ...)` for share-of-total, running totals, and neighbourhood ranking.
- **Reusable views** — `CREATE OR REPLACE VIEW vw_neighbourhood_scorecard` so Tableau and future queries don't need to repeat the underlying joins/aggregations.
- **Bias-aware filtering** — excluding calendar months that are incomplete across both scrape snapshots before computing forward availability, to prevent near-term months from appearing artificially busier.

## 5. Visualization Approach

Tableau was connected to the MySQL analytical layer (fact table + `vw_neighbourhood_scorecard`) to build three linked dashboard pages:

- **Dashboard (Overview):** headline KPIs + seasonality line chart + annual review-volume bar chart with year-over-year % change callouts.
- **Area Overview:** dot-density map by estimated occupancy, choropleth map by estimated revenue, and a ranked neighbourhood revenue bar chart.
- **Host Overview:** host-size-band comparison of listing share vs. revenue share, and a Superhost vs. non-Superhost comparison on rating and revenue.

All three pages share global filters for **review month**, **neighbourhood name**, and **room type**, allowing stakeholders to drill from a market-wide view down to a specific area or segment without leaving the dashboard.

## 6. Limitations

- Estimated revenue and occupancy are modelled figures, not confirmed transaction data — they should be treated as directional indicators rather than exact financials.
- The two-snapshot scrape design means forward availability for months closest to the scrape date is less complete and should be read with the caveat noted in Chapter 3 of the SQL.
- STL licence number presence reflects what is captured in the source listing data at scrape time, not a live regulatory register lookup.
