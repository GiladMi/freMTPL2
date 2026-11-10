# freMTPL2 - Motor Insurance Pricing with GLMs

An end-to-end actuarial pricing pipeline on the freMTPL2 French motor third-party liability (MTPL) portfolio: SQL data preparation, Poisson / Gamma / Tweedie GLMs for claim frequency, severity and pure premium, segment-level validation, and rating relativities exported to an Excel/VBA rating calculator.

## Data

| | |
|---|---|
| Policies | 678,013 (678,010 after dropping 3 drivers aged exactly 100, who fall outside the age bands) |
| Exposure | 358,498 policy-years |
| Paid claims | 26,444 on 24,944 policies (claim frequency 0.074 per policy-year) |
| Severity | mean capped loss of €1,559 per policy with a paid claim |
| Rating factors | driver age band, vehicle power, vehicle brand, area (A-F) |

Source files (`data-raw/`): `freMTPL2freq.csv` (policy risk features and exposure) and `freMTPL2sev.csv` (individual claim amounts).

**Data preparation** (`scripts/pipeline.sql`, run in SQLite):
- Defensive defaults for missing risk features, and exposure recorded in days converted to years. None of these trigger on this file (no missing values; exposure ranges from 0.003 to 2.01 years).
- Claims aggregated per policy and **capped at €10,000 per policy** to limit the influence of large losses on the GLM fits.
- Claims joined to policies. 6 policy IDs in the claims file (195 claims) have no matching policy record and are excluded.

## Models

| Model | Family / link | Target | Specification |
|---|---|---|---|
| Frequency | Poisson, log | paid claim count | offset `log(exposure)` |
| Severity | Gamma, log | capped average cost per claim | weights = claim count, policies with at least one claim |
| Pure premium | Tweedie, log | capped loss per exposure-year | weights = exposure; power parameter *p* chosen by maximum-likelihood profiling on a 10% sample |

Driver age is binned (<25, 25-34, 35-44, 45-54, 55-64, 65+; <25 is the base level), vehicle power enters as a continuous variable, and brand and area are categorical.

## Results

### Frequency relativities (Poisson GLM)

Multiplicative effect on claim frequency versus the base level, holding the other factors fixed.

| Driver age | Relativity vs. <25 | | Area | Relativity vs. A |
|---|---|---|---|---|
| 25-34 | 0.47 | | B | 1.12 |
| 35-44 | 0.44 | | C | 1.24 |
| 45-54 | 0.48 | | D | 1.53 |
| 55-64 | 0.40 | | E | 1.77 |
| 65+ | 0.39 | | F | 1.85 |

Drivers under 25 claim about 2.1 times as often as drivers aged 25-34 and about 2.6 times as often as drivers aged 65+. Frequency rises steadily from Area A to Area F. Severity varies far less than frequency: most severity relativities lie within ±15% of the base level.

### Validation: predicted vs. actual pure premium (in-sample)

Both the frequency x severity model and the Tweedie model reproduce the actual capped pure premium of **€108.46 per policy-year** at portfolio level, and each area to within ±1%:

| Area | Exposure (years) | Actual pure premium (€/year) |
|---|---|---|
| A | 61,969 | 77.38 |
| B | 43,012 | 89.53 |
| C | 104,447 | 98.27 |
| D | 77,120 | 124.90 |
| E | 63,819 | 146.60 |
| F | 8,129 | 121.04 |

`src/05_model_validation.R` prints this comparison and writes `results/segment_res.csv`.

## Rating calculator (Excel / VBA)

`src/06_export_coef.R` exports the relativities of all three models and their base rates (the exponentiated intercepts) to `reporting/outputs/`. The VBA modules in `reporting/vba/` turn them into a rating engine:

- `modImportCoefficients` loads `coefficients.csv` into the `Coefficients` sheet.
- `modCalculator` reads four inputs from the `Calculator` sheet (`B3:B6`: age band, vehicle power, brand, area), multiplies the base rate by the matching relativities, and outputs expected frequency, severity, pure premium, a 20% expense and profit loading, and the final premium (`B9:B13`).
- `modHelper` refreshes the coefficients and clears the calculator.

## Repository structure

| Path | Contents |
|---|---|
| `scripts/pipeline.sql` | Data cleaning, claim aggregation and modeling table (SQLite) |
| `src/01_run_pipeline.R` | Loads the CSVs into SQLite, runs the SQL, exports `modeling_data.csv` |
| `src/02_glm_modeling.R` | Factor encoding, age bands, log-exposure |
| `src/03_freq_sev_models.R` | Poisson frequency and Gamma severity GLMs |
| `src/04_tweedie_model.R` | Tweedie power profiling and pure-premium GLM |
| `src/05_model_validation.R` | Actual vs. predicted pure premium, portfolio and by area |
| `src/06_export_coef.R` | Relativities and base rates for the workbook |
| `reporting/` | Exported CSVs, VBA modules, Excel workbook |

## Build Instructions

### Prerequisites

- [**R**](https://www.r-project.org/) (version 4.0 or higher recommended)
- [**RStudio**](https://posit.co/downloads) (optional, but highly recommended)
- Microsoft Excel (only for the rating calculator)

### Setup and Execution

1. Clone and navigate to the repository.
2. In the R console, run `renv::restore()` to install the missing packages.
3. Run the scripts in `src/` in order, `01` to `06`. The Tweedie profiling in `04` can take several minutes.
4. Intermediate data is written to `data/`, validation tables to `results/`, and workbook inputs to `reporting/outputs/`.
5. In Excel, import the modules from `reporting/vba/` into `reporting/pricing_workbook.xlsx` and run `RefreshAll` to load the coefficients.

## Status and next steps

- Plots: relativity charts and actual-vs-predicted by segment.
- Workbook: the sheets are in place, but the Calculator layout and rate card still need to be built.
- Validation is in-sample; a hold-out set or cross-validation would test out-of-sample performance.
- Extend the rating factors (vehicle age, fuel type, density, region, bonus-malus), which are prepared in the data but not yet used.
