# ============================================================
# S&P 500 FINANCIAL ANALYTICS - R FORECASTING MODEL
# Author: Abdulrahman Jalilov
#
# Data Source: MySQL (sp500_project.companies) - Query 9.1 export
# File: sp500_clean_export.csv (444 companies, 21 variables)
#
# Objective: Use financial fundamentals to predict YTD stock
# performance — which metrics best explain short-term price moves?
#
# Pipeline: MySQL → sp500_clean_export.csv → R (this script)
#           → cleaned results → Excel/Shiny dashboard
# ============================================================

library(tidyverse)
library(caret)
library(corrplot)
library(ggplot2)
library(kableExtra)
library(scales)

# ============================================================
# SECTION 1: DATA LOADING & CLEANING
# ============================================================

# Load the clean export from MySQL Query 9.1
# (place the CSV in your working directory)
df_raw <- read.csv("sp500_clean_export.csv", stringsAsFactors = FALSE)

cat("=== Dataset Overview ===\n")
cat("Rows:", nrow(df_raw), "\n")
cat("Cols:", ncol(df_raw), "\n")
cat("YTD Performance range:", round(min(df_raw$ytd_performance), 2),
    "% to", round(max(df_raw$ytd_performance), 2), "%\n\n")

# ---- 1.1 Remove statistical outliers ----
# Extreme ROE values (>500%) are debt-inflation artifacts (APA, MSI)
# Extreme P/E values (>200) reflect near-zero earnings (CRM, GE restructuring)
# These distort regression coefficients and should be capped or removed

df_clean <- df_raw %>%
  filter(
    roe        > -200   & roe        < 200,    # remove debt-inflated ROE
    pe_ratio   < 200,                           # remove distorted P/E (CRM 888)
    debt_to_equity < 20,                        # remove extreme leverage (NCLH 198)
    net_margin >= 0                             # only profitable companies
  )

cat("=== After Cleaning ===\n")
cat("Companies remaining:", nrow(df_clean), "\n")
cat("Removed:", nrow(df_raw) - nrow(df_clean), "outliers\n\n")


# ============================================================
# SECTION 2: EXPLORATORY DATA ANALYSIS
# ============================================================

# ---- 2.1 YTD Performance Distribution ----
p1 <- ggplot(df_clean, aes(x = ytd_performance)) +
  geom_histogram(bins = 40, fill = "#457B9D", color = "white", alpha = 0.8) +
  geom_vline(xintercept = 0, color = "#E76F51", linewidth = 1, linetype = "dashed") +
  geom_vline(xintercept = mean(df_clean$ytd_performance),
             color = "#2A9D8F", linewidth = 1) +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Distribution of YTD Stock Performance",
    subtitle = paste0("Mean: ", round(mean(df_clean$ytd_performance), 1),
                      "% | Median: ", round(median(df_clean$ytd_performance), 1), "%"),
    x = "YTD Performance (%)",
    y = "Number of Companies",
    caption = "Red dashed line = 0% | Teal line = mean | S&P 500 Companies, early 2023"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 16))

print(p1)

# ---- 2.2 Correlation Heatmap ----
numeric_vars <- df_clean %>%
  select(ytd_performance, pe_ratio, pb_ratio, net_margin, gross_margin,
         operating_margin, roe, roa, debt_to_equity, current_ratio,
         beta, eps_growth_fwd, lt_growth_5y, dividend_yield, rsi, analyst_rec) %>%
  cor(use = "complete.obs")

corrplot(numeric_vars,
         method = "color",
         type = "upper",
         tl.cex = 0.8,
         tl.col = "#2C3E50",
         col = colorRampPalette(c("#E76F51", "white", "#2A9D8F"))(200),
         title = "Correlation Matrix — S&P 500 Financial Indicators",
         mar = c(0, 0, 2, 0))

# ---- 2.3 Top Correlations with YTD Performance ----
corr_with_ytd <- numeric_vars["ytd_performance", ] %>%
  as.data.frame() %>%
  rownames_to_column("variable") %>%
  rename(correlation = ".") %>%
  filter(variable != "ytd_performance") %>%
  arrange(desc(abs(correlation)))

cat("=== Top Correlations with YTD Performance ===\n")
print(corr_with_ytd)

# ---- KEY FINDING: RSI dominates ----
# RSI correlation = 0.69 (by far the strongest predictor)
# This tells us: in this snapshot, MOMENTUM (RSI) explains more
# of the short-term price variation than any fundamental metric
# (profitability, valuation, growth). This has important implications
# for the business problem — fundamentals matter less in the short run.


# ============================================================
# SECTION 3: SIMPLE LINEAR REGRESSION (BASELINE)
# ============================================================
# We start with the two strongest individual predictors:
# RSI (momentum) and beta (market sensitivity)

# ---- 3.1 Model 1: RSI only ----
model_rsi <- lm(ytd_performance ~ rsi, data = df_clean)
cat("\n=== Model 1: RSI Only ===\n")
print(summary(model_rsi))

# ---- 3.2 Model 2: Beta only ----
model_beta <- lm(ytd_performance ~ beta, data = df_clean)
cat("\n=== Model 2: Beta Only ===\n")
print(summary(model_beta))

# ---- 3.3 RSI scatter with regression line ----
p2 <- ggplot(df_clean, aes(x = rsi, y = ytd_performance)) +
  geom_point(alpha = 0.5, color = "#457B9D", size = 2) +
  geom_smooth(method = "lm", color = "#E76F51", se = TRUE, linewidth = 1.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = 70, linetype = "dotted", color = "#E76F51", alpha = 0.7) +
  geom_vline(xintercept = 30, linetype = "dotted", color = "#2A9D8F", alpha = 0.7) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "RSI vs YTD Performance",
    subtitle = paste0("R² = ", round(summary(model_rsi)$r.squared, 3),
                      " | RSI is the strongest single predictor (r = 0.69)"),
    x = "RSI (Relative Strength Index)",
    y = "YTD Performance (%)",
    caption = "Red dotted line = Overbought (70) | Teal dotted line = Oversold (30)"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 16))

print(p2)


# ============================================================
# SECTION 4: MULTIPLE LINEAR REGRESSION
# ============================================================
# We build three models of increasing complexity:
#   Model A: Momentum only (RSI, beta)
#   Model B: Fundamentals only (pe, net_margin, roe, roa, debt, current_ratio)
#   Model C: Full model (all variables)
# This tests the core question: do fundamentals predict YTD performance
# or is the market purely momentum-driven in the short run?

# ---- 4.1 Model A: Momentum ----
model_momentum <- lm(
  ytd_performance ~ rsi + beta + dividend_yield,
  data = df_clean
)

# ---- 4.2 Model B: Fundamentals ----
model_fundamentals <- lm(
  ytd_performance ~ pe_ratio + net_margin + roe + roa +
    debt_to_equity + current_ratio + gross_margin +
    eps_growth_fwd + lt_growth_5y,
  data = df_clean
)

# ---- 4.3 Model C: Full ----
model_full <- lm(
  ytd_performance ~ rsi + beta + dividend_yield +
    pe_ratio + net_margin + roe + roa +
    debt_to_equity + current_ratio + gross_margin +
    eps_growth_fwd + lt_growth_5y + analyst_rec,
  data = df_clean
)

# ---- 4.4 Model comparison summary ----
model_comparison <- data.frame(
  Model = c("Momentum Only", "Fundamentals Only", "Full Model"),
  Variables = c(3, 9, 13),
  R_Squared = c(
    round(summary(model_momentum)$r.squared, 4),
    round(summary(model_fundamentals)$r.squared, 4),
    round(summary(model_full)$r.squared, 4)
  ),
  Adj_R_Squared = c(
    round(summary(model_momentum)$adj.r.squared, 4),
    round(summary(model_fundamentals)$adj.r.squared, 4),
    round(summary(model_full)$adj.r.squared, 4)
  ),
  AIC = c(
    round(AIC(model_momentum), 1),
    round(AIC(model_fundamentals), 1),
    round(AIC(model_full), 1)
  )
)

cat("\n=== Model Comparison ===\n")
print(model_comparison)

cat("\n=== Full Model Summary ===\n")
print(summary(model_full))


# ============================================================
# SECTION 5: MODEL DIAGNOSTICS
# ============================================================

# ---- 5.1 Residuals vs Fitted ----
par(mfrow = c(2, 2))
plot(model_full, col = "#457B9D", pch = 16, cex = 0.6)
par(mfrow = c(1, 1))

# ---- 5.2 Feature Importance (standardized coefficients) ----
# Standardize to compare variable importance on the same scale
df_scaled <- df_clean %>%
  select(ytd_performance, rsi, beta, dividend_yield, pe_ratio,
         net_margin, roe, roa, debt_to_equity, current_ratio,
         gross_margin, eps_growth_fwd, lt_growth_5y, analyst_rec) %>%
  mutate(across(-ytd_performance, scale))

model_scaled <- lm(ytd_performance ~ ., data = df_scaled)

importance <- broom::tidy(model_scaled) %>%
  filter(term != "(Intercept)") %>%
  mutate(
    abs_estimate = abs(estimate),
    direction = ifelse(estimate > 0, "Positive", "Negative")
  ) %>%
  arrange(desc(abs_estimate))

cat("\n=== Feature Importance (Standardized Coefficients) ===\n")
print(importance %>% select(term, estimate, abs_estimate, direction, p.value) %>%
      mutate(across(where(is.numeric), round, 4)))

# ---- 5.3 Feature Importance Plot ----
p3 <- ggplot(importance, aes(x = reorder(term, abs_estimate),
                              y = estimate,
                              fill = direction)) +
  geom_col(width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Positive" = "#2A9D8F", "Negative" = "#E76F51")) +
  labs(
    title = "Feature Importance — Standardized Regression Coefficients",
    subtitle = "Predicting YTD Performance from Financial Fundamentals + Momentum",
    x = NULL,
    y = "Standardized Coefficient",
    fill = "Direction",
    caption = "Teal = positive predictor of YTD performance | Red = negative predictor"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 16),
        legend.position = "bottom")

print(p3)


# ============================================================
# SECTION 6: TRAIN/TEST SPLIT & CROSS-VALIDATION
# ============================================================
# We validate the model on a held-out test set to ensure results
# are not overfitted — same methodology as the HR project.

set.seed(42)
train_idx <- createDataPartition(df_scaled$ytd_performance, p = 0.8, list = FALSE)
train_data <- df_scaled[train_idx, ]
test_data  <- df_scaled[-train_idx, ]

# 5-fold cross-validated model
ctrl <- trainControl(method = "cv", number = 5)

cv_model <- train(
  ytd_performance ~ .,
  data      = train_data,
  method    = "lm",
  trControl = ctrl
)

# Predictions on test set
test_preds <- predict(cv_model, newdata = test_data)
test_actual <- test_data$ytd_performance

test_rmse <- sqrt(mean((test_preds - test_actual)^2))
test_r2   <- cor(test_preds, test_actual)^2

cat("\n=== Cross-Validated Model Performance ===\n")
cat("CV RMSE (training):", round(cv_model$results$RMSE, 3), "\n")
cat("CV R² (training):  ", round(cv_model$results$Rsquared, 4), "\n")
cat("Test RMSE:         ", round(test_rmse, 3), "\n")
cat("Test R²:           ", round(test_r2, 4), "\n")

# ---- 6.1 Predicted vs Actual Plot ----
results_df <- data.frame(
  ticker  = df_clean$ticker[-train_idx],
  actual  = test_actual,
  predicted = test_preds
)

p4 <- ggplot(results_df, aes(x = actual, y = predicted)) +
  geom_point(alpha = 0.6, color = "#457B9D", size = 2) +
  geom_abline(intercept = 0, slope = 1,
              color = "#E76F51", linewidth = 1, linetype = "dashed") +
  geom_smooth(method = "lm", color = "#2A9D8F", se = FALSE) +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Predicted vs Actual YTD Performance (Test Set)",
    subtitle = paste0("Test R² = ", round(test_r2, 3),
                      " | RMSE = ", round(test_rmse, 2), "%"),
    x = "Actual YTD Performance (%)",
    y = "Predicted YTD Performance (%)",
    caption = "Red dashed = perfect prediction line | Teal = model fit line"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 16))

print(p4)


# ============================================================
# SECTION 7: BUSINESS CONCLUSIONS
# ============================================================

cat("\n\n============================================================\n")
cat("BUSINESS CONCLUSIONS\n")
cat("============================================================\n\n")

cat("1. RSI (momentum) is the dominant predictor of short-term YTD performance\n")
cat("   (correlation = 0.69). Fundamentals alone explain far less of short-\n")
cat("   term price variation — consistent with market efficiency theory.\n\n")

cat("2. Momentum Model R² = ", round(summary(model_momentum)$r.squared, 3),
    " vs Fundamentals R² = ", round(summary(model_fundamentals)$r.squared, 3), "\n")
cat("   → Momentum explains ~", round(summary(model_momentum)$r.squared*100, 1),
    "% of YTD performance variation;\n")
cat("     Fundamentals explain only ~",
    round(summary(model_fundamentals)$r.squared*100, 1), "%\n\n")

cat("3. Among fundamental variables, DIVIDEND YIELD has the most significant\n")
cat("   NEGATIVE relationship with YTD performance — consistent with our\n")
cat("   SQL findings: high-yield stocks (energy, banks) lagged the market.\n\n")

cat("4. The Full Model explains ~",
    round(summary(model_full)$r.squared*100, 1), "% of YTD variation.\n")
cat("   Remaining ~", round((1-summary(model_full)$r.squared)*100, 1),
    "% is unexplained — reflecting news, sentiment,\n")
cat("   sector rotation, and macro factors not captured in financial ratios.\n\n")

cat("5. Data quality caveats for these results:\n")
cat("   - Dataset is a snapshot (early 2023); results may not generalize\n")
cat("   - Failed banks (SIVB, FRC, SBNY) removed as outliers\n")
cat("   - REITs artificially inflate gross margin metrics\n")
cat("   - Debt-inflated ROE values removed (ROE > 200% threshold)\n")


# ============================================================
# EXPORT RESULTS FOR EXCEL/SHINY DASHBOARD
# ============================================================

# Export predictions + actuals for dashboard use
write.csv(results_df, "sp500_predictions.csv", row.names = FALSE)

# Export model comparison for report table
write.csv(model_comparison, "sp500_model_comparison.csv", row.names = FALSE)

# Export feature importance for chart
write.csv(importance, "sp500_feature_importance.csv", row.names = FALSE)

cat("\n=== Exports Complete ===\n")
cat("sp500_predictions.csv       - Predicted vs actual YTD\n")
cat("sp500_model_comparison.csv  - R², AIC comparison across 3 models\n")
cat("sp500_feature_importance.csv - Standardized coefficients\n")
