/* =============================================================================
   SALES CASE STUDY — PRICING, PROFITABILITY & PRICE ELASTICITY OF DEMAND
   =============================================================================
   Dataset : Daily aggregated Sales, Cost of Sales, and Quantity Sold for a
             single product at a single retail store (1,053 days,
             2013-12-30 to 2016-11-16).

   Objective:
     1. Derive daily sales price per unit and average unit sales price
     2. Derive daily % gross profit and % gross profit per unit
     3. Identify 3 promotional periods and calculate Price Elasticity of
        Demand (PED) for each
     4. Assess whether the product performs better or worse when sold at a
        promotional price

   Platform  : Databricks SQL
   Source    : sales_casestudy.sales_data.sales_case_study_2021
   Output    : sales_casestudy.sales_data.sales_case_study_clean
   ============================================================================= */


/* -----------------------------------------------------------------------
   SECTION 1 — DATA QUALITY CHECKS
   Confirms the raw data is safe to build on before deriving anything.
   ----------------------------------------------------------------------- */

-- Row count and date range
SELECT
  COUNT(*)                                            AS row_count,
  MIN(`Date`)                                         AS min_date,
  MAX(`Date`)                                         AS max_date,
  DATEDIFF(MAX(`Date`), MIN(`Date`)) + 1               AS expected_daily_rows,
  (DATEDIFF(MAX(`Date`), MIN(`Date`)) + 1) - COUNT(*)  AS missing_days
FROM sales_casestudy.sales_data.sales_case_study_2021;

-- Missing values per column
SELECT
  SUM(CASE WHEN `Date` IS NULL THEN 1 ELSE 0 END)          AS null_date,
  SUM(CASE WHEN `Sales` IS NULL THEN 1 ELSE 0 END)         AS null_sales,
  SUM(CASE WHEN `Cost Of Sales` IS NULL THEN 1 ELSE 0 END) AS null_cost_of_sales,
  SUM(CASE WHEN `Quantity Sold` IS NULL THEN 1 ELSE 0 END) AS null_quantity_sold
FROM sales_casestudy.sales_data.sales_case_study_2021;

-- Duplicate dates
SELECT `Date`, COUNT(*) AS occurrences
FROM sales_casestudy.sales_data.sales_case_study_2021
GROUP BY `Date`
HAVING COUNT(*) > 1;

-- Invalid rows: zero/negative sales or quantity, negative cost
SELECT *
FROM sales_casestudy.sales_data.sales_case_study_2021
WHERE `Sales` <= 0
   OR `Quantity Sold` <= 0
   OR `Cost Of Sales` < 0;


/* -----------------------------------------------------------------------
   SECTION 2 — BUILD CLEANED TABLE WITH DERIVED METRICS
   price_per_unit, gross_profit_pct, gross_profit_pct_per_unit, date
   helper columns, and a first-pass promo-candidate flag based on a
   14-day trailing rolling average (price down >5% & quantity up >10%).

   Note: gross_profit_pct and gross_profit_pct_per_unit are mathematically
   identical for this single-product daily dataset (quantity cancels out
   of both numerator and denominator) — both are retained to match the
   case study's stated deliverables.
   ----------------------------------------------------------------------- */

CREATE OR REPLACE TABLE sales_casestudy.sales_data.sales_case_study_clean AS
WITH base AS (
  SELECT
    CAST(`Date` AS DATE)              AS date,
    CAST(`Sales` AS DOUBLE)           AS sales,
    CAST(`Cost Of Sales` AS DOUBLE)   AS cost_of_sales,
    CAST(`Quantity Sold` AS BIGINT)   AS quantity_sold
  FROM sales_casestudy.sales_data.sales_case_study_2021
  WHERE `Sales` > 0
    AND `Quantity Sold` > 0
    AND `Cost Of Sales` >= 0
),
metrics AS (
  SELECT
    *,
    sales / quantity_sold                                      AS price_per_unit,
    cost_of_sales / quantity_sold                               AS cost_per_unit,
    (sales - cost_of_sales)                                     AS gross_profit,
    (sales - cost_of_sales) / sales                             AS gross_profit_pct,
    ((sales / quantity_sold) - (cost_of_sales / quantity_sold))
      / (sales / quantity_sold)                                  AS gross_profit_pct_per_unit,
    YEAR(date)                                                  AS year,
    MONTH(date)                                                 AS month,
    WEEKOFYEAR(date)                                            AS week_of_year,
    DATE_FORMAT(date, 'EEEE')                                   AS day_of_week,
    CASE WHEN DAYOFWEEK(date) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend
  FROM base
),
with_rolling AS (
  SELECT
    *,
    AVG(price_per_unit) OVER (
      ORDER BY date ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
    ) AS price_rolling_avg,
    AVG(quantity_sold) OVER (
      ORDER BY date ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
    ) AS qty_rolling_avg
  FROM metrics
)
SELECT
  *,
  (price_per_unit - price_rolling_avg) / price_rolling_avg  AS price_drop_pct,
  (quantity_sold - qty_rolling_avg) / qty_rolling_avg        AS qty_spike_pct,
  CASE
    WHEN (price_per_unit - price_rolling_avg) / price_rolling_avg < -0.05
     AND (quantity_sold - qty_rolling_avg) / qty_rolling_avg > 0.10
    THEN TRUE ELSE FALSE
  END AS promo_candidate
FROM with_rolling;


/* -----------------------------------------------------------------------
   SECTION 3 — IDENTIFY DISCRETE PROMO PERIODS
   Gaps-and-islands technique: collapses consecutive promo-candidate days
   into continuous date ranges, ranked by duration and quantity spike.
   ----------------------------------------------------------------------- */

WITH candidates AS (
  SELECT date, price_per_unit, quantity_sold, price_drop_pct, qty_spike_pct
  FROM sales_casestudy.sales_data.sales_case_study_clean
  WHERE promo_candidate = TRUE
),
islands AS (
  SELECT
    *,
    DATE_SUB(date, CAST(ROW_NUMBER() OVER (ORDER BY date) AS INT)) AS island_id
  FROM candidates
),
periods AS (
  SELECT
    island_id,
    MIN(date)                           AS period_start,
    MAX(date)                           AS period_end,
    DATEDIFF(MAX(date), MIN(date)) + 1  AS period_length_days,
    COUNT(*)                            AS candidate_days_in_period,
    ROUND(AVG(price_drop_pct) * 100, 2) AS avg_price_drop_pct,
    ROUND(AVG(qty_spike_pct) * 100, 2)  AS avg_qty_spike_pct,
    ROUND(AVG(price_per_unit), 2)       AS avg_price_per_unit,
    SUM(quantity_sold)                  AS total_quantity_sold
  FROM islands
  GROUP BY island_id
)
SELECT *
FROM periods
ORDER BY period_length_days DESC, avg_qty_spike_pct DESC;


/* -----------------------------------------------------------------------
   SECTION 4 — PRICE ELASTICITY OF DEMAND FOR THE 3 CHOSEN PERIODS
   Baseline = average price/quantity in the 14 days immediately before
   each promo period starts. PED = %change in quantity / %change in price.

   Chosen periods (selected for the strongest combined price-drop +
   quantity-spike signal, sustained over 8+ days):
     Period 1 : 2016-05-24 to 2016-06-03 (11 days)
     Period 2 : 2015-09-23 to 2015-10-02 (10 days)
     Period 3 : 2016-08-10 to 2016-08-17 (8 days)
   ----------------------------------------------------------------------- */

WITH tagged AS (
  SELECT
    date,
    price_per_unit,
    quantity_sold,
    gross_profit_pct,
    CASE
      WHEN date BETWEEN '2016-05-10' AND '2016-06-03' THEN 'Period 1'
      WHEN date BETWEEN '2015-09-09' AND '2015-10-02' THEN 'Period 2'
      WHEN date BETWEEN '2016-07-27' AND '2016-08-17' THEN 'Period 3'
    END AS period_label,
    CASE
      WHEN date BETWEEN '2016-05-10' AND '2016-05-23' THEN 'baseline'
      WHEN date BETWEEN '2016-05-24' AND '2016-06-03' THEN 'promo'
      WHEN date BETWEEN '2015-09-09' AND '2015-09-22' THEN 'baseline'
      WHEN date BETWEEN '2015-09-23' AND '2015-10-02' THEN 'promo'
      WHEN date BETWEEN '2016-07-27' AND '2016-08-09' THEN 'baseline'
      WHEN date BETWEEN '2016-08-10' AND '2016-08-17' THEN 'promo'
    END AS window_label
  FROM sales_casestudy.sales_data.sales_case_study_clean
),
agg AS (
  SELECT
    period_label,
    window_label,
    COUNT(*)               AS n_days,
    AVG(price_per_unit)    AS avg_price,
    AVG(quantity_sold)     AS avg_qty,
    AVG(gross_profit_pct)  AS avg_gp_pct
  FROM tagged
  WHERE period_label IS NOT NULL
  GROUP BY period_label, window_label
)
SELECT
  b.period_label,
  b.n_days                                                                       AS baseline_days,
  pr.n_days                                                                      AS promo_days,
  ROUND(b.avg_price, 2)                                                          AS baseline_avg_price,
  ROUND(pr.avg_price, 2)                                                         AS promo_avg_price,
  ROUND((pr.avg_price - b.avg_price) / b.avg_price * 100, 2)                     AS pct_change_price,
  ROUND(b.avg_qty, 0)                                                            AS baseline_avg_qty,
  ROUND(pr.avg_qty, 0)                                                           AS promo_avg_qty,
  ROUND((pr.avg_qty - b.avg_qty) / b.avg_qty * 100, 2)                           AS pct_change_qty,
  ROUND(
    ((pr.avg_qty - b.avg_qty) / b.avg_qty) / ((pr.avg_price - b.avg_price) / b.avg_price),
    2
  )                                                                               AS price_elasticity_of_demand,
  ROUND(b.avg_gp_pct * 100, 2)                                                   AS baseline_avg_gp_pct,
  ROUND(pr.avg_gp_pct * 100, 2)                                                  AS promo_avg_gp_pct
FROM agg b
JOIN agg pr
  ON pr.period_label = b.period_label
 AND pr.window_label = 'promo'
WHERE b.window_label = 'baseline'
ORDER BY b.period_label;


/* -----------------------------------------------------------------------
   SECTION 5 — FULL CLEANED TABLE (for export / downstream visualization)
   ----------------------------------------------------------------------- */

SELECT *
FROM sales_casestudy.sales_data.sales_case_study_clean
ORDER BY date;

