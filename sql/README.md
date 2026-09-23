# SQL Scripts

Add your MySQL Workbench `.sql` files to this folder, run in the following order:

| Order | File | Purpose |
|---|---|---|
| 1 | `01_staging_load.sql` | Loads raw CSV extracts (listings, hosts, calendar, reviews) into staging tables with minimal transformation. |
| 2 | `02_build_model.sql` | Cleans, types, deduplicates, and builds the analytical model: `fact_listings`, `dim_host`, `dim_neighbourhood`, and monthly review/availability rollups. |
| 3 | `03_edinburgh_story.sql` | The 4-chapter business analysis: Market Size, Geographic Supply, Seasonality & Availability, and Host Structure — plus the `vw_neighbourhood_scorecard` view. |

Based on this project's development history, the following queries/objects should exist inside `03_edinburgh_story.sql`:

- **Chapter 1 — How big is the market?**
  - Q1. Headline numbers (listings, hosts, % entire homes, % Superhost listings, average rating, listings without a price)
- **Chapter 2 — Where is the supply?**
  - Q3. Top neighbourhoods by listing share and cumulative share
  - Q4. `CREATE OR REPLACE VIEW vw_neighbourhood_scorecard` (listings, avg. estimated revenue, avg. estimated occupancy, avg. rating, revenue rank)
- **Chapter 3 — When does demand peak?**
  - Q5. Seasonality index by calendar month (2023–2025 full years)
  - Q7. Forward availability by month (excluding incomplete months near the scrape date)
- **Chapter 4 — Who runs the market?**
  - Q8. Host size bands — share of listings vs. share of estimated revenue, and STL licence number presence

> Replace the file names/numbering above with your actual script names if they differ, and paste in your finished, tested SQL. Keep each chapter's queries commented with a header banner (as in the original workbook) so the analytical narrative stays readable directly in the `.sql` file, not just in the dashboard.

## Running the scripts

```bash
mysql -u <user> -p airbnb_analytics < 01_staging_load.sql
mysql -u <user> -p airbnb_analytics < 02_build_model.sql
mysql -u <user> -p airbnb_analytics < 03_edinburgh_story.sql
```

Or open each file in MySQL Workbench against the `airbnb_analytics` schema and execute top to bottom.
