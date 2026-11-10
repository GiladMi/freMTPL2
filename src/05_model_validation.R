# Compare our fitted models: freq-sev vs tweedie

library(dplyr)
library(readr)
library(here)

df_model <- readRDS(here("data", "modeling_data_prepped.rds")) |>
  select(Exposure, log_Exposure, Total_Severity, DrivAge_Bin, VehPower, VehBrand, Area, Sev_ClaimCount)

freq_model <- readRDS(here("data", "freq_model.rds"))
sev_model <- readRDS(here("data", "sev_model.rds"))
tweedie_model <- readRDS(here("data", "tweedie_model.rds"))

# Calculate freq-sev prediction
df_model$Pred_Freq <- predict(freq_model, newdata = df_model, type = "response")

# Predict severity per. claim
df_model$Pred_Sev <- predict(sev_model, newdata = df_model, type = "response")

# Pure Premium = Freq x Sev
# E[Agg] = E[Freq] x E[Sev|Claim>0]
df_model$Pred_PP_FreqSev <- df_model$Pred_Freq * df_model$Pred_Sev

# Calculate Tweedie model prediction
# The Tweedie model predicts pure premium PER EXPOSURE-YEAR, so scale by Exposure to get expected loss
df_model$Pred_PP_Tweedie <- predict(tweedie_model, newdata = df_model, type = "response") * df_model$Exposure

cat("\n=== ACTUARIAL MODEL VALIDATION ===\n")
cat(sprintf("Actual Portfolio Pure Premium:      €%.2f\n", 
            sum(df_model$Total_Severity) / sum(df_model$Exposure)))
cat(sprintf("Predicted (Freq-Sev) Pure Premium:  €%.2f\n", 
            sum(df_model$Pred_PP_FreqSev) / sum(df_model$Exposure)))
cat(sprintf("Predicted (Tweedie) Pure Premium:   €%.2f\n", 
            sum(df_model$Pred_PP_Tweedie) / sum(df_model$Exposure)))

cat("\n=== SEGMENT-LEVEL VALIDATION (By Area) ===\n")
segment_validation <- df_model |>
  group_by(Area) |>
  summarise(
    Exposure = sum(Exposure),
    Actual_Loss = sum(Total_Severity),
    Actual_PP = Actual_Loss / Exposure,
    Pred_PP_FreqSev = sum(Pred_PP_FreqSev) / Exposure,
    Pred_PP_Tweedie = sum(Pred_PP_Tweedie) / Exposure,
    FreqSev_Ratio = Pred_PP_FreqSev / Actual_PP,
    Tweedie_Ratio = Pred_PP_Tweedie / Actual_PP
  )

print(segment_validation)


if (!dir.exists(here("results"))) {
  dir.create(here("results"))
}

write_csv(df_model, here("results", "scored_policies.csv"))
write_csv(segment_validation, here("results", "segment_res.csv"))