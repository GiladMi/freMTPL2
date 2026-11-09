# Tweedie GLM for pure premium models

library(statmod)
library(tweedie)
library(dplyr)
library(here)

df_model <- readRDS(here("data", "modeling_data_prepped.rds")) |>
  select(Exposure, log_Exposure, Total_Severity, DrivAge_Bin, VehPower, VehBrand, Area)

# We use Tweedie profiling using MLE to find optimal 'p' (power) parameter of distribution
# Optimize by random sampling
set.seed(42)
sample_size <- floor(nrow(df_model) * 0.10)
df_sample <- df_model |> sample_n(sample_size)
#
message("Profiling tweedie paramter 'p'; this may take a while!")
twe_profile <- tweedie_profile(
  Total_Severity ~ DrivAge_Bin + VehPower + VehBrand + Area,
  #p.vec = seq(1.1, 1.9, by = 0.1),
  link.power = 0, # log link
  data = df_sample,
  offset = log_Exposure
)

opt_p <- twe_profile$xi.max

#opt_p = 1.5

tweedie_model <- glm(
  Total_Severity ~ DrivAge_Bin + VehPower + VehBrand + Area,
  family = tweedie(var.power = opt_p, link.power = 0),
  data = df_model,
  offset = log_Exposure
)

print(summary(tweedie_model))

cat("\n--- TWEEDIE RELATIVITIES (Pure Premium Multipliers) ---\n")
print(exp(coef(tweedie_model)))

saveRDS(tweedie_model, here("data", "tweedie_model.rds"))