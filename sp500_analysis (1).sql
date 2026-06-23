-- ============================================================
-- S&P 500 FINANCIAL ANALYTICS - SQL PORTFOLIO PROJECT
-- Author: Abdulrahman Jalilov
-- Dataset: S&P 500 Companies Financial Indicators (496 companies, 74 columns)
-- Source: Financial data aggregated from Yahoo Finance / Finviz
-- Database: sp500_project | Table: companies
-- ============================================================
--
-- BUSINESS PROBLEM:
-- The S&P 500 represents the 500 largest U.S. publicly traded companies
-- across 11 sectors. While the index is widely followed as a benchmark,
-- individual investors and analysts face a critical challenge: identifying
-- which sectors and companies offer the best combination of profitability,
-- financial stability, valuation, and growth potential.
--
-- This project analyzes 496 S&P 500 companies across 74 financial indicators
-- to answer three core questions:
--   1. Where is value being created? (Profitability)
--   2. Where is risk being taken?   (Valuation & Stability)
--   3. Which sectors are positioned for future growth? (Growth Analysis)
--
-- TOOLS: MySQL (analysis) → R (cleaning + forecasting) → Excel/Shiny (dashboard)
-- ============================================================

USE sp500_project;

-- ============================================================
-- HELPER NOTE ON DATA TYPES
-- All numeric columns are stored as VARCHAR because the raw data
-- contains mixed formats: "41.05B", "2336.71B", "54.50%", "-" (missing).
-- We use REPLACE() + CAST() to convert values on the fly in each query.
-- Convention used throughout:
--   - Remove 'B' (billions), 'M' (millions), 'T' (trillions), '%' signs
--   - Replace '-' (missing) with NULL using NULLIF()
--   - CAST to DECIMAL for arithmetic
-- ============================================================


-- ============================================================
-- SECTION 1: DATA QUALITY & MARKET OVERVIEW
-- ============================================================

-- ------------------------------------------------------------
-- Query 1.1: Dataset Overview
-- How many companies do we have, and what is the total market
-- capitalization represented in this dataset?
-- Market Cap classification:
--   Mega Cap  > $200B  (e.g. Apple, Microsoft)
--   Large Cap $10B-200B (most S&P 500 companies)
--   Mid Cap   $2B-10B
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_companies,
    COUNT(DISTINCT index_membership) AS distinct_index_memberships,
    -- Sum market caps (convert B/M/T to raw billions for comparison)
    ROUND(SUM(
        CASE
            WHEN market_cap LIKE '%T' THEN CAST(REPLACE(market_cap, 'T', '') AS DECIMAL(10,3)) * 1000
            WHEN market_cap LIKE '%B' THEN CAST(REPLACE(market_cap, 'B', '') AS DECIMAL(10,3))
            WHEN market_cap LIKE '%M' THEN CAST(REPLACE(market_cap, 'M', '') AS DECIMAL(10,3)) / 1000
            ELSE NULL
        END
    ), 2) AS total_market_cap_billions,
    -- Count by size tier
    SUM(CASE WHEN market_cap LIKE '%T' THEN 1
             WHEN market_cap LIKE '%B' AND CAST(REPLACE(market_cap,'B','') AS DECIMAL(10,2)) >= 200 THEN 1
             ELSE 0 END) AS mega_cap_200b_plus,
    SUM(CASE WHEN market_cap LIKE '%B'
             AND CAST(REPLACE(market_cap,'B','') AS DECIMAL(10,2)) BETWEEN 10 AND 199.99 THEN 1
             ELSE 0 END) AS large_cap_10b_200b,
    SUM(CASE WHEN market_cap LIKE '%B'
             AND CAST(REPLACE(market_cap,'B','') AS DECIMAL(10,2)) < 10 THEN 1
             WHEN market_cap LIKE '%M' THEN 1
             ELSE 0 END) AS mid_cap_under_10b
FROM companies;


-- ------------------------------------------------------------
-- Query 1.2: Companies Per Index
-- Some companies belong to multiple indices (DJIA, NDX, S&P 500).
-- The Dow Jones (DJIA) contains only 30 companies, NDX is the
-- NASDAQ-100. Membership signals the company's prestige/size tier.
-- ------------------------------------------------------------
SELECT
    index_membership,
    COUNT(*) AS company_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM companies), 2) AS pct_of_total
FROM companies
GROUP BY index_membership
ORDER BY company_count DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 1.3: Missing Value Audit
-- Financial datasets always have gaps. A '-' in this dataset
-- means the metric is not applicable or not reported.
-- We flag columns with high missing rates — these should not
-- be used in downstream analysis without caution.
-- ------------------------------------------------------------
SELECT
    'pe_ratio'            AS metric, SUM(CASE WHEN pe_ratio = '-' OR pe_ratio IS NULL THEN 1 ELSE 0 END) AS missing_count, ROUND(SUM(CASE WHEN pe_ratio = '-' OR pe_ratio IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS missing_pct FROM companies
UNION ALL SELECT 'dividend_yield', SUM(CASE WHEN dividend_yield = '-' OR dividend_yield IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN dividend_yield = '-' OR dividend_yield IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'peg_ratio', SUM(CASE WHEN peg_ratio = '-' OR peg_ratio IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN peg_ratio = '-' OR peg_ratio IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'total_debt_to_equity', SUM(CASE WHEN total_debt_to_equity = '-' OR total_debt_to_equity IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN total_debt_to_equity = '-' OR total_debt_to_equity IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'lt_growth_5y', SUM(CASE WHEN lt_growth_5y = '-' OR lt_growth_5y IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN lt_growth_5y = '-' OR lt_growth_5y IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'return_on_equity', SUM(CASE WHEN return_on_equity = '-' OR return_on_equity IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN return_on_equity = '-' OR return_on_equity IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'gross_margin', SUM(CASE WHEN gross_margin = '-' OR gross_margin IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN gross_margin = '-' OR gross_margin IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
UNION ALL SELECT 'beta', SUM(CASE WHEN beta = '-' OR beta IS NULL THEN 1 ELSE 0 END), ROUND(SUM(CASE WHEN beta = '-' OR beta IS NULL THEN 1 ELSE 0 END)*100.0/COUNT(*),1) FROM companies
ORDER BY missing_pct DESC;


-- ------------------------------------------------------------
-- Query 1.4: Top 15 Companies by Market Capitalization
-- Market Cap = Current Stock Price x Shares Outstanding
-- The largest companies have disproportionate weight in the
-- S&P 500 index (it is market-cap-weighted, not equal-weighted).
-- A small number of mega-cap companies can drive index returns.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    revenue_ttm,
    prev_close,
    CAST(REPLACE(pe_ratio, '-', '0') AS DECIMAL(10,2)) AS pe_ratio,
    gross_margin,
    return_on_equity
FROM companies
WHERE market_cap LIKE '%T'
   OR (market_cap LIKE '%B' AND CAST(REPLACE(market_cap,'B','') AS DECIMAL(10,2)) >= 100)
ORDER BY
    CASE
        WHEN market_cap LIKE '%T' THEN CAST(REPLACE(market_cap,'T','') AS DECIMAL(10,3)) * 1000
        WHEN market_cap LIKE '%B' THEN CAST(REPLACE(market_cap,'B','') AS DECIMAL(10,3))
        ELSE 0
    END DESC
LIMIT 15;


-- ============================================================
-- SECTION 2: PROFITABILITY ANALYSIS
-- ============================================================
-- Profitability ratios measure how efficiently a company
-- converts revenue into profit. Key metrics:
--   Gross Margin    = (Revenue - COGS) / Revenue
--                     How much is left after production costs
--   Operating Margin= Operating Income / Revenue
--                     Efficiency after operating expenses
--   Net Margin      = Net Income / Revenue
--                     Bottom-line profitability
--   ROE             = Net Income / Shareholders' Equity
--                     Return generated for equity holders
--   ROA             = Net Income / Total Assets
--                     How efficiently assets generate profit
--   ROI             = Net Income / Invested Capital
--                     Overall return on capital deployed
-- ============================================================

-- ------------------------------------------------------------
-- Query 2.1: Average Profitability Metrics by Index Membership
-- DJIA companies (blue chips) typically show stronger margins
-- than average S&P 500 constituents due to their dominant
-- market positions and pricing power.
-- ------------------------------------------------------------
SELECT
    index_membership,
    COUNT(*) AS companies,
    ROUND(AVG(NULLIF(CAST(REPLACE(gross_margin,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_gross_margin_pct,
    ROUND(AVG(NULLIF(CAST(REPLACE(operating_margin,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_operating_margin_pct,
    ROUND(AVG(NULLIF(CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_net_margin_pct,
    ROUND(AVG(NULLIF(CAST(REPLACE(return_on_equity,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_roe_pct,
    ROUND(AVG(NULLIF(CAST(REPLACE(return_on_assets,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_roa_pct
FROM companies
WHERE gross_margin != '-'
  AND operating_margin != '-'
  AND net_profit_margin != '-'
GROUP BY index_membership
ORDER BY avg_gross_margin_pct DESC;


-- ------------------------------------------------------------
-- Query 2.2: Top 10 Companies by Gross Margin
-- High gross margins indicate strong pricing power or low
-- production costs. Software/tech companies typically lead
-- (margins 60-80%+) while retailers and manufacturers lag
-- (margins 20-30%). This is a key indicator of competitive moat.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    gross_margin,
    operating_margin,
    net_profit_margin,
    return_on_equity,
    return_on_assets
FROM companies
WHERE gross_margin != '-'
ORDER BY CAST(REPLACE(gross_margin,'%','') AS DECIMAL(10,2)) DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Query 2.3: Top 10 Companies by Return on Equity (ROE)
-- ROE measures how much profit is generated per dollar of
-- shareholder equity. Warren Buffett considers ROE > 20%
-- consistently as a sign of a durable competitive advantage.
-- CAUTION: Very high ROE (e.g. 100%+) can indicate heavy
-- debt financing rather than genuine profitability.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    return_on_equity,
    return_on_assets,
    return_on_investment,
    total_debt_to_equity,
    net_profit_margin
FROM companies
WHERE return_on_equity != '-'
  AND return_on_equity NOT LIKE '-%'
ORDER BY CAST(REPLACE(return_on_equity,'%','') AS DECIMAL(10,2)) DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Query 2.4: Bottom 10 Companies by Net Profit Margin
-- (Loss-making or near-breakeven companies)
-- Negative net margins mean the company spends more than it
-- earns. This is common in early-stage growth companies or
-- cyclical industries during downturns (airlines, energy).
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    revenue_ttm,
    net_profit_margin,
    operating_margin,
    return_on_equity,
    eps_diluted
FROM companies
WHERE net_profit_margin != '-'
  AND net_profit_margin LIKE '-%'
ORDER BY CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)) ASC
LIMIT 10;


-- ============================================================
-- SECTION 3: VALUATION ANALYSIS
-- ============================================================
-- Valuation ratios compare a stock's price to its fundamentals.
-- They help identify whether a stock is cheap or expensive
-- relative to its earnings, sales, or assets.
--   P/E  = Price / Earnings Per Share
--           How much investors pay per $1 of earnings
--           Market average ~20-25x; growth stocks often 50x+
--   P/B  = Price / Book Value Per Share
--           Price relative to net assets; <1 may indicate undervaluation
--   P/S  = Price / Revenue Per Share
--           Useful when earnings are negative (growth companies)
--   PEG  = P/E / Expected EPS Growth Rate
--           PEG < 1 often considered undervalued relative to growth
-- ============================================================

-- ------------------------------------------------------------
-- Query 3.1: Average Valuation Ratios by Index Membership
-- Higher P/E ratios mean investors pay more for each dollar
-- of earnings — typically because they expect strong future growth.
-- DJIA companies tend to have more moderate valuations as they
-- are mature, established businesses.
-- ------------------------------------------------------------
SELECT
    index_membership,
    COUNT(*) AS companies,
    ROUND(AVG(NULLIF(CAST(REPLACE(pe_ratio,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_pe_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(forward_pe,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_forward_pe,
    ROUND(AVG(NULLIF(CAST(REPLACE(price_to_book,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_pb_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(price_to_sales,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_ps_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(peg_ratio,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_peg_ratio
FROM companies
WHERE pe_ratio != '-'
  AND pe_ratio NOT LIKE '-%'
GROUP BY index_membership
ORDER BY avg_pe_ratio DESC;


-- ------------------------------------------------------------
-- Query 3.2: Potentially Undervalued Companies
-- Criteria for "potentially undervalued":
--   P/E < 15 (below market average)
--   P/B < 2  (trading near book value)
--   Analyst recommendation < 2.5 (closer to "Buy")
--   Positive net margin (actually profitable)
-- This is a classic value investing screen (Graham/Buffett style).
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    prev_close,
    pe_ratio,
    forward_pe,
    price_to_book,
    peg_ratio,
    analyst_recommendation,
    net_profit_margin,
    analyst_target_price
FROM companies
WHERE pe_ratio != '-'
  AND pe_ratio NOT LIKE '-%'
  AND price_to_book != '-'
  AND analyst_recommendation != '-'
  AND net_profit_margin != '-'
  AND net_profit_margin NOT LIKE '-%'
  AND CAST(REPLACE(pe_ratio,'-','') AS DECIMAL(10,2)) BETWEEN 1 AND 15
  AND CAST(REPLACE(price_to_book,'-','') AS DECIMAL(10,2)) < 2
  AND CAST(REPLACE(analyst_recommendation,'-','') AS DECIMAL(10,2)) < 2.5
ORDER BY CAST(REPLACE(pe_ratio,'-','') AS DECIMAL(10,2)) ASC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 3.3: Analyst Recommendation Distribution
-- Analyst ratings: 1=Strong Buy, 2=Buy, 3=Hold, 4=Sell, 5=Strong Sell
-- Most analysts cluster around "Buy" (1.5-2.5) due to coverage bias —
-- firms are more likely to cover companies they are bullish on.
-- Average recommendations below 2.0 signal strong consensus bullishness.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)) BETWEEN 1.0 AND 1.5 THEN '1.0-1.5 Strong Buy'
        WHEN CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)) BETWEEN 1.5 AND 2.0 THEN '1.5-2.0 Buy'
        WHEN CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)) BETWEEN 2.0 AND 2.5 THEN '2.0-2.5 Moderate Buy'
        WHEN CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)) BETWEEN 2.5 AND 3.0 THEN '2.5-3.0 Hold'
        WHEN CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)) > 3.0 THEN '3.0+ Sell/Underperform'
        ELSE 'No Rating'
    END AS recommendation_band,
    COUNT(*) AS company_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM companies WHERE analyst_recommendation != '-'), 2) AS pct_of_total
FROM companies
WHERE analyst_recommendation != '-'
GROUP BY recommendation_band
ORDER BY MIN(CAST(REPLACE(analyst_recommendation,'-','0') AS DECIMAL(10,2)));


-- ------------------------------------------------------------
-- Query 3.4: Stocks Where Analyst Target Price Implies >20% Upside
-- Analyst target price represents the 12-month price estimate.
-- If (target - current price) / current price > 20%, analysts
-- collectively see significant upside from current levels.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    prev_close,
    analyst_target_price,
    ROUND(
        (CAST(REPLACE(analyst_target_price,'-','0') AS DECIMAL(10,2)) -
         CAST(REPLACE(prev_close,'-','0') AS DECIMAL(10,2))) /
         NULLIF(CAST(REPLACE(prev_close,'-','0') AS DECIMAL(10,2)), 0) * 100
    , 2) AS implied_upside_pct,
    analyst_recommendation,
    pe_ratio,
    net_profit_margin
FROM companies
WHERE analyst_target_price != '-'
  AND prev_close != '-'
  AND CAST(REPLACE(prev_close,'-','0') AS DECIMAL(10,2)) > 0
  AND CAST(REPLACE(analyst_target_price,'-','0') AS DECIMAL(10,2)) > 0
HAVING implied_upside_pct > 20
ORDER BY implied_upside_pct DESC
LIMIT 15;


-- ============================================================
-- SECTION 4: RISK & FINANCIAL STABILITY
-- ============================================================
-- Risk metrics help identify how vulnerable a company is to
-- economic downturns, rising interest rates, or market stress.
--   Debt/Equity     = Total Debt / Shareholders' Equity
--                     High D/E means heavy reliance on borrowed money
--                     (risky in rising interest rate environments)
--   Current Ratio   = Current Assets / Current Liabilities
--                     > 1.0 means the company can cover short-term debts
--                     < 1.0 is a potential liquidity warning signal
--   Quick Ratio     = (Current Assets - Inventory) / Current Liabilities
--                     Stricter liquidity test (excludes inventory)
--   Beta            = Stock's sensitivity to market movements
--                     Beta > 1 = more volatile than the market
--                     Beta < 1 = more defensive (utilities, staples)
-- ============================================================

-- ------------------------------------------------------------
-- Query 4.1: Liquidity Health by Index Membership
-- The current ratio and quick ratio measure short-term financial
-- health. Companies with ratios below 1.0 may struggle to meet
-- their immediate financial obligations.
-- ------------------------------------------------------------
SELECT
    index_membership,
    COUNT(*) AS companies,
    ROUND(AVG(NULLIF(CAST(REPLACE(current_ratio,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_current_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(quick_ratio,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_quick_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(total_debt_to_equity,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_debt_to_equity,
    ROUND(AVG(NULLIF(CAST(REPLACE(beta,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_beta,
    -- Count companies with potential liquidity risk
    SUM(CASE WHEN current_ratio != '-'
             AND CAST(REPLACE(current_ratio,'-','') AS DECIMAL(10,2)) < 1.0 THEN 1 ELSE 0 END) AS companies_current_ratio_below_1
FROM companies
WHERE current_ratio != '-'
GROUP BY index_membership
ORDER BY avg_current_ratio DESC;


-- ------------------------------------------------------------
-- Query 4.2: High Debt Companies (Potential Risk Flag)
-- Debt-to-Equity > 2.0 means for every $1 of equity, the company
-- has $2+ of debt. Acceptable in capital-intensive sectors
-- (utilities, real estate) but a warning sign in tech/consumer.
-- High debt + rising interest rates = earnings pressure.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    total_debt_to_equity,
    lt_debt_to_equity,
    current_ratio,
    quick_ratio,
    net_profit_margin,
    return_on_equity,
    beta
FROM companies
WHERE total_debt_to_equity != '-'
  AND CAST(REPLACE(total_debt_to_equity,'-','') AS DECIMAL(10,2)) > 2.0
ORDER BY CAST(REPLACE(total_debt_to_equity,'-','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 4.3: Beta Distribution — Defensive vs Aggressive Stocks
-- Defensive stocks (Beta < 0.8) tend to outperform in bear markets.
-- Aggressive stocks (Beta > 1.5) amplify market moves.
-- A portfolio manager uses beta to manage overall market risk.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) < 0 THEN 'Negative Beta (Counter-cyclical)'
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) BETWEEN 0 AND 0.5 THEN '0.0-0.5 Very Defensive'
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) BETWEEN 0.5 AND 0.8 THEN '0.5-0.8 Defensive'
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) BETWEEN 0.8 AND 1.2 THEN '0.8-1.2 Market-Like'
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) BETWEEN 1.2 AND 1.5 THEN '1.2-1.5 Moderately Aggressive'
        WHEN CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)) > 1.5 THEN '1.5+ High Beta/Aggressive'
        ELSE 'No Data'
    END AS beta_band,
    COUNT(*) AS company_count,
    ROUND(AVG(NULLIF(CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_net_margin,
    ROUND(AVG(NULLIF(CAST(REPLACE(perf_year,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_1yr_performance_pct
FROM companies
WHERE beta != '-'
GROUP BY beta_band
ORDER BY MIN(CAST(REPLACE(beta,'-','0') AS DECIMAL(10,2)));


-- ------------------------------------------------------------
-- Query 4.4: Financially Strongest Companies
-- "Financial fortress" screen — companies that score well on ALL of:
--   Low debt (D/E < 0.5), Strong liquidity (Current Ratio > 2),
--   Profitable (Net Margin > 10%), Defensive or neutral Beta (< 1.2)
-- These are the kind of companies Berkshire Hathaway looks for.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    total_debt_to_equity,
    current_ratio,
    net_profit_margin,
    return_on_equity,
    beta,
    analyst_recommendation
FROM companies
WHERE total_debt_to_equity != '-'
  AND current_ratio != '-'
  AND net_profit_margin != '-'
  AND beta != '-'
  AND CAST(REPLACE(total_debt_to_equity,'-','') AS DECIMAL(10,2)) < 0.5
  AND CAST(REPLACE(current_ratio,'-','') AS DECIMAL(10,2)) > 2.0
  AND CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)) > 10.0
  AND CAST(REPLACE(beta,'-','') AS DECIMAL(10,2)) < 1.2
ORDER BY CAST(REPLACE(return_on_equity,'%','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ============================================================
-- SECTION 5: GROWTH ANALYSIS
-- ============================================================
-- Growth metrics identify companies expanding faster than
-- the overall economy. Key metrics:
--   EPS Growth (5yr)   Historical earnings growth rate
--   Revenue Growth (5yr) Historical sales expansion rate
--   EPS Growth (next yr) Forward-looking earnings estimate
--   Long-term growth    5-year consensus analyst estimate
--
-- Note: High growth stocks typically carry higher P/E ratios
-- because investors pay a premium for future earnings. This is
-- why the PEG ratio (P/E divided by growth rate) is more useful
-- than P/E alone for growth companies.
-- ============================================================

-- ------------------------------------------------------------
-- Query 5.1: Top 15 Growth Companies
-- Strong historical + forward EPS growth, combined with
-- positive revenue growth = most likely to be high-quality
-- growth companies. Compare with their current valuation
-- to see if the growth is already "priced in."
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    eps_growth_5y               AS eps_growth_past_5yr,
    lt_growth_5y                AS lt_growth_estimate_5yr,
    eps_growth_next_year        AS eps_growth_next_yr,
    sales_growth_5y             AS revenue_growth_5yr,
    revenue_growth_qoq          AS revenue_growth_latest_qtr,
    pe_ratio,
    peg_ratio,
    analyst_recommendation
FROM companies
WHERE eps_growth_5y != '-'
  AND lt_growth_5y != '-'
  AND eps_growth_next_year != '-'
  AND sales_growth_5y != '-'
  AND eps_growth_5y NOT LIKE '-%'
  AND lt_growth_5y NOT LIKE '-%'
  AND eps_growth_next_year NOT LIKE '-%'
ORDER BY
    CAST(REPLACE(lt_growth_5y,'%','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 5.2: PEG Ratio Analysis — Growth at a Reasonable Price
-- PEG < 1.0 suggests the stock is undervalued relative to its
-- growth rate (Peter Lynch's "growth at a reasonable price" rule).
-- PEG > 2.0 may mean investors are paying too much for growth.
-- This is one of the most useful valuation screens for growth stocks.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    pe_ratio,
    peg_ratio,
    lt_growth_5y AS growth_estimate_5yr,
    eps_growth_next_year,
    net_profit_margin,
    analyst_recommendation,
    CASE
        WHEN CAST(REPLACE(peg_ratio,'-','0') AS DECIMAL(10,2)) < 1.0 THEN 'Potentially Undervalued vs Growth'
        WHEN CAST(REPLACE(peg_ratio,'-','0') AS DECIMAL(10,2)) BETWEEN 1.0 AND 2.0 THEN 'Fairly Valued vs Growth'
        WHEN CAST(REPLACE(peg_ratio,'-','0') AS DECIMAL(10,2)) > 2.0 THEN 'Potentially Overvalued vs Growth'
        ELSE 'No Data'
    END AS peg_signal
FROM companies
WHERE peg_ratio != '-'
  AND peg_ratio NOT LIKE '-%'
  AND pe_ratio != '-'
ORDER BY CAST(REPLACE(peg_ratio,'-','') AS DECIMAL(10,2)) ASC
LIMIT 20;


-- ------------------------------------------------------------
-- Query 5.3: Revenue Growth Laggards (Sales Declining)
-- Companies with negative 5-year sales growth are losing
-- market share or operating in declining industries.
-- Worth monitoring alongside their profit margins — sometimes
-- a shrinking company is cutting costs and becoming more
-- profitable (the "quality over growth" strategy).
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    sales_growth_5y             AS revenue_growth_5yr,
    revenue_growth_qoq          AS revenue_growth_latest_qtr,
    eps_growth_5y               AS eps_growth_5yr,
    net_profit_margin,
    operating_margin,
    analyst_recommendation
FROM companies
WHERE sales_growth_5y != '-'
  AND sales_growth_5y LIKE '-%'
ORDER BY CAST(REPLACE(sales_growth_5y,'%','') AS DECIMAL(10,2)) ASC
LIMIT 15;


-- ============================================================
-- SECTION 6: DIVIDEND ANALYSIS
-- ============================================================
-- Dividends are cash payments made to shareholders from company
-- profits. High-dividend stocks are preferred by income investors
-- (retirees, income funds). Key metrics:
--   Dividend Yield   = Annual Dividend / Current Price
--                      Higher = more income per $ invested
--   Payout Ratio     = Dividends Paid / Net Income
--                      >80% may be unsustainable long-term
--                      0% means the company reinvests all earnings
-- ============================================================

-- ------------------------------------------------------------
-- Query 6.1: Top 15 Dividend-Paying Companies
-- A sustainable dividend requires both a reasonable yield AND
-- a sustainable payout ratio. We look for yield > 2%
-- (above typical S&P average of ~1.5%) with payout < 75%.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    dividend_annual,
    dividend_yield,
    dividend_payout_ratio,
    net_profit_margin,
    current_ratio,
    eps_growth_next_year,
    analyst_recommendation
FROM companies
WHERE dividend_yield != '-'
  AND dividend_payout_ratio != '-'
  AND dividend_yield NOT LIKE '0.00%'
  AND CAST(REPLACE(dividend_yield,'%','') AS DECIMAL(10,2)) > 2.0
  AND CAST(REPLACE(dividend_payout_ratio,'%','') AS DECIMAL(10,2)) BETWEEN 1 AND 75
ORDER BY CAST(REPLACE(dividend_yield,'%','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 6.2: Dividend Sustainability Check
-- Payout ratio > 80% is a warning sign — the company pays out
-- most of its earnings as dividends, leaving little buffer
-- for reinvestment or economic downturns. These dividends
-- are at higher risk of being cut during recessions.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    dividend_yield,
    dividend_payout_ratio,
    net_profit_margin,
    eps_growth_next_year,
    current_ratio,
    total_debt_to_equity
FROM companies
WHERE dividend_payout_ratio != '-'
  AND dividend_payout_ratio NOT LIKE '-%'
  AND CAST(REPLACE(dividend_payout_ratio,'%','') AS DECIMAL(10,2)) > 80
ORDER BY CAST(REPLACE(dividend_payout_ratio,'%','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ============================================================
-- SECTION 7: MARKET PERFORMANCE ANALYSIS
-- ============================================================
-- Performance metrics show how stocks have actually traded.
-- We compare short-term vs long-term performance to identify:
--   Momentum stocks  (outperforming across all time periods)
--   Recovery plays   (underperforming YTD but strong fundamentals)
--   Potential sells  (weak performance + weak fundamentals)
-- ============================================================

-- ------------------------------------------------------------
-- Query 7.1: Best and Worst YTD Performers
-- Year-to-date performance shows the market's current sentiment
-- about each company. Strong fundamental companies with weak
-- YTD performance may represent buying opportunities.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    perf_ytd                    AS ytd_performance,
    perf_year                   AS one_yr_performance,
    perf_quarter                AS qtr_performance,
    perf_month                  AS month_performance,
    pe_ratio,
    net_profit_margin,
    analyst_recommendation
FROM companies
WHERE perf_ytd != '-'
ORDER BY CAST(REPLACE(perf_ytd,'%','') AS DECIMAL(10,2)) DESC
LIMIT 15;


-- ------------------------------------------------------------
-- Query 7.2: RSI (Relative Strength Index) Analysis
-- RSI measures momentum on a 0-100 scale:
--   RSI > 70 = Overbought (may be due for a pullback)
--   RSI 30-70 = Normal trading range
--   RSI < 30 = Oversold (may represent a buying opportunity)
-- RSI is one of the most widely used technical indicators
-- in stock market analysis.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN CAST(REPLACE(rsi,'-','0') AS DECIMAL(10,2)) >= 70 THEN 'Overbought (RSI 70+)'
        WHEN CAST(REPLACE(rsi,'-','0') AS DECIMAL(10,2)) BETWEEN 50 AND 69.99 THEN 'Bullish (RSI 50-70)'
        WHEN CAST(REPLACE(rsi,'-','0') AS DECIMAL(10,2)) BETWEEN 30 AND 49.99 THEN 'Bearish (RSI 30-50)'
        WHEN CAST(REPLACE(rsi,'-','0') AS DECIMAL(10,2)) < 30 THEN 'Oversold (RSI <30)'
        ELSE 'No Data'
    END AS rsi_zone,
    COUNT(*) AS company_count,
    ROUND(AVG(NULLIF(CAST(REPLACE(perf_ytd,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_ytd_perf,
    ROUND(AVG(NULLIF(CAST(REPLACE(pe_ratio,'-','') AS DECIMAL(10,2)),0)), 2) AS avg_pe_ratio,
    ROUND(AVG(NULLIF(CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)),0)), 2) AS avg_net_margin
FROM companies
WHERE rsi != '-'
GROUP BY rsi_zone
ORDER BY MIN(CAST(REPLACE(rsi,'-','0') AS DECIMAL(10,2)));


-- ============================================================
-- SECTION 8: COMPREHENSIVE COMPANY SCORECARD
-- ============================================================
-- A composite score combining profitability, valuation, growth,
-- and stability — giving each company a holistic financial health
-- score. This is similar to what quant funds use to rank stocks.
-- ============================================================

-- ------------------------------------------------------------
-- Query 8.1: Top 20 Companies by Composite Financial Score
-- Scoring methodology (each dimension scored 0-25, total 0-100):
--   Profitability (25pts): Net Margin + ROE normalized
--   Valuation    (25pts): Inverse P/E (lower P/E = higher score)
--   Growth       (25pts): EPS growth next yr + lt growth
--   Stability    (25pts): Low beta + low debt + high current ratio
-- This demonstrates quantitative finance thinking.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    market_cap,
    net_profit_margin,
    return_on_equity,
    pe_ratio,
    eps_growth_next_year,
    lt_growth_5y,
    beta,
    total_debt_to_equity,
    current_ratio,
    analyst_recommendation,
    -- Composite score (simplified weighted ranking approach)
    ROUND(
        -- Profitability component (higher margin + ROE = better)
        COALESCE(LEAST(CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2)) / 2, 12.5), 0) +
        COALESCE(LEAST(CAST(REPLACE(return_on_equity,'%','') AS DECIMAL(10,2)) / 10, 12.5), 0) +
        -- Valuation component (lower P/E = better, capped at 15pts)
        COALESCE(GREATEST(15 - CAST(REPLACE(pe_ratio,'-','30') AS DECIMAL(10,2)) / 3, 0), 0) +
        -- Growth component
        COALESCE(LEAST(CAST(REPLACE(eps_growth_next_year,'%','') AS DECIMAL(10,2)) / 4, 12.5), 0) +
        COALESCE(LEAST(CAST(REPLACE(lt_growth_5y,'%','') AS DECIMAL(10,2)) / 2, 12.5), 0) +
        -- Stability component (lower beta + low debt = better)
        COALESCE(GREATEST(10 - CAST(REPLACE(beta,'-','1') AS DECIMAL(10,2)) * 5, 0), 0) +
        COALESCE(GREATEST(10 - CAST(REPLACE(total_debt_to_equity,'-','1') AS DECIMAL(10,2)) * 2, 0), 0)
    , 1) AS composite_score
FROM companies
WHERE net_profit_margin != '-'
  AND net_profit_margin NOT LIKE '-%'
  AND return_on_equity != '-'
  AND pe_ratio != '-'
  AND pe_ratio NOT LIKE '-%'
  AND eps_growth_next_year != '-'
  AND eps_growth_next_year NOT LIKE '-%'
  AND lt_growth_5y != '-'
  AND lt_growth_5y NOT LIKE '-%'
  AND beta != '-'
  AND total_debt_to_equity != '-'
ORDER BY composite_score DESC
LIMIT 20;


-- ============================================================
-- EXPORT QUERIES FOR R (Forecasting Inputs)
-- These clean, aggregated outputs will be exported from MySQL
-- and imported into R for regression/forecasting models.
-- ============================================================

-- ------------------------------------------------------------
-- Query 9.1: Clean Dataset for R Export
-- Exports a numeric-ready dataset with key financial ratios
-- converted to decimals — used as input for the R forecasting
-- model that predicts YTD stock performance from fundamentals.
-- ------------------------------------------------------------
SELECT
    ticker,
    index_membership,
    CAST(REPLACE(pe_ratio,'-','') AS DECIMAL(10,2))             AS pe_ratio,
    CAST(REPLACE(price_to_book,'-','') AS DECIMAL(10,2))        AS pb_ratio,
    CAST(REPLACE(price_to_sales,'-','') AS DECIMAL(10,2))       AS ps_ratio,
    CAST(REPLACE(net_profit_margin,'%','') AS DECIMAL(10,2))    AS net_margin,
    CAST(REPLACE(gross_margin,'%','') AS DECIMAL(10,2))         AS gross_margin,
    CAST(REPLACE(operating_margin,'%','') AS DECIMAL(10,2))     AS operating_margin,
    CAST(REPLACE(return_on_equity,'%','') AS DECIMAL(10,2))     AS roe,
    CAST(REPLACE(return_on_assets,'%','') AS DECIMAL(10,2))     AS roa,
    CAST(REPLACE(total_debt_to_equity,'-','') AS DECIMAL(10,2)) AS debt_to_equity,
    CAST(REPLACE(current_ratio,'-','') AS DECIMAL(10,2))        AS current_ratio,
    CAST(REPLACE(beta,'-','') AS DECIMAL(10,2))                 AS beta,
    CAST(REPLACE(eps_growth_next_year,'%','') AS DECIMAL(10,2)) AS eps_growth_fwd,
    CAST(REPLACE(lt_growth_5y,'%','') AS DECIMAL(10,2))         AS lt_growth_5y,
    CAST(REPLACE(dividend_yield,'%','') AS DECIMAL(10,2))       AS dividend_yield,
    CAST(REPLACE(insider_ownership,'%','') AS DECIMAL(10,2))    AS insider_ownership,
    CAST(REPLACE(rsi,'-','') AS DECIMAL(10,2))                  AS rsi,
    CAST(REPLACE(perf_ytd,'%','') AS DECIMAL(10,2))             AS ytd_performance,
    CAST(REPLACE(perf_year,'%','') AS DECIMAL(10,2))            AS one_yr_performance,
    CAST(REPLACE(analyst_recommendation,'-','') AS DECIMAL(10,2)) AS analyst_rec
FROM companies
WHERE pe_ratio NOT LIKE '-%'  AND pe_ratio != '-'
  AND net_profit_margin != '-'
  AND return_on_equity != '-'
  AND beta != '-'
  AND perf_ytd != '-'
  AND rsi != '-';
