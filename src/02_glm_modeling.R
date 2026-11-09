library(dplyr)
library(tidyr)
library(readr)
library(here)

if(!file.exists(here("data", "modeling_data.csv"))) {
  stop("Modeling data CSV not found! Make sure to run 01_run_pipeline.R first.")
}

df <- read_csv(here("data", "modeling_data.csv"))

df <- df |>
  mutate(
    VehBrand = as.factor(VehBrand),
    VehGas = as.factor(VehGas),
    Region = as.factor(Region),
    Area = as.factor(Area),
    
    # Split drivers into age groups (bins)
    DrivAge_Bin = cut(DrivAge, breaks = c(0, 25, 35, 45, 55, 65, 100),
                      lables = c("<25", "25-34", "35-44", "45-54", "55-64", "65+"),
                      right = FALSE),
    
    # log continuous data for the GLM
    log_Exposure = log(Exposure)
  ) |>
  drop_na(VehBrand, VehGas, Region, Area, DrivAge_Bin)

# Print for checks
cat("Total Policies:", nrow(df), "\n")
cat("Policies with >= 1 Paid Claim:", sum(df$Sev_ClaimCount > 0), "\n")
cat("Overall Paid Claim Frequency:", sum(df$Sev_ClaimCount) / sum(df$Exposure), "\n")
cat("Average Severity (for policies with claims):", 
    sum(df$Total_Severity) / sum(df$Sev_ClaimCount > 0), "\n")


saveRDS(df, here("data", "modeling_data_prepped.rds"))