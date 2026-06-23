# S&P 500 Financial Analytics

A comprehensive financial analysis of 496 S&P 500 companies across 74 financial indicators, combining MySQL for structured querying, R for statistical modelling, and an interactive R Markdown report — demonstrating both business analytics skills and applied finance knowledge.

The core finding: **momentum (RSI) explains 56% of short-term stock performance**, while all 9 fundamental financial ratios combined explain only 16% — empirically confirming the momentum factor documented by Jegadeesh & Titman (1993) on real market data.

---

## Business Problem

The S&P 500 represents the 500 largest U.S. publicly traded companies across 11 sectors. While the index is widely followed as a benchmark, investors and analysts face a critical challenge: identifying which sectors and companies offer the best combination of profitability, financial stability, valuation, and growth potential. This project answers three questions:

1. **Where is value being created?** (Profitability Analysis)
2. **Where is risk being taken?** (Valuation & Stability)
3. **What drives short-term stock performance?** (Regression Forecasting)

---

## Dataset

- **Source:** Yahoo Finance / Finviz — aggregated financial indicators
- **Size:** 496 S&P 500 companies | 74 financial columns | Snapshot: Early 2023
- **Database:** MySQL (`sp500_project.companies`) — all columns stored as VARCHAR due to mixed formats (e.g. "41.05B", "54.50%"); REPLACE() + CAST() used for arithmetic throughout

---

## SQL Analysis (17 Queries, 8 Sections)

| Section | Queries | What It Covers |
|---|---|---|
| 1. Data Quality & Overview | 4 | Market cap distribution ($35.7T total), missing value audit, top 15 by market cap |
| 2. Profitability | 4 | Gross margin, net margin, ROE, ROA by index tier — NDX companies avg 57.94% gross margin |
| 3. Valuation | 4 | P/E, P/B, PEG ratio analysis — energy sector trades at PEG 0.14-0.44 (ESG discount) |
| 4. Risk & Stability | 4 | Beta distribution, debt/equity, liquidity screen, "Financial Fortress" criteria |
| 5. Growth | 3 | EPS growth, revenue growth, PEG vs growth rate (full 381-company PEG distribution) |
| 6. Dividends | 2 | Yield sustainability screen, payout ratio warnings (IBM at 362.9%) |
| 7. Performance | 2 | YTD returns, RSI zone analysis |
| 8. Composite Scorecard | 1 | Quantitative scoring across profitability, valuation, growth, and stability |
| Export | 1 | Clean numeric dataset for R forecasting (Query 9.1) |

---

## Regression Forecasting (R)

Three models predicting YTD stock performance from financial indicators:

| Model | Variables | Train R² | CV R² |
|---|---|---|---|
| **Momentum Only** | RSI + Beta + Dividend Yield | 0.5595 | 0.5345 |
| Fundamentals Only | 9 financial ratios | 0.1619 | 0.0828 |
| Full Model | All 13 variables | 0.5877 | 0.5379 |

**Test R² = 0.51 | RMSE = ±7.94%**

An R² of ~0.56 is notably high by cross-sectional equity return standards — academic literature typically reports 0.05–0.30 for fundamental models. The momentum dominance is not a failure; it is the expected result confirmed by 30+ years of empirical asset pricing research.

---

## Key Findings

- **Total S&P 500 market cap: $35.7 trillion** — 30 mega-cap companies (6%) dominate the index
- **NVDA's PEG ratio: 6.55 vs Energy sector PEG: 0.14–0.44** — AI premium vs ESG structural discount
- **Only 15 companies (3%)** pass all four "Financial Fortress" criteria simultaneously (D/E < 0.5, Current Ratio > 2, Net Margin > 10%, Beta < 1.2)
- **Three failed banks (SVB, Signature, First Republic)** appeared financially healthy in the data — the most important lesson: quantitative screens cannot detect bank run risk
- **RSI correlation with YTD returns: 0.69** — the strongest predictor in the dataset, outperforming every fundamental ratio

---

## Data Warnings & Limitations

- All numeric columns stored as VARCHAR — use `REPLACE() + CAST()` for arithmetic (documented in every query)
- `current_price` column actually stores today's % performance — actual stock price is in `prev_close` (column shift from CSV import)
- REIT gross margins (99%+) are not comparable to regular companies — structural accounting difference
- Debt-inflated ROE (APA: 924.9%, Colgate: 472.2%) reflects leverage, not operational excellence
- Dataset is a single early-2023 snapshot — results reflect bear market recovery dynamics

---

## Repository Contents

| File | Description |
|---|---|
| `sp500_setup.sql` | CREATE TABLE statement + LOAD DATA command for MySQL import |
| `sp500_analysis.sql` | 17 queries across 8 analytical sections with financial knowledge comments |
| `sp500_report.Rmd` | Full R Markdown report — EDA, correlation analysis, 3 regression models, validation, business conclusions |
| `sp500_forecasting.R` | Standalone R forecasting script (same models as Rmd, script format) |

---

## Tools

MySQL · SQL · R · tidyverse · caret · corrplot · broom · ggplot2 · plotly

---

## Author

Abdulrahman Jalilov — [LinkedIn](https://uk.linkedin.com/in/abdulrahman-jalilov-526a25257) · [GitHub](https://github.com/lesdenizz)
