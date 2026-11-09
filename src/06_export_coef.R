library(dplyr)
library(here)

freq_model <- readRDS(here("data", "freq_model.rds"))
sev_model <- readRDS(here("data", "sev_model.rds"))
tweedie_model <- readRDS(here("data", "tweedie_model.rds"))

# Extract and exponentiate coefficients
extract_relativities <- function(model, model_name) {
  coefs <- coef(model)
  data.frame(
    Model = model_name,
    Factor = names(coefs),
    Relativitiy = exp(coefs),
    stringsAsFactors = FALSE
  )
}

freq_rel <- extract_relativities(freq_model, "Frequency")
sev_rel <- extract_relativities(sev_model, "Severity")
tweedie_rel <- extract_relativities(tweedie_model, "Tweedie")

# Parse factor names to separate Factor and Level
extract_clean <- function(model, model_name) {
  coefs <- coef(model)
  xlevels <- model$xlevels  # Stores factor levels
  
  result <- list()
  
  for (nm in names(coefs)) {
    if (nm == "(Intercept)") {
      # Intercept
      result[[length(result) + 1]] <- data.frame(
        Model = model_name, Factor = "Intercept", Level = "",
        Relativitiy = exp(coefs[nm]), Type = "Base",
        Coefficient = coefs[nm],
        stringsAsFactors = FALSE
      )
    } else if (grepl("\\[", nm)) {
      # Binned continuous variable like DrivAge_Bin[25,35)
      var_name <- gsub("\\[.*", "", nm)
      lvl <- gsub(".*\\[|\\)]", "", nm)
      lvl <- gsub(",", "-", lvl)
      lvl <- gsub("\\)$", "", lvl)
      
      result[[length(result) + 1]] <- data.frame(
        Model = model_name, Factor = var_name, Level = lvl,
        Relativitiy = exp(coefs[nm]), Type = "Categorical",
        Coefficient = coefs[nm],
        stringsAsFactors = FALSE
      )
    } else {
      # Try to match against xlevels (for categorical variables)
      matched <- FALSE
      for (var_name in names(xlevels)) {
        for (lvl in xlevels[[var_name]]) {
          expected_name <- paste0(var_name, lvl)
          if (nm == expected_name) {
            result[[length(result) + 1]] <- data.frame(
              Model = model_name, Factor = var_name, Level = lvl,
              Relativitiy = exp(coefs[nm]), Type = "Categorical",
              Coefficient = coefs[nm],
              stringsAsFactors = FALSE
            )
            matched <- TRUE
            break
          }
        }
        if (matched) break
      }
      
      # If not matched, it's a continuous variable
      if (!matched) {
        result[[length(result) + 1]] <- data.frame(
          Model = model_name, Factor = nm, Level = "",
          Relativitiy = exp(coefs[nm]), Type = "Continuous",
          Coefficient = coefs[nm],
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  do.call(rbind, result)
}

freq_rel <- extract_clean(freq_model, "Frequency")
sev_rel <- extract_clean(sev_model, "Severity")
tweedie_rel <- extract_clean(tweedie_model, "Tweedie")

rename(freq_rel, Freq_Rel = Relativitiy, Freq_Coef = Coefficient)
rename(sev_rel, Sev_Rel = Relativitiy, Sev_Coef = Coefficient)
rename(tweedie_rel, Tweedie_Rel = Relativitiy, Tweedie_Coef = Coefficient)

# Merge all models into one table
coefficients_table <- freq_rel |>
  full_join(sev_rel, by = c("Model", "Factor", "Level", "Type", "Relativitiy", "Coefficient")) |>
  full_join(tweedie_rel, by = c("Model", "Factor", "Level", "Type", "Relativitiy", "Coefficient")) |>
  # Fill NAs with 1.0 for relativities and 0 for coefficients
  mutate(
    Relativitiy = ifelse(is.na(Relativitiy), 1.0, Relativitiy),
    Coefficient = ifelse(is.na(Coefficient), 0, Coefficient)
  ) |>
  select(Model, Factor, Level, Type, Relativitiy, Coefficient)

# Add base rates (the intercept values)
base_rates <- data.frame(
  Metric = c("Base Frequency (claims/year)", 
             "Base Severity (€/claim)", 
             "Base Pure Premium (€/year)"),
  Value = c(exp(coef(freq_model)[1]),
            exp(coef(sev_model)[1]),
            exp(coef(tweedie_model)[1]))
)

# Export
if (!dir.exists(here("reporting", "outputs"))) {
  dir.create(here("reporting", "outputs"), recursive = TRUE)
}

write_csv(coefficients_table, 
          here("reporting", "outputs", "coefficients.csv"))

write_csv(base_rates, 
          here("reporting", "outputs", "base_rates.csv"))

cat(sprintf("  Base Frequency: %.4f claims/year\n", base_rates$Value[1]))
cat(sprintf("  Base Severity:  €%.2f\n", base_rates$Value[2]))
cat(sprintf("  Base Pure Premium: €%.2f\n", base_rates$Value[3]))