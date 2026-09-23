-- ===========================================================================
-- EDINBURGH AIRBNB - SQL STORY (MySQL 8.0, schema: airbnb_analytics)
-- Chapters: 1 How big?  2 Where?  3 When?  4 Who?  5 So what?
-- Run ONE query at a time (cursor on the query -> Ctrl+Enter).
-- ===========================================================================
USE airbnb_analytics;

-- ---------------------------------------------------------------------------
-- CHAPTER 1: HOW BIG IS THE MARKET?
-- ---------------------------------------------------------------------------
-- Q1. Headline numbers
SELECT COUNT(*)                                             AS listings,
       COUNT(DISTINCT f.host_id)                            AS hosts,
       ROUND(100 * AVG(f.room_type = 'Entire home/apt'), 1) AS pct_entire_homes,
       ROUND(100 * AVG(h.is_superhost), 1)                  AS pct_superhost_listings,
       ROUND(AVG(f.review_scores_rating), 2)                AS avg_rating,
       SUM(f.price_gbp IS NULL)                             AS listings_without_price
FROM fact_listing f
JOIN dim_host h ON h.host_id = f.host_id;

-- Q2. Median price (MySQL has no MEDIAN(), so we rank the rows and pick the middle one)
-- NOTE: price is a quote for one future stay, not a base rate. Use it to compare listings, not seasons.
WITH ranked AS (
  SELECT price_gbp,
         ROW_NUMBER() OVER (ORDER BY price_gbp) AS rn,
         COUNT(*)     OVER ()                   AS cnt
  FROM fact_listing
  WHERE price_gbp IS NOT NULL
)
SELECT ROUND(AVG(price_gbp), 1) AS median_price_gbp,
       (SELECT ROUND(AVG(price_gbp), 1) FROM fact_listing) AS mean_price_gbp   -- mean is pulled up by outliers
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- ---------------------------------------------------------------------------
-- CHAPTER 2: WHERE IS THE SUPPLY?
-- ---------------------------------------------------------------------------
-- Q3. Top 10 neighbourhoods: share of listings + cumulative share
SELECT n.neighbourhood_name,
       COUNT(*)                                                    AS listings,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)            AS share_pct,
       ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC ROWS UNBOUNDED PRECEDING)
                 / SUM(COUNT(*)) OVER (), 1)                       AS cumulative_share_pct
FROM fact_listing f
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
GROUP BY n.neighbourhood_name
ORDER BY listings DESC
LIMIT 10;

-- Q4. Neighbourhood scorecard (a VIEW, so Tableau and later queries can reuse it)
CREATE OR REPLACE VIEW vw_neighbourhood_scorecard AS
SELECT n.neighbourhood_name,
       COUNT(*)                                                       AS listings,
       ROUND(AVG(f.est_revenue_gbp_365), 0)                           AS avg_est_revenue_gbp,
       ROUND(AVG(f.est_occupancy_days_365), 0)                        AS avg_est_occupancy_days,
       ROUND(AVG(f.review_scores_rating), 2)                          AS avg_rating,
       ROUND(100 * AVG(f.license_status = 'Edinburgh STL number'), 1) AS pct_with_stl_number
FROM fact_listing f
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
GROUP BY n.neighbourhood_name;

SELECT RANK() OVER (ORDER BY avg_est_revenue_gbp DESC) AS revenue_rank, s.*
FROM vw_neighbourhood_scorecard s
WHERE listings >= 30            -- ignore tiny areas, their averages are unreliable
ORDER BY revenue_rank
LIMIT 10;

-- ---------------------------------------------------------------------------
-- CHAPTER 3: WHEN IS DEMAND HIGH?  (reviews = proxy for real stays)
-- ---------------------------------------------------------------------------
-- Q5. Seasonality: share of the year's reviews by calendar month (full years 2023-2025)
--     seasonality_index 1.00 = an average month; 1.50 = 50% busier than average
SELECT MONTH(review_month)                                              AS month_no,
       MONTHNAME(MIN(review_month))                                     AS month_name,
       SUM(review_count)                                                AS reviews,
       ROUND(100 * SUM(review_count) / SUM(SUM(review_count)) OVER (), 1) AS pct_of_year,
       ROUND(SUM(review_count) / (SUM(SUM(review_count)) OVER () / 12), 2) AS seasonality_index
FROM fact_reviews_monthly
WHERE review_month BETWEEN '2023-01-01' AND '2025-12-01'
GROUP BY MONTH(review_month)
ORDER BY month_no;

-- Q6. Yearly trend + year-on-year growth (LAG looks at the previous row)
WITH yearly AS (
  SELECT YEAR(review_month) AS yr, SUM(review_count) AS reviews
  FROM fact_reviews_monthly
  WHERE YEAR(review_month) BETWEEN 2015 AND 2025
  GROUP BY YEAR(review_month)
)
SELECT yr, reviews,
       ROUND(100 * (reviews - LAG(reviews) OVER (ORDER BY yr)) / LAG(reviews) OVER (ORDER BY yr), 1) AS yoy_growth_pct
FROM yearly
ORDER BY yr;

-- Q7. Forward availability by month.
--     Listings were scraped on two dates (23 Jun and 2 Jul 2026), so the first month (Jul 2026) and the
--     last month (Jun 2027) are incomplete for some listings. We keep only months that are complete for all.
--     CAUTION: near months look busier simply because they are closer to the scrape date.
SELECT month_start,
       ROUND(100 * SUM(available_days) / SUM(days_in_data), 1) AS pct_days_available
FROM fact_calendar_monthly
WHERE month_start BETWEEN '2026-08-01' AND '2027-05-01'
GROUP BY month_start
ORDER BY month_start;

-- ---------------------------------------------------------------------------
-- CHAPTER 4: WHO RUNS THE MARKET?
-- ---------------------------------------------------------------------------
-- Q8. Host size bands: share of listings vs share of estimated revenue
SELECT h.host_size_band,
       COUNT(DISTINCT h.host_id)                                          AS hosts,
       COUNT(*)                                                           AS listings,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                   AS pct_of_listings,
       ROUND(100 * SUM(f.est_revenue_gbp_365) / SUM(SUM(f.est_revenue_gbp_365)) OVER (), 1) AS pct_of_est_revenue
FROM fact_listing f
JOIN dim_host h ON h.host_id = f.host_id
GROUP BY h.host_size_band
ORDER BY h.host_size_band;

-- Q9. Top 10 hosts with running (cumulative) share of ALL listings
SELECT host_id, host_name, listings_count,
       ROUND(100 * SUM(listings_count) OVER (ORDER BY listings_count DESC, host_id ROWS UNBOUNDED PRECEDING)
                 / (SELECT COUNT(*) FROM fact_listing), 1) AS cumulative_pct_of_all_listings
FROM dim_host
ORDER BY listings_count DESC, host_id
LIMIT 10;

-- Q10. Superhost vs non-superhost
-- CAUTION: Inside Airbnb estimates occupancy partly from reviews, so more reviews -> higher estimate.
SELECT h.is_superhost,
       COUNT(*)                                     AS listings,
       ROUND(AVG(f.review_scores_rating), 2)        AS avg_rating,
       ROUND(AVG(f.est_occupancy_days_365), 0)      AS avg_est_occupancy_days,
       ROUND(AVG(f.est_revenue_gbp_365), 0)         AS avg_est_revenue_gbp
FROM fact_listing f
JOIN dim_host h ON h.host_id = f.host_id
GROUP BY h.is_superhost;

-- ---------------------------------------------------------------------------
-- CHAPTER 5: SO WHAT?
-- ---------------------------------------------------------------------------
-- Q11. Licence field completeness by host size (a data-quality / compliance PROXY, not proof of legality)
SELECT h.host_size_band,
       COUNT(*)                                                          AS listings,
       ROUND(100 * AVG(f.license_status = 'Edinburgh STL number'), 1)    AS pct_with_stl_number,
       ROUND(100 * AVG(f.license_status = 'Missing'), 1)                 AS pct_missing
FROM fact_listing f
JOIN dim_host h ON h.host_id = f.host_id
GROUP BY h.host_size_band
ORDER BY h.host_size_band;

-- Q12. Where do the busiest listings sit? Top 5 neighbourhoods by listings that are high-occupancy (200+ days)
SELECT n.neighbourhood_name,
       COUNT(*)                                             AS high_occupancy_listings,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS share_of_all_high_occ_pct
FROM fact_listing f
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
WHERE f.est_occupancy_days_365 >= 200
GROUP BY n.neighbourhood_name
ORDER BY high_occupancy_listings DESC
LIMIT 5;
