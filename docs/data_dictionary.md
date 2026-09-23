# Data Dictionary — Edinburgh Airbnb Market Analytics

This document describes the fields used across the staging, modelled, and analytical layers. Update table/column names here if your final schema differs from the naming used in `sql/`.

## 1. Grain & Core Entities

| Entity | Grain | Description |
|---|---|---|
| `fact_listings` (f) | One row per active listing | Core fact table combining listing, pricing, review, and estimated performance metrics. |
| `dim_host` (h) | One row per host | Host-level attributes, including portfolio size and Superhost status. |
| `dim_neighbourhood` (n) | One row per neighbourhood | Geographic dimension used for area-level rollups. |
| Reviews (monthly) | One row per listing per review month | Aggregated review counts by calendar month, used for seasonality analysis. |
| Availability (calendar) | One row per listing per date | Daily availability records across scrape snapshots, rolled up to month for forward-availability reporting. |

## 2. Key Fields

| Field | Table/Alias | Type | Description |
|---|---|---|---|
| `host_id` | f / h | ID | Unique identifier for a host; used to count distinct hosts and join to host attributes. |
| `room_type` | f | Text | Listing type, e.g. `Entire home/apt`, `Private room`, `Hotel room`, `Shared room`. |
| `price_gbp` | f | Numeric | Nightly listing price in GBP. |
| `review_scores_rating` | f | Numeric (0–5) | Average guest review score for the listing. |
| `is_superhost` | h | Boolean/Flag | Whether the host holds Superhost status. |
| `host_size_band` | h | Categorical | Bucketed host portfolio size: `1. Single listing`, `2. 2-5 listings`, `3. 6-20 listings`, `4. 21+ listings`. |
| `stl_number` | f / h | Text (nullable) | Scotland Short-Term Let licence number, where present in the listing data. |
| `neighbourhood_name` | n | Text | Standardized Edinburgh neighbourhood/area name. |
| `est_revenue_gbp_365` | f | Numeric | Modelled estimated annual revenue for the listing (GBP). |
| `est_occupancy_days_365` | f | Numeric | Modelled estimated annual occupied nights for the listing. |
| `review_month` | Reviews | Date (month) | Calendar month of a review, used to build seasonality metrics. |
| `review_count` | Reviews | Integer | Number of reviews received in a given month. |
| `available_days` | Availability | Integer | Count of available (unbooked) days within a calendar month. |
| `days_in_dataset` | Availability | Integer | Count of days in a month that are actually covered by the scrape snapshots (used to compute a fair % availability and exclude incomplete months). |
| `month_start` | Availability | Date | First day of the reporting month, used for month-over-month trending. |

## 3. Derived / Calculated Metrics

| Metric | Formula (conceptual) | Used In |
|---|---|---|
| `pct_entire_homes` | `100 × AVG(room_type = 'Entire home/apt')` | Chapter 1 — Market size |
| `pct_superhost_listings` | `100 × AVG(is_superhost)` | Chapter 1 — Market size |
| `share_pct` (neighbourhood) | `100 × listings / SUM(listings) OVER ()` | Chapter 2 — Geographic supply |
| `cumulative_share_pct` | Running `SUM(share_pct)` ordered by listings descending | Chapter 2 — Geographic supply |
| `seasonality_index` | `SUM(review_count) / (SUM(SUM(review_count)) OVER () / 12)` | Chapter 3 — Seasonality |
| `pct_days_available` | `100 × SUM(available_days) / SUM(days_in_dataset)` | Chapter 3 — Forward availability |
| `pct_with_stl_number` | `100 × AVG(stl_number IS NOT NULL)` | Chapter 4 — Host structure |
| `revenue_rank` | `RANK() OVER (ORDER BY avg_est_revenue_gbp DESC)` | Neighbourhood scorecard view |

## 4. Analytical View

### `vw_neighbourhood_scorecard`
A persisted view combining listing counts, average estimated revenue, average estimated occupancy, and average rating per neighbourhood, with a revenue-based rank. Built so Tableau (or any downstream BI tool) can query a single, pre-aggregated object rather than repeating the underlying joins/aggregations.

```sql
CREATE OR REPLACE VIEW vw_neighbourhood_scorecard AS
SELECT
    n.neighbourhood_name,
    COUNT(*)                                        AS listings,
    ROUND(AVG(f.est_revenue_gbp_365), 0)             AS avg_est_revenue_gbp,
    ROUND(AVG(f.est_occupancy_days_365), 0)          AS avg_est_occupancy_days,
    ROUND(AVG(f.review_scores_rating), 2)            AS avg_rating,
    RANK() OVER (ORDER BY AVG(f.est_revenue_gbp_365) DESC) AS revenue_rank
FROM fact_listings f
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
GROUP BY n.neighbourhood_name;
```

> ℹ️ Confirm exact column/table names against your live `03_build_model.sql` and update this dictionary to match before publishing.

## 5. Data Quality Notes

- **Missing prices:** 634 listings had no price recorded at the time of scrape — these are retained in counts but excluded from price-based averages.
- **Forward availability bias:** Months closest to the scrape date structurally appear "busier" (higher % available) simply because more of that month's data has been captured — always cross-check against the `days_in_dataset` completeness field.
- **STL licence number:** Presence of a number is a data-completeness indicator, not a confirmed regulatory compliance status.
