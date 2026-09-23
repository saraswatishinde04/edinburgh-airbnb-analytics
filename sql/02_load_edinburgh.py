"""
Load Inside Airbnb (Edinburgh, June 2026) into MySQL staging tables.

Setup (once):   pip install pandas sqlalchemy pymysql
Run:            python 02_load_edinburgh.py --folder "C:\\path\\to\\edinburgh" --password YOUR_MYSQL_PASSWORD

--folder must contain listings, calendar and reviews as .csv or .csv.gz
(extracted files or the downloaded gz files both work).

Creates (re-runnable, tables are replaced):
  stg_listings   one row per listing, cleaned columns only
  stg_calendar   listing_id, date, available (1/0)         ~2.28M rows
  stg_reviews    review_id, listing_id, date, reviewer_id  ~676K rows (review text NOT loaded)
"""
import argparse, os, re, sys, time
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.types import Date

ap = argparse.ArgumentParser()
ap.add_argument("--folder", required=True)
ap.add_argument("--password", required=True)
ap.add_argument("--user", default="root")
ap.add_argument("--host", default="localhost")
ap.add_argument("--port", type=int, default=3306)
ap.add_argument("--database", default="airbnb_analytics")
args = ap.parse_args()

engine = create_engine(URL.create("mysql+pymysql", username=args.user, password=args.password,
                                  host=args.host, port=args.port, database=args.database,
                                  query={"charset": "utf8mb4"}))

def find(base):
    for name in (f"{base}.csv", f"{base}.csv.gz", f"{base}_csv.gz"):
        p = os.path.join(args.folder, name)
        if os.path.exists(p):
            return p
    sys.exit(f"Could not find {base}.csv / {base}.csv.gz in {args.folder}")

def yn(s):                      # 't'/'f' -> 1/0, else NULL
    return s.map({"t": 1, "f": 0}).astype("Int64")

# ---------------------------------------------------------------- listings
t0 = time.time()
KEEP = ["id", "name", "host_id", "host_name", "hosts_time_as_host_years", "host_is_superhost",
        "host_listings_count", "calculated_host_listings_count",
        "calculated_host_listings_count_entire_homes",
        "neighbourhood_cleansed", "latitude", "longitude", "property_type", "room_type",
        "accommodates", "bathrooms", "bedrooms", "beds", "price", "price_quote_checkin_date",
        "minimum_nights", "maximum_nights", "has_availability",
        "availability_30", "availability_60", "availability_90", "availability_365",
        "number_of_reviews", "number_of_reviews_ltm", "number_of_reviews_l30d", "reviews_per_month",
        "first_review", "last_review", "review_scores_rating", "review_scores_accuracy",
        "review_scores_cleanliness", "review_scores_checkin", "review_scores_communication",
        "review_scores_location", "review_scores_value", "license",
        "estimated_occupancy_l365d", "estimated_revenue_l365d", "last_scraped"]
L = pd.read_csv(find("listings"), usecols=KEEP, low_memory=False)
L = L.rename(columns={"id": "listing_id"})
# price arrives as "$225.50" but the source quote JSON says currency = GBP -> store plain number, label as GBP
L["price_gbp"] = pd.to_numeric(L["price"].astype(str).str.replace(r"[^0-9.]", "", regex=True), errors="coerce")
L = L.drop(columns=["price"])
L["host_is_superhost"] = yn(L["host_is_superhost"])
L["has_availability"] = yn(L["has_availability"])
for c in ["first_review", "last_review", "last_scraped", "price_quote_checkin_date"]:
    L[c] = pd.to_datetime(L[c], errors="coerce").dt.date
L["license"] = L["license"].astype("string").str.strip()
L.to_sql("stg_listings", engine, if_exists="replace", index=False, chunksize=1000, method="multi",
         dtype={c: Date() for c in ["first_review", "last_review", "last_scraped", "price_quote_checkin_date"]})
print(f"stg_listings: {len(L):,} rows  ({time.time()-t0:.0f}s)")

# ---------------------------------------------------------------- calendar
t0 = time.time(); n = 0; first = True
for chunk in pd.read_csv(find("calendar"), usecols=["listing_id", "date", "available"], chunksize=200_000):
    chunk["available"] = (chunk["available"] == "t").astype("int8")
    chunk["date"] = pd.to_datetime(chunk["date"]).dt.date
    chunk.to_sql("stg_calendar", engine, if_exists="replace" if first else "append", index=False,
                 chunksize=20_000, method="multi", dtype={"date": Date()})
    first = False; n += len(chunk)
    print(f"  calendar: {n:,} rows...", end="\r")
print(f"stg_calendar: {n:,} rows  ({time.time()-t0:.0f}s)          ")

# ---------------------------------------------------------------- reviews (no comment text)
t0 = time.time(); n = 0; first = True
for chunk in pd.read_csv(find("reviews"), usecols=["listing_id", "id", "date", "reviewer_id"], chunksize=200_000):
    chunk = chunk.rename(columns={"id": "review_id"})
    chunk["date"] = pd.to_datetime(chunk["date"]).dt.date
    chunk.to_sql("stg_reviews", engine, if_exists="replace" if first else "append", index=False,
                 chunksize=20_000, method="multi", dtype={"date": Date()})
    first = False; n += len(chunk)
    print(f"  reviews: {n:,} rows...", end="\r")
print(f"stg_reviews: {n:,} rows  ({time.time()-t0:.0f}s)          ")

# ---------------------------------------------------------------- indexes for the joins in 03_build_model.sql
with engine.begin() as con:
    con.execute(text("CREATE INDEX idx_cal_listing ON stg_calendar (listing_id)"))
    con.execute(text("CREATE INDEX idx_rev_listing ON stg_reviews (listing_id)"))
    con.execute(text("CREATE INDEX idx_lst_listing ON stg_listings (listing_id)"))
    for t in ("stg_listings", "stg_calendar", "stg_reviews"):
        print(t, con.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar())
print("Done. Next: run 03_build_model.sql in Workbench.")
