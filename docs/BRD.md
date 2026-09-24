# Business Requirements Document (BRD)
## Edinburgh Airbnb Market Analytics

| | |
|---|---|
| **Document version** | 1.0 |
| **Status** | Final |
| **Prepared for** | Market Analytics / Strategy Stakeholders |
| **Prepared by** | Saraswati Shinde |
| **Date** | September 2026 |

---

## 1. Executive Summary

Edinburgh's short-term letting (STL) sector has grown substantially since 2015 and is now subject to Scotland's mandatory **STL Licensing Scheme**, which requires every host operating a short-term let to hold a registered licence number. This creates a pressing need — for hosts, platform teams, tourism boards, and city regulators alike — to understand the size, geographic distribution, seasonality, and ownership structure of the Edinburgh Airbnb market.

This project delivers a **data-driven market intelligence solution**: a MySQL analytical data model built from listings, host, calendar, and review-level data, paired with an interactive Tableau dashboard that lets stakeholders explore the market by neighbourhood, room type, and time period.

---

## 2. Business Background & Problem Statement

- Edinburgh attracts high, seasonally concentrated tourist demand (Fringe Festival, Hogmanay, summer season), making short-term letting a significant part of the city's visitor accommodation supply.
- Regulatory change (STL licensing) has shifted the competitive and compliance landscape, particularly for multi-listing "portfolio" hosts.
- Prior to this project, market data existed only as raw, disconnected extracts with no standardized model, no repeatable reporting layer, and no self-service dashboard — making it difficult to answer basic strategic questions quickly or consistently.

**Core problem:** Stakeholders lack a single, trustworthy, refreshable view of *market size, geographic concentration, seasonal demand, and host structure* to support strategic and operational decisions.

---

## 3. Business Objectives

| # | Objective |
|---|---|
| BO-1 | Quantify the overall size and composition of the Edinburgh Airbnb market (listings, hosts, room types, ratings). |
| BO-2 | Identify which neighbourhoods drive the most supply, revenue, and occupancy. |
| BO-3 | Understand seasonal demand patterns to support pricing, staffing, and marketing timing decisions. |
| BO-4 | Profile host structure — distinguishing individual hosts from multi-listing operators — and assess licensing compliance by host size. |
| BO-5 | Deliver these insights through a reusable, filterable, self-service dashboard rather than one-off static reports. |

---

## 4. Scope

### 4.1 In Scope
- Historical and current Airbnb listing, host, calendar/availability, and review data for **Edinburgh, Scotland**.
- Data cleaning, modelling, and transformation in MySQL.
- Analytical SQL answering the questions defined in Section 5.
- A 3-page interactive Tableau dashboard (Overview, Area, Host).
- Supporting documentation (this BRD, data dictionary, methodology).

### 4.2 Out of Scope
- Real-time / live-streaming data ingestion (the project is based on point-in-time scrape snapshots).
- Predictive modelling or forecasting (descriptive/diagnostic analytics only).
- Data for cities other than Edinburgh.
- Legal interpretation of STL licensing requirements (STL licence *number presence* is reported as a data field only, not a compliance determination).

---

## 5. Functional Requirements

Requirements are organized into four analytical "chapters," matching the structure of the SQL story (`sql/03_edinburgh_story.sql`).

### Chapter 1 — How Big Is the Market?
| ID | Requirement |
|---|---|
| FR-1.1 | Report total active listings and distinct hosts. |
| FR-1.2 | Report the share of listings that are "Entire home/apt" vs. other room types. |
| FR-1.3 | Report the share of listings operated by Superhosts. |
| FR-1.4 | Report the average review rating across the market. |
| FR-1.5 | Flag listings missing a price, to quantify data completeness/market gaps. |

### Chapter 2 — Where Is the Supply?
| ID | Requirement |
|---|---|
| FR-2.1 | Rank neighbourhoods by listing count, with share of total and cumulative share. |
| FR-2.2 | Provide a reusable neighbourhood scorecard (listings, average estimated revenue, average estimated occupancy, average rating) as a persisted SQL view for downstream BI tools. |
| FR-2.3 | Rank neighbourhoods by estimated annual revenue. |

### Chapter 3 — When Does Demand Peak?
| ID | Requirement |
|---|---|
| FR-3.1 | Calculate a monthly seasonality index (2023–2025 full years) where 1.00 = an average month. |
| FR-3.2 | Report forward-looking availability by month, excluding any month that is incomplete across the two scrape snapshots to avoid bias. |

### Chapter 4 — Who Runs the Market?
| ID | Requirement |
|---|---|
| FR-4.1 | Segment hosts into size bands (single listing, 2–5, 6–20, 21+) and report listing share vs. revenue share per band. |
| FR-4.2 | Report STL licence number presence/absence by host size band. |
| FR-4.3 | Compare Superhosts vs. non-Superhosts on average rating and average estimated revenue. |

### Dashboard Requirements
| ID | Requirement |
|---|---|
| FR-5.1 | Provide headline KPI cards (listings, hosts, median price, % Superhost). |
| FR-5.2 | Provide filters for review month, neighbourhood name, and room type, applied consistently across relevant charts. |
| FR-5.3 | Provide a geographic view of listings by estimated occupancy and by revenue. |
| FR-5.4 | Provide host-size and Superhost comparison visuals. |

---

## 6. Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | All SQL logic must be reproducible end-to-end from raw source files to final views. |
| NFR-2 | Queries must return results for the full dataset in well under 5 seconds on standard hardware (evidenced by sub-0.5-second execution times observed during development). |
| NFR-3 | The dashboard must load and filter interactively without noticeable lag for end users. |
| NFR-4 | All documentation must be version-controlled alongside the code (Git/GitHub). |
| NFR-5 | Sensitive/raw personal data (if any host-identifying fields exist) must not be committed to the public repository. |

---

## 7. Data Requirements

See [`data_dictionary.md`](data_dictionary.md) for full field definitions. At minimum, the source data must provide:
- Listing-level attributes (room type, price, neighbourhood, ratings, license/STL number).
- Host-level attributes (host ID, Superhost flag, number of listings).
- Calendar/availability data at a daily grain, across at least two scrape snapshots.
- Review-level data with review dates, aggregated to monthly counts.

---

## 8. Assumptions & Constraints

- Data reflects two scrape snapshots (23 June 2026 and 2 July 2026); forward availability figures near the scrape date should be interpreted with caution, as they are structurally biased toward appearing busier.
- "Estimated revenue" and "estimated occupancy" are derived/modelled fields from the source data, not confirmed booking transactions, and should be labelled as estimates in all reporting.
- Neighbourhood boundaries follow the source data provider's standard geographic definitions for Edinburgh.
- STL licence number presence is used as a proxy for registration visibility in the dataset; absence of a number in the data does not necessarily confirm non-compliance.

---

## 9. Deliverables

1. MySQL scripts: staging load, data model build, and business analysis (`sql/`).
2. A persisted analytical view (`vw_neighbourhood_scorecard`) for BI reuse.
3. A 3-page Tableau dashboard (Overview, Area, Host).
4. Project documentation: README, BRD, data dictionary, methodology.

## 10. Success Criteria

- All functional requirements (Section 5) are answered by a corresponding SQL query or dashboard view.
- Stakeholders can self-serve neighbourhood- and host-level insights without needing to write SQL.
- The repository is structured so a new analyst can reproduce the entire pipeline from raw data to dashboard within one working day.

---

## 11. Stakeholders

| Role | Interest |
|---|---|
| City Tourism / Strategy Analysts | Market sizing, seasonality, neighbourhood concentration |
| Host / Property Management Operators | Revenue benchmarking, Superhost premium, competitive positioning |
| Regulatory / Licensing Stakeholders | Host size structure, licence number visibility by segment |
| Data/BI Team | Reusable data model and dashboard for ongoing reporting |
