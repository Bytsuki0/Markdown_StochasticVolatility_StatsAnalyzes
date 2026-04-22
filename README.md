# HEAVILY OUTDATED DOC
# Stochastic Volatility Analysis of Intraday Returns


This repository contains two Quarto (`.qmd`) reports analysing stochastic volatility and intraday return dynamics around market crash events, using 1-minute tick data. Both reports are rendered to HTML and follow a common analytical pipeline, applied to different assets and markets.

---

## Reports

### 1. `analise_volatilidade_ibm_3_op.qmd` — IBM (NYSE)

Analyses intraday 1-minute returns for IBM across **three automatically detected crash events** identified from the full historical series. Each crash is defined as a day with the largest closing-price drop, subject to a minimum separation of ~31 000 observations between events.

**Pipeline:**

- **Data loading & preprocessing** — reads `IBM_data.csv`, filters opening noise (first 9 minutes) and late ticks, removes outliers via 10-σ clipping with forward-fill.
- **Crash detection** — ranks trading days by overnight closing-price decline; selects the top 3 non-overlapping events, then pinpoints the intraday minute of minimum return within each crash day.
- **Windowing** — constructs 9 segments (3 events × 3 phases): *pre* (−20 000 to −10 000 obs), *during* (−1 000 to +9 000 obs), and *post* (+20 000 to +30 000 obs) relative to the crash minute.
- **Stationarity** — ADF test for each of the 9 segments.
- **Descriptive analysis** — historical volatility (30-min rolling window), ACF/PACF of log-returns.
- **Stochastic Volatility models** — fits 9 independent `svsample()` models (MCMC, 5 000 draws, 1 000 burn-in) via the `stochvol` package. Results are cached as compressed `.rds` files to avoid re-running MCMC.
- **Realized Variance & jumps** — computes RV, Bipower Variation (BV), jump component, annualised volatility, and descriptive statistics per segment. Statistical validation via permutation tests (RV difference), Levene's test, and Kolmogorov–Smirnov test.
- **SV parameter analysis** — extracts posterior distributions of μ (level), φ (persistence), and σ (volatility-of-volatility) for all 9 segments. Derives: shock half-life, unconditional variance, predictability index, and CV of the latent volatility series.
- **Visualisations** — heatmap of z-scored parameter profiles; predictability plane (φ vs σ with quadrant classification); half-life bar chart with 95% credible intervals; pairwise posterior P(σ_A > σ_B) matrix; posterior density and violin plots of annualised volatility; consolidated comparison across all 3 events.

---

### 2. `analise_volatilidade_petr4_Q1.qmd` — PETR4 (B3)

Analyses intraday 1-minute returns for PETR4 (Petrobras) during **Q1 2021** (04 Jan – 25 Jun 2021, ~49 611 observations), focusing on the **sharp drop of 22 Feb 2021** triggered by the announcement of a CEO change.

**Data source:** MetaTrader 5. **Author:** Gustavo Vitor da Silva.

**Pipeline:**

- **Data loading & preprocessing** — reads `dt_1min_PETR4_2021_metatrader.csv` (Windows/Linux paths handled automatically), filters opening noise (before 10:20), late ticks (after 16:54), and the public holiday on 17 Feb 2021.
- **Stationarity** — ADF test on the full return series.
- **Segment definition** — three fixed segments: *pre* (obs 1–10 000), *post* (obs ~11 600–22 600, centred on the crash), and *recovery* (obs ~33 600–43 600).
- **Descriptive analysis** — 30-min rolling historical volatility; ACF/PACF of log-returns pre and post crash.
- **Stochastic Volatility models** — fits 3 `svsample()` models (one per segment, 5 000 draws, 1 000 burn-in), cached as `sv_fit.rds`, `sv_fit2.rds`, `sv_fit3.rds`.
- **Parameter interpretation** — posterior summaries of μ, φ, and σ with regime-level comparisons (post − pre, recovery − pre), including posterior probability P(param_post > param_pre).
- **Realized Variance & jumps** — RV, BV, jump share (~61–62% across all regimes), annualised volatility (~0.34 pre, ~0.46 post, ~0.24 recovery).
- **Statistical tests** — permutation tests on RV differences, Levene's test, KS test.
- **Visualisations** — cumulative realised volatility curves; price series with highlighted segments; posterior density plots; violin/boxplot of annualised volatility draws; summary tables.

---

## Key Findings

| Asset  | Regime      | μ (log-vol level) | φ (persistence) | σ (vol-of-vol) | Ann. Vol (approx.) |
|--------|-------------|:-----------------:|:---------------:|:--------------:|:------------------:|
| PETR4  | Pre-crash   | −13.8             | 0.97            | 0.16           | ~0.34              |
| PETR4  | Post-crash  | −13.3             | 0.99            | 0.12           | ~0.46              |
| PETR4  | Recovery    | −14.4             | 0.98            | 0.11           | ~0.24              |

For IBM, equivalent parameter estimates and regime classifications are produced programmatically across 9 segments (3 events × 3 phases) and presented as heatmaps and predictability-plane plots.

---

## Repository Structure

```
.
├── analise_volatilidade_ibm_3_op.qmd       # IBM analysis (3 crash events)
├── analise_volatilidade_petr4_Q1.qmd       # PETR4 Q1 2021 analysis
├── IBM_data.csv                             # IBM 1-min tick data (required)
├── dt_1min_PETR4_2021_metatrader.csv        # PETR4 1-min tick data (required)
├── sv_ibm_e1_pre.rds                        # Cached SV model (auto-generated)
├── sv_ibm_e1_during.rds
├── sv_ibm_e1_post.rds
├── sv_ibm_e2_pre.rds
├── sv_ibm_e2_during.rds
├── sv_ibm_e2_post.rds
├── sv_ibm_e3_pre.rds
├── sv_ibm_e3_during.rds
├── sv_ibm_e3_post.rds
├── sv_fit.rds                               # Cached SV model PETR4 pre (auto-generated)
├── sv_fit2.rds                              # Cached SV model PETR4 post
├── sv_fit3.rds                              # Cached SV model PETR4 recovery
├── compressed.txt                           # Flag file — PETR4 MCMC already run
└── compressed_ibm_v2.txt                    # Flag file — IBM MCMC already run
```

> **Note:** `.rds` cache files and flag `.txt` files are created automatically on first render. If they exist, MCMC is skipped and results are loaded from disk.

---

## Requirements

### R Packages

```r
install.packages(c(
  "ggplot2", "tidyr", "dplyr", "zoo", "xts", "forecast",
  "lubridate", "PerformanceAnalytics", "quantmod", "tseries",
  "FinTS", "stochvol", "cowplot", "wavelets", "gridExtra",
  "broom", "rugarch", "moments", "coda", "car", "boot",
  "knitr", "fpp2", "fpp3", "parsnip", "rsample"
))
```

### Software

- [R](https://www.r-project.org/) ≥ 4.2
- [Quarto](https://quarto.org/) ≥ 1.3

---

## Rendering

```bash
# IBM analysis
quarto render analise_volatilidade_ibm_3_op.qmd

# PETR4 analysis
quarto render analise_volatilidade_petr4_Q1.qmd
```

> **First render warning:** MCMC sampling (`svsample`) is computationally intensive. Expect ~10–30 minutes per segment depending on hardware. Subsequent renders load cached `.rds` files and complete in seconds.

---

## Methodology Notes

- **Stochastic Volatility model:** AR(1) log-volatility model estimated via MCMC using the `stochvol` package. Parameters: μ (long-run log-vol mean), φ (AR persistence), σ (volatility-of-volatility).
- **Realized Variance (RV):** ∑ rₜ²
- **Bipower Variation (BV):** (π/2)⁻¹ ∑ |rₜ| |rₜ₋₁| — robust to jumps.
- **Jump component:** max(RV − BV, 0); jump share = Jump / RV.
- **Annualised volatility:** √(RV/n) × √(252 × 390) (NYSE/B3 ~390 min/day).
- **MCMC thinning:** stored draws are systematically thinned to ≤ 2 000 per segment and saved with `compress = "xz"` to keep repository size manageable.

---

## Data Sources

| Asset | Exchange | Frequency | Source        | Period             |
|-------|----------|-----------|---------------|--------------------|
| IBM   | NYSE     | 1 min     | `IBM_data.csv`| See full series    |
| PETR4 | B3       | 1 min     | MetaTrader 5  | Jan – Jun 2021     |
