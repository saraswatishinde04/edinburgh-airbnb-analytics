USE airbnb_analytics;

-- 1) One row per listing (6,244 rows)
CREATE OR REPLACE VIEW vw_tableau_listings AS
SELECT f.listing_id, f.listing_name, n.neighbourhood_name, f.room_type, f.property_type,
       f.accommodates, f.bedrooms, f.latitude, f.longitude,
       f.price_gbp,
       CASE WHEN f.price_gbp IS NULL THEN '0. No price'
            WHEN f.price_gbp < 100  THEN '1. Under 100'
            WHEN f.price_gbp < 200  THEN '2. 100-199'
            WHEN f.price_gbp < 300  THEN '3. 200-299'
            WHEN f.price_gbp < 500  THEN '4. 300-499'
            ELSE '5. 500+' END                                  AS price_band_gbp,
       f.availability_365, f.number_of_reviews, f.number_of_reviews_ltm,
       f.review_scores_rating, f.review_scores_location, f.review_scores_value,
       f.est_occupancy_days_365, f.est_revenue_gbp_365, f.license_status,
       h.host_id, h.host_name,
       CASE WHEN h.is_superhost = 1 THEN 'Superhost'
            WHEN h.is_superhost = 0 THEN 'Not superhost'
            ELSE 'Unknown' END                                   AS superhost_label,
       h.years_as_host, h.listings_count AS host_listings_count, h.host_size_band
FROM fact_listing f
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
JOIN dim_host h          ON h.host_id = f.host_id;

-- 2) Reviews by month x neighbourhood x room type
CREATE OR REPLACE VIEW vw_tableau_reviews_monthly AS
SELECT r.review_month, n.neighbourhood_name, f.room_type, SUM(r.review_count) AS reviews
FROM fact_reviews_monthly r
JOIN fact_listing f      ON f.listing_id = r.listing_id
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
GROUP BY r.review_month, n.neighbourhood_name, f.room_type;

-- 3) Forward availability by month x neighbourhood (only months complete for every listing)
CREATE OR REPLACE VIEW vw_tableau_availability_monthly AS
SELECT c.month_start, n.neighbourhood_name,
       SUM(c.available_days) AS available_days, SUM(c.days_in_data) AS days_in_data
FROM fact_calendar_monthly c
JOIN fact_listing f      ON f.listing_id = c.listing_id
JOIN dim_neighbourhood n ON n.neighbourhood_id = f.neighbourhood_id
WHERE c.month_start BETWEEN '2026-08-01' AND '2027-05-01'
GROUP BY c.month_start, n.neighbourhood_name;
SELECT COUNT(*) AS listings_rows FROM vw_tableau_listings;
SELECT COUNT(*) AS review_rows, SUM(reviews) AS total_reviews FROM vw_tableau_reviews_monthly;
SELECT COUNT(*) AS availability_rows FROM vw_tableau_availability_monthly;
SELECT * FROM vw_tableau_listings;
SELECT * FROM vw_tableau_reviews_monthly;
SELECT * FROM vw_tableau_availability_monthly;