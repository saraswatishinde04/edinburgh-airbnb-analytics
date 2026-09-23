# Data

Raw data files are **intentionally not committed** to this repository (see `.gitignore`), in line with standard practice for large/third-party-licensed datasets.

## Expected structure

```
data/
├── raw/
│   ├── listings.csv
│   ├── hosts.csv
│   ├── calendar.csv          # daily availability, two scrape snapshots
│   └── reviews.csv           # review-level, rolled up to monthly in SQL
└── processed/                # optional: exported query results, extracts
```

## Sourcing the data

1. Add the exact source, URL, and licence terms in [`../docs/methodology.md`](../docs/methodology.md) Section 1.
2. Download the raw extracts for **Edinburgh, Scotland** covering:
   - Listings and host attributes (current snapshot)
   - Calendar/availability at daily grain across two scrape dates (23 June 2026 and 2 July 2026, per this project)
   - Reviews with per-review dates, covering full calendar years 2015–2025
3. Place the files in `data/raw/` using the file names above (or update `sql/01_staging_load.sql` to match your actual file names).

## Notes

- If your data source has usage restrictions (e.g. non-commercial use, attribution requirements), reproduce them in the main [`README.md`](../README.md) License section.
- Do not commit personally identifiable host information beyond what the original source already makes public.
