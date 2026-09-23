-- ============================================================
-- EDINBURGH AIRBNB (Inside Airbnb, June 2026) - star schema
-- Run after 02_load_edinburgh.py.  MySQL 8.0
-- Safe to re-run: drops and rebuilds the model tables (staging is untouched).
-- ============================================================
USE airbnb_analytics;

DROP TABLE IF EXISTS fact_reviews_monthly;
DROP TABLE IF EXISTS fact_calendar_monthly;
DROP TABLE IF EXISTS fact_listing;
DROP TABLE IF EXISTS dim_host;
DROP TABLE IF EXISTS dim_neighbourhood;

-- ---------- dim_neighbourhood (111 names, identical to the GeoJSON names) ----------
CREATE TABLE dim_neighbourhood (
  neighbourhood_id   INT AUTO_INCREMENT PRIMARY KEY,
  neighbourhood_name VARCHAR(150) NOT NULL UNIQUE
);
INSERT INTO dim_neighbourhood (neighbourhood_name)
SELECT DISTINCT neighbourhood_cleansed FROM stg_listings ORDER BY neighbourhood_cleansed;

-- ---------- dim_host ----------
CREATE TABLE dim_host (
  host_id          BIGINT PRIMARY KEY,
  host_name        VARCHAR(255),
  is_superhost     TINYINT,
  years_as_host    DECIMAL(4,1),
  listings_count   INT,             -- listings this host has in Edinburgh (this dataset)
  host_size_band   VARCHAR(20)
);
INSERT INTO dim_host (host_id, host_name, is_superhost, years_as_host, listings_count, host_size_band)
SELECT host_id, MAX(host_name), MAX(host_is_superhost), MAX(hosts_time_as_host_years), COUNT(*),
       CASE WHEN COUNT(*) = 1 THEN '1. Single listing'
            WHEN COUNT(*) <= 5 THEN '2. 2-5 listings'
            WHEN COUNT(*) <= 20 THEN '3. 6-20 listings'
            ELSE '4. 21+ listings' END
FROM stg_listings
GROUP BY host_id;

-- ---------- fact_listing ----------
CREATE TABLE fact_listing (
  listing_id        BIGINT PRIMARY KEY,
  host_id           BIGINT NOT NULL,
  neighbourhood_id  INT NOT NULL,
  listing_name      VARCHAR(500),
  property_type     VARCHAR(100),
  room_type         VARCHAR(50),
  accommodates      INT,
  bedrooms          DECIMAL(4,1),
  beds              DECIMAL(4,1),
  latitude          DOUBLE,
  longitude         DOUBLE,
  price_gbp         DECIMAL(10,2),   -- quote for ONE future stay (see price_quote_checkin_date), not a base rate
  price_quote_checkin_date DATE,
  minimum_nights    INT,
  availability_365  INT,
  number_of_reviews INT,
  number_of_reviews_ltm INT,
  reviews_per_month DOUBLE,
  first_review      DATE,
  last_review       DATE,
  review_scores_rating DOUBLE,
  review_scores_location DOUBLE,
  review_scores_value DOUBLE,
  est_occupancy_days_365 INT,        -- Inside Airbnb model estimate
  est_revenue_gbp_365    DOUBLE,     -- = price x estimated occupancy (estimate, not actual income)
  license_raw       VARCHAR(500),
  license_status    VARCHAR(30),
  FOREIGN KEY (host_id) REFERENCES dim_host (host_id),
  FOREIGN KEY (neighbourhood_id) REFERENCES dim_neighbourhood (neighbourhood_id)
);
INSERT INTO fact_listing
SELECT s.listing_id, s.host_id, n.neighbourhood_id, s.name, s.property_type, s.room_type,
       s.accommodates, s.bedrooms, s.beds, s.latitude, s.longitude,
       s.price_gbp, s.price_quote_checkin_date, s.minimum_nights, s.availability_365,
       s.number_of_reviews, s.number_of_reviews_ltm, s.reviews_per_month, s.first_review, s.last_review,
       s.review_scores_rating, s.review_scores_location, s.review_scores_value,
       s.estimated_occupancy_l365d, s.estimated_revenue_l365d,
       s.license,
       CASE WHEN s.license IS NULL OR TRIM(s.license) = ''                            THEN 'Missing'
            WHEN s.license REGEXP 'EH[^0-9]{0,4}[0-9]{4,6}'                            THEN 'Edinburgh STL number'
            WHEN LOWER(s.license) REGEXP 'pending|awaiting|application|submitted'      THEN 'Pending / applied'
            WHEN LOWER(s.license) REGEXP 'exempt|not applicable'                       THEN 'Exempt / N/A'
            ELSE 'Other reference' END
FROM stg_listings s
JOIN dim_neighbourhood n ON n.neighbourhood_name = s.neighbourhood_cleansed;

-- ---------- fact_calendar_monthly (2.28M daily rows -> listing x month) ----------
-- Calendar has NO price column in the 2026 files: availability only.
CREATE TABLE fact_calendar_monthly (
  listing_id      BIGINT NOT NULL,
  month_start     DATE NOT NULL,
  days_in_data    INT,
  available_days  INT,
  is_full_month   TINYINT,           -- first/last months are partial: filter is_full_month = 1 for trends
  PRIMARY KEY (listing_id, month_start),
  FOREIGN KEY (listing_id) REFERENCES fact_listing (listing_id)
);
INSERT INTO fact_calendar_monthly
SELECT c.listing_id, DATE_FORMAT(c.date, '%Y-%m-01'), COUNT(*), SUM(c.available),
       (COUNT(*) = DAY(LAST_DAY(MIN(c.date))))
FROM stg_calendar c
JOIN fact_listing f ON f.listing_id = c.listing_id
GROUP BY c.listing_id, DATE_FORMAT(c.date, '%Y-%m-01');

-- ---------- fact_reviews_monthly (review history = proxy for actual stays) ----------
CREATE TABLE fact_reviews_monthly (
  listing_id   BIGINT NOT NULL,
  review_month DATE NOT NULL,
  review_count INT,
  PRIMARY KEY (listing_id, review_month),
  FOREIGN KEY (listing_id) REFERENCES fact_listing (listing_id)
);
INSERT INTO fact_reviews_monthly
SELECT r.listing_id, DATE_FORMAT(r.date, '%Y-%m-01'), COUNT(*)
FROM stg_reviews r
JOIN fact_listing f ON f.listing_id = r.listing_id
GROUP BY r.listing_id, DATE_FORMAT(r.date, '%Y-%m-01');

-- ============================================================
-- VALIDATION (run each, compare with EXPECTED)
-- ============================================================
SELECT 'dim_neighbourhood' AS tbl, COUNT(*) AS n FROM dim_neighbourhood   -- 111
UNION ALL SELECT 'dim_host',              COUNT(*) FROM dim_host          -- 3669
UNION ALL SELECT 'fact_listing',          COUNT(*) FROM fact_listing      -- 6244
UNION ALL SELECT 'fact_calendar_monthly', COUNT(*) FROM fact_calendar_monthly
UNION ALL SELECT 'fact_reviews_monthly',  COUNT(*) FROM fact_reviews_monthly;

-- orphans that were dropped on purpose (calendar/review rows for listings missing from listings.csv)
SELECT (SELECT COUNT(*) FROM stg_calendar) - (SELECT SUM(days_in_data) FROM fact_calendar_monthly) AS calendar_rows_dropped,   -- 14 listings x 365 = 5110
       (SELECT COUNT(*) FROM stg_reviews)  - (SELECT SUM(review_count) FROM fact_reviews_monthly)  AS review_rows_dropped;

SELECT license_status, COUNT(*) AS listings, ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (), 1) AS pct
FROM fact_listing GROUP BY license_status ORDER BY listings DESC;
