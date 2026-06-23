-- ============================================================
-- S&P 500 FINANCIAL ANALYTICS - SQL PORTFOLIO PROJECT
-- Dataset: S&P 500 Companies Financial Indicators (496 companies, 74 columns)
-- Database: sp500_project | Table: companies
-- ============================================================

-- Enable local file import
SET GLOBAL local_infile = 1;

-- Create and select database
CREATE DATABASE IF NOT EXISTS sp500_project;
USE sp500_project;

-- Drop table if re-running
DROP TABLE IF EXISTS companies;

-- Create table with clean column names (original names were too long/messy for SQL)
CREATE TABLE companies (
  `ticker`                        VARCHAR(10),
  `index_membership`              VARCHAR(50),
  `market_cap`                    VARCHAR(20),
  `income_ttm`                    VARCHAR(20),
  `revenue_ttm`                   VARCHAR(20),
  `book_value_per_share`          VARCHAR(20),
  `cash_per_share`                VARCHAR(20),
  `dividend_annual`               VARCHAR(20),
  `dividend_yield`                VARCHAR(20),
  `employees`                     VARCHAR(20),
  `has_options`                   VARCHAR(5),
  `shortable`                     VARCHAR(5),
  `analyst_recommendation`        VARCHAR(10),
  `pe_ratio`                      VARCHAR(20),
  `forward_pe`                    VARCHAR(20),
  `peg_ratio`                     VARCHAR(20),
  `price_to_sales`                VARCHAR(20),
  `price_to_book`                 VARCHAR(20),
  `price_to_cash`                 VARCHAR(20),
  `price_to_fcf`                  VARCHAR(20),
  `quick_ratio`                   VARCHAR(20),
  `current_ratio`                 VARCHAR(20),
  `total_debt_to_equity`          VARCHAR(20),
  `lt_debt_to_equity`             VARCHAR(20),
  `dist_20d_sma`                  VARCHAR(20),
  `eps_diluted`                   VARCHAR(20),
  `eps_next_year`                 VARCHAR(20),
  `eps_next_quarter`              VARCHAR(20),
  `eps_growth_this_year`          VARCHAR(20),
  `eps_growth_next_year`          VARCHAR(20),
  `lt_growth_5y`                  VARCHAR(20),
  `eps_growth_5y`                 VARCHAR(20),
  `sales_growth_5y`               VARCHAR(20),
  `revenue_growth_qoq`            VARCHAR(20),
  `earnings_growth_qoq`           VARCHAR(20),
  `earnings_date`                 VARCHAR(50),
  `dist_50d_sma`                  VARCHAR(20),
  `insider_ownership`             VARCHAR(20),
  `insider_transactions_6m`       VARCHAR(20),
  `institutional_ownership`       VARCHAR(20),
  `institutional_transactions_3m` VARCHAR(20),
  `return_on_assets`              VARCHAR(20),
  `return_on_equity`              VARCHAR(20),
  `return_on_investment`          VARCHAR(20),
  `gross_margin`                  VARCHAR(20),
  `operating_margin`              VARCHAR(20),
  `net_profit_margin`             VARCHAR(20),
  `dividend_payout_ratio`         VARCHAR(20),
  `dist_200d_sma`                 VARCHAR(20),
  `shares_outstanding`            VARCHAR(20),
  `shares_float`                  VARCHAR(20),
  `short_interest_ratio`          VARCHAR(20),
  `short_interest`                VARCHAR(20),
  `analyst_target_price`          VARCHAR(20),
  `week_52_range`                 VARCHAR(30),
  `dist_52w_high`                 VARCHAR(20),
  `dist_52w_low`                  VARCHAR(20),
  `rsi`                           VARCHAR(20),
  `relative_volume`               VARCHAR(20),
  `avg_volume_3m`                 VARCHAR(20),
  `volume`                        VARCHAR(30),
  `perf_week`                     VARCHAR(20),
  `perf_month`                    VARCHAR(20),
  `perf_quarter`                  VARCHAR(20),
  `perf_half_year`                VARCHAR(20),
  `perf_year`                     VARCHAR(20),
  `perf_ytd`                      VARCHAR(20),
  `beta`                          VARCHAR(20),
  `avg_true_range`                VARCHAR(20),
  `volatility_week`               VARCHAR(20),
  `volatility_month`              VARCHAR(20),
  `prev_close`                    VARCHAR(20),
  `current_price`                 VARCHAR(20),
  `perf_today`                    VARCHAR(20)
);

-- Load the CSV (update the path to match your file location)
LOAD DATA LOCAL INFILE 'C:/Users/aksta/Desktop/sp500_project/snp500_companies_description.csv'
INTO TABLE companies
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Verify row count (expect ~496)
SELECT COUNT(*) AS total_companies FROM companies;

-- Quick spot check
SELECT ticker, index_membership, market_cap, revenue_ttm,
       pe_ratio, gross_margin, return_on_equity, current_price
FROM companies
LIMIT 5;
