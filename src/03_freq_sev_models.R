library(dplyr)
library(here)

df <- readRDS(here("data", "modeling_data_prepped.rds"))

# Select the variables we want as predictors (can be experimented on)
vars_to_keep <- c("Exposure", "log_Exposure", "Sev_ClaimCount", "Total_Severity",
                  "DrivAge_Bin", "VehPower", "VehBrand", "Area")
df_model <- df |> select(all_of(vars_to_keep))

# Frequency Model (Poisson GLM)
# Target: Sev_ClaimCount (Number of paid claims)
# Offset: log_Exposure
# log(y/l_xp) = x_0 + beta_1 * x_1 + ... + beta_n * x_n -> log(y) = x_0 + beta_1 * x_1 + ... + beta_n * x_n + log(l_xp)

freq_model <- glm(
  Sev_ClaimCount ~ DrivAge_Bin + VehPower + VehBrand + Area,
  family = poisson(link = "log"),
  data = df_model,
  offset = log_Exposure
)

print(summary(freq_model))

saveRDS(freq_model, here("data", "freq_model.rds"))

# Severity Model (Gamma GLM)
# Target: average 'capped' severity PER CLAIM, weighted by the number of claims.
# (Fitting the policy-level total and then multiplying by the expected claim COUNT
# double-counts policies with several claims: ~+6% bias on the portfolio.)

df_sev <- df_model |>
  filter(Sev_ClaimCount > 0) |>
  mutate(Avg_Severity = Total_Severity / Sev_ClaimCount)

sev_model <- glm(
  Avg_Severity ~ DrivAge_Bin + VehPower + VehBrand + Area,
  family = Gamma(link = "log"),
  data = df_sev,
  weights = Sev_ClaimCount
)

print(summary(sev_model))

saveRDS(sev_model, here("data", "sev_model.rds"))

# Get exp coefficients (relatives)

cat("\n--- FREQUENCY RELATIVITIES (Exponentiated Coefficients) ---\n")
freq_coef <- coef(freq_model)
print(exp(freq_coef))

cat("\n--- SEVERITY RELATIVITIES (Exponentiated Coefficients) ---\n")
sev_coefs <- coef(sev_model)
print(exp(sev_coefs))