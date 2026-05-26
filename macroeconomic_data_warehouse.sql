/* ============================================================
TITLE: SQLite Data Warehouse for Macroeconomic Indicators
DESCRIPTION: Portfolio version of a star-schema warehouse for GDP growth, PPP expenditure, and productivity analysis.
============================================================ */
   
   PRAGMA foreign_keys = ON;
/* ---------- 1. STAGING IMPORT ----------*/
   File -> ImPORT -> Table from CSV File
   
/* ---------- RENAME IMPORTED TABLES --------= */

ALTER TABLE "GDP Growth Dataset" RENAME TO staging_gdp;

ALTER TABLE "PPP detailed results, Nominal expenditure as a percentage of GDP"
RENAME TO staging_ppp;

ALTER TABLE "Productivity by Industry Dataset" RENAME TO staging_prod;

/* ---------- 2. STAR SCHEMA DDL ---------- */
CREATE TABLE dim_country (
  country_id   INTEGER PRIMARY KEY,
  country_code TEXT NOT NULL UNIQUE,
  country_name TEXT NOT NULL
);

CREATE TABLE dim_time (
  time_id  INTEGER PRIMARY KEY,
  year     INTEGER NOT NULL UNIQUE
);

CREATE TABLE dim_measure (
  measure_id   INTEGER PRIMARY KEY,
  measure_code TEXT NOT NULL UNIQUE,
  measure_name TEXT NOT NULL
);

CREATE TABLE dim_activity (
  activity_id   INTEGER PRIMARY KEY,
  activity_code TEXT NOT NULL UNIQUE,
  activity_name TEXT NOT NULL
);

CREATE TABLE fact_gdp_growth (
  country_id INTEGER NOT NULL,
  time_id    INTEGER NOT NULL,
  measure_id INTEGER NOT NULL,
  gdp_growth REAL,
  FOREIGN KEY(country_id) REFERENCES dim_country(country_id),
  FOREIGN KEY(time_id)    REFERENCES dim_time(time_id),
  FOREIGN KEY(measure_id) REFERENCES dim_measure(measure_id)
);

CREATE TABLE fact_ppp_expenditure (
  country_id      INTEGER NOT NULL,
  time_id         INTEGER NOT NULL,
  measure_id      INTEGER NOT NULL,
  activity_id     INTEGER NOT NULL,
  expenditure_pct REAL,
  FOREIGN KEY(country_id)  REFERENCES dim_country(country_id),
  FOREIGN KEY(time_id)     REFERENCES dim_time(time_id),
  FOREIGN KEY(measure_id)  REFERENCES dim_measure(measure_id),
  FOREIGN KEY(activity_id) REFERENCES dim_activity(activity_id)
);

CREATE TABLE fact_productivity (
  country_id         INTEGER NOT NULL,
  time_id            INTEGER NOT NULL,
  measure_id         INTEGER NOT NULL,
  activity_id        INTEGER NOT NULL,
  productivity_value REAL,
  FOREIGN KEY(country_id)  REFERENCES dim_country(country_id),
  FOREIGN KEY(time_id)     REFERENCES dim_time(time_id),
  FOREIGN KEY(measure_id)  REFERENCES dim_measure(measure_id),
  FOREIGN KEY(activity_id) REFERENCES dim_activity(activity_id)
);

/* ---------- 3. POPULATE DIMENSIONS ---------- */
INSERT OR IGNORE INTO dim_country (country_code, country_name)
SELECT DISTINCT REF_AREA, "Reference area" FROM staging_gdp
UNION
SELECT DISTINCT REF_AREA, "Reference area" FROM staging_ppp
UNION
SELECT DISTINCT REF_AREA, "Reference area" FROM staging_prod;

INSERT OR IGNORE INTO dim_time (year)
SELECT DISTINCT CAST(TIME_PERIOD AS INTEGER) FROM staging_gdp
UNION
SELECT DISTINCT CAST(TIME_PERIOD AS INTEGER) FROM staging_ppp
UNION
SELECT DISTINCT CAST(TIME_PERIOD AS INTEGER) FROM staging_prod;

INSERT OR IGNORE INTO dim_measure (measure_code, measure_name)
SELECT DISTINCT MEASURE, COALESCE("Measure_name", MEASURE) FROM staging_gdp
UNION
SELECT DISTINCT MEASURE, COALESCE("Measure_name", MEASURE) FROM staging_ppp
UNION
SELECT DISTINCT MEASURE, COALESCE("Measure_name", MEASURE) FROM staging_prod;

INSERT OR IGNORE INTO dim_activity (activity_code, activity_name)
SELECT DISTINCT ANALYTICAL_CATEGORIES, "Analytical_categories_name"
FROM staging_ppp
WHERE ANALYTICAL_CATEGORIES IS NOT NULL
UNION
SELECT DISTINCT ACTIVITY, "Economic activity"
FROM staging_prod
WHERE ACTIVITY IS NOT NULL;

/* ---------- 4. POPULATE FACTS (cast types + simple filters ---------- */ 
INSERT INTO fact_gdp_growth (country_id, time_id, measure_id, gdp_growth)
SELECT dc.country_id,
       dt.time_id,
       dm.measure_id,
       CAST(s.OBS_VALUE AS REAL)
FROM staging_gdp s
JOIN dim_country dc ON dc.country_code = s.REF_AREA
JOIN dim_time    dt ON dt.year        = CAST(s.TIME_PERIOD AS INTEGER)
JOIN dim_measure dm ON dm.measure_code = s.MEASURE
WHERE s.MEASURE = 'GDPV_ANNPCT'             -- real GDP growth, annual %
  AND s.OBS_VALUE NOT IN ('', 'NA');

INSERT INTO fact_ppp_expenditure (country_id, time_id, measure_id, activity_id, expenditure_pct)
SELECT dc.country_id,
       dt.time_id,
       dm.measure_id,
       da.activity_id,
       CAST(s.OBS_VALUE AS REAL)
FROM staging_ppp s
JOIN dim_country  dc ON dc.country_code  = s.REF_AREA
JOIN dim_time     dt ON dt.year          = CAST(s.TIME_PERIOD AS INTEGER)
JOIN dim_measure  dm ON dm.measure_code  = s.MEASURE    -- expect NE_GDP
JOIN dim_activity da ON da.activity_code = s.ANALYTICAL_CATEGORIES
WHERE s.MEASURE = 'NE_GDP'                          -- nominal expenditure as % of GDP
  AND s.OBS_VALUE NOT IN ('', 'NA');

INSERT INTO fact_productivity (country_id, time_id, measure_id, activity_id, productivity_value)
SELECT dc.country_id,
       dt.time_id,
       dm.measure_id,
       da.activity_id,
       CAST(s.OBS_VALUE AS REAL)
FROM staging_prod s
JOIN dim_country  dc ON dc.country_code  = s.REF_AREA
JOIN dim_time     dt ON dt.year          = CAST(s.TIME_PERIOD AS INTEGER)
JOIN dim_measure  dm ON dm.measure_code  = s.MEASURE   -- expect GVAHRS
JOIN dim_activity da ON da.activity_code = s.ACTIVITY
WHERE s.MEASURE = 'GVAHRS'            -- gross value added per hour worked
  AND s.TRANSFORMATION = 'GY'         -- keep consistent with your CSV
  AND s.UNIT_MEASURE   = 'PA'         -- as per your file
  AND s.OBS_VALUE NOT IN ('', 'NA');
  

/* ---------- 5. VALIDATION CHECKS ---------- */
/* INDEXES */
CREATE INDEX IF NOT EXISTS idx_gdp  ON fact_gdp_growth(country_id, time_id);
CREATE INDEX IF NOT EXISTS idx_ppp  ON fact_ppp_expenditure(country_id, time_id, activity_id);
CREATE INDEX IF NOT EXISTS idx_prod ON fact_productivity(country_id, time_id, activity_id);

/* QA COUNTS */
SELECT 'dim_country', COUNT(*) FROM dim_country
UNION ALL SELECT 'dim_time', COUNT(*) FROM dim_time
UNION ALL SELECT 'dim_measure', COUNT(*) FROM dim_measure
UNION ALL SELECT 'dim_activity', COUNT(*) FROM dim_activity
UNION ALL SELECT 'fact_gdp_growth', COUNT(*) FROM fact_gdp_growth
UNION ALL SELECT 'fact_ppp_expenditure', COUNT(*) FROM fact_ppp_expenditure
UNION ALL SELECT 'fact_productivity', COUNT(*) FROM fact_productivity;

SELECT * FROM fact_gdp_growth LIMIT 5;
SELECT * FROM fact_ppp_expenditure LIMIT 5;
SELECT * FROM fact_productivity LIMIT 5;

/* ---------- . ANALYTICAL QUERIES ---------- */
/* ------------------------------------------------------------
   Q1) NZ vs OECD (overlap 2022): rank by GDP growth & PPP
   How to use: two leaderboards / highlight NZ.
   ------------------------------------------------------------ */

WITH
params AS (
  SELECT 2022 AS target_year, 'NZL' AS anchor_iso   -- change year/anchor here
),
yr AS (
  SELECT dt.time_id
  FROM dim_time dt, params p
  WHERE dt.year = p.target_year
),
nz AS (
  SELECT d.country_id
  FROM dim_country d, params p
  WHERE d.country_code = p.anchor_iso
),
g AS (
  SELECT country_id, gdp_growth
  FROM fact_gdp_growth
  WHERE time_id = (SELECT time_id FROM yr)
),
p AS (
  SELECT country_id, AVG(expenditure_pct) AS ppp_pct
  FROM fact_ppp_expenditure
  WHERE time_id = (SELECT time_id FROM yr)
  GROUP BY country_id
),
joined AS (
  SELECT g.country_id, g.gdp_growth, p.ppp_pct
  FROM g
  LEFT JOIN p USING(country_id)  -- keep GDP rows even if PPP is missing
)
SELECT dc.country_name         AS "Country",
       ROUND(j.gdp_growth,2)   AS "GDP Growth (%)",
       ROUND(j.ppp_pct,2)      AS "PPP Investment (% of GDP)",
       RANK() OVER (ORDER BY j.gdp_growth DESC) AS "Rank by GDP Growth (2022)",
       RANK() OVER (ORDER BY j.ppp_pct  DESC)   AS "Rank by PPP Investment (2022)",
       CASE WHEN dc.country_id=(SELECT country_id FROM nz) 
            THEN 'New Zealand' ELSE 'Other Countries' END AS "Group"
FROM joined j
JOIN dim_country dc USING(country_id)
ORDER BY "Rank by GDP Growth (2022)";


/* ------------------------------------------------------------
   Q2) Trend: NZ GDP growth vs OECD average (all years)
   How to use: line chart with two series + (optional) difference.
   ------------------------------------------------------------ */

WITH params AS (SELECT 'NZL' AS COUNTRY_CODE),
nz AS (
  SELECT country_id 
  FROM dim_country d, params p
  WHERE d.country_code = p.COUNTRY_CODE
)
SELECT 
    t.year                                      AS "Year",
    ROUND(AVG(CASE WHEN f.country_id=(SELECT country_id FROM nz) 
                   THEN f.gdp_growth END), 2)   AS "New Zealand GDP Growth (%)",
    ROUND(AVG(CASE WHEN f.country_id!=(SELECT country_id FROM nz) 
                   THEN f.gdp_growth END), 2)   AS "OECD Average GDP Growth (%)",
    ROUND(
         AVG(CASE WHEN f.country_id=(SELECT country_id FROM nz) 
                  THEN f.gdp_growth END)
       - AVG(CASE WHEN f.country_id!=(SELECT country_id FROM nz) 
                  THEN f.gdp_growth END)
    ,2)                                         AS "NZ and OECD Growth Difference (%)"
FROM fact_gdp_growth f
JOIN dim_time t ON t.time_id = f.time_id
GROUP BY t.year
ORDER BY t.year;

/* ------------------------------------------------------------
  Q3: NZ correlation between PPP Investment share (A05) 
  and GDP growth + NZ rank vs others
 ------------------------------------------------------------ */
WITH invest AS (
  SELECT f.country_id, t.year, f.expenditure_pct AS invest_pct
  FROM fact_ppp_expenditure f
  JOIN dim_activity da ON da.activity_id = f.activity_id
  JOIN dim_time t      ON t.time_id = f.time_id
  WHERE da.activity_code = 'A05'
),
gdp AS (
  SELECT fg.country_id, t.year, fg.gdp_growth
  FROM fact_gdp_growth fg
  JOIN dim_time t ON t.time_id = fg.time_id
),
pairs2 AS (
  SELECT i.country_id, i.year, i.invest_pct, g.gdp_growth
  FROM invest i 
  JOIN gdp g USING(country_id, year)
),
stats2 AS (
  SELECT country_id, 
         COUNT(*) AS N, 
         SUM(invest_pct) AS si, 
         SUM(gdp_growth) AS sg,
         SUM(invest_pct*gdp_growth) AS sxy, 
         SUM(invest_pct*invest_pct) AS sxx,
         SUM(gdp_growth*gdp_growth) AS syy
  FROM pairs2 
  GROUP BY country_id 
  HAVING COUNT(*) >= 2
),
corr2 AS (
  SELECT country_id, N,
         (N*sxy - si*sg) / NULLIF(SQRT((N*sxx - si*si)*(N*syy - sg*sg)), 0.0) AS corr_inv_vs_gdp
  FROM stats2
),
ranked AS (
  SELECT c.country_code             AS "Country Code",
         c.country_name             AS "Country Name",
         corr2.N                    AS "Years of Data Used",
         ROUND(corr2.corr_inv_vs_gdp, 3) AS "Correlation (PPP Investment vs GDP Growth)",
         RANK() OVER (ORDER BY corr2.corr_inv_vs_gdp DESC) AS "Rank by Correlation",
         COUNT(*) OVER ()           AS "Total Countries"
  FROM corr2 
  JOIN dim_country c USING (country_id)
)
SELECT *
FROM ranked
WHERE "Country Code" = 'NZL' OR "Country Name" = 'New Zealand';


/* ------------------------------------------------------------
    Quick sanity checks
   ------------------------------------------------------------ */

-- Coverage per fact
SELECT 'GDP years',   COUNT(DISTINCT t.year) FROM fact_gdp_growth fg JOIN dim_time t ON t.time_id=fg.time_id
UNION ALL
SELECT 'PPP years',   COUNT(DISTINCT t.year) FROM fact_ppp_expenditure fp JOIN dim_time t ON t.time_id=fp.time_id
UNION ALL
SELECT 'PROD years',  COUNT(DISTINCT t.year) FROM fact_productivity    f  JOIN dim_time t ON t.time_id=f.time_id;

