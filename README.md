**FNB Case study(salescasestudy)**

**Author:** Kagiso Matenchi

## Overview

This project analyzes simulated daily sales data for a single product sold at one large retail store, covering **30 December 2013 to 16 November 2016** (1,053 trading days). The dataset tracks daily Sales, Cost of Sales, and Quantity Sold, and the goal was to answer a set of core business questions around pricing, profitability, seasonality, and promotional effectiveness — then present the findings as a static report, a formal presentation, and a live interactive dashboard.

Core questions addressed:
1. What is the daily sales price per unit, and how does it vary?
2. What is the average unit sales price of the product?
3. What is the daily gross profit percentage?
4. Is gross profit % the same when calculated per unit vs. in aggregate?
5. How elastic is demand during promotional periods, and does the product perform better or worse at a promotional price?

Plus additional exploratory analysis: seasonality (year-over-year and day-of-week patterns), the price-vs-quantity relationship, and a full-dataset comparison of promotional vs. non-promotional days.

## Approach

1. **Data cleaning & feature engineering** — Started from the raw daily sales data and derived: price per unit, cost per unit, gross profit, gross profit %, day-of-week, weekend flag, and a rolling-average-based promotional flag (`promo_candidate`) built from price-drop + quantity-spike detection against a trailing average.
2. **Core metrics calculation** — Computed daily and aggregate versions of price and gross profit %, and confirmed algebraically that gross profit % and gross profit % per unit are mathematically identical (difference under 1e-10 across all 1,053 days).
3. **Promotional period identification** — Isolated the three longest contiguous promotional runs in the data and benchmarked each against a 30-day non-promotional baseline immediately preceding it, calculating price elasticity of demand (PED) for each.
4. **Full-dataset validation** — Cross-checked the 3-period elasticity finding against all 128 promotional days vs. 925 non-promotional days in the dataset, to confirm the pattern held at scale and wasn't specific to the three chosen periods.
5. **Reporting** — Built the analysis into a PDF report, a formatted Word-style build guide, a Power BI dashboard (using the cleaned Excel export), a PowerPoint presentation for stakeholders, and a live interactive web dashboard for self-service exploration.

## Key Insights

- **Overall performance:** The product ran at a slight net loss over the full period — **-3.81% overall gross profit**, on **R186.9m** in total sales and **5,279,872** units sold, at a volume-weighted average price of **R35.40**.
- **Turnaround in progress:** 2014–2015 were consistently loss-making, but 2016 is the first year with a positive average gross profit margin, with 4 of the last 5 months of available data profitable — a clear sign of improving pricing/cost discipline.
- **Demand is highly price elastic:** Across three tested promotional periods, price cuts of 10–15% drove 50–170% more units sold per day (PED between -5.3 and -14.3).
- **But promotions are currently unprofitable:** In every single tested period, gross profit % flipped from positive at baseline (+2.0% to +4.6%) to negative during the promotion (-5.9% to -13.1%). This held at full-dataset scale too — 128 promotional days averaged 67% more units sold at a 6% lower price, but average gross profit % flipped from +0.04% (non-promo, roughly breakeven) to -7.5% (promo).
- **Seasonality:** Saturdays generate the highest average daily sales (~R279k), about 25% above the weekday average, though weekend sales carry thinner margins. Price and quantity are strongly negatively correlated (r ≈ -0.62), while price and gross profit % are strongly positively correlated (r ≈ +0.64) — higher prices protect margin, as expected.
- **Recommendation:** Test shallower promotional discounts (roughly half the current depth). Given how elastic demand is, a smaller markdown should still generate a strong volume response while protecting — rather than erasing — gross margin.

## Tools Used

| Tool | Purpose |
|---|---|
| **Excel** | Source data cleaning and the underlying daily dataset (`Sales_CaseStudy_Cleaned_.xlsx`) |
| **Databricks(SQL)** | Data validation, aggregation, and cross-checking all reported figures against the raw data  and also for data visualization|
| **Power BI** | Interactive dashboard build — KPI cards, monthly trend charts, promo period analysis, DAX measures |
| **PowerPoint (native charts)** | Stakeholder-ready presentation deck summarizing the full case study |
| **Lovable** | Live, browser-based interactive dashboard with file upload, filtering, and live-updating charts |
| **Miro** | For project planning 
| **Canva** | to create a project gantt chart
|**Google Looker Studio** | To create dashboard presentation

**And Lastly i have also created a data agent on databrciks to validate my findings from the given data**
## Links

- **Live Dashboard:** [sales-pulse-dash-43.lovable.app](https://sales-pulse-dash-43.lovable.app)
- **Data source:** Sales Case Study (cleaned), 30 Dec 2013 – 16 Nov 2016, simulated data for one product at a single retail store
