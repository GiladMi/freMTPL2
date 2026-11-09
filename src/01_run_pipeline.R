library(DBI)
library(readr)
library(here)

db_path <- here("data", "actuarial_pricing.db")


if (!dir.exists(here("data"))) {
  dir.create(here("data"))
}

# Check and delete previous database
if (file.exists(db_path)) {
  message("Deleting old database...")
  file.remove(db_path)
}

con <- dbConnect(RSQLite::SQLite(), dbname = db_path)
message(sprintf("Connected to SQLite database (%s).", db_path))

# Read and write raw data
df_freq <- read_csv(here("data-raw", "freMTPL2freq.csv"))
df_claim <- read_csv(here("data-raw", "freMTPL2sev.csv"))

dbWriteTable(con, "policy_raw", df_freq, overwrite = TRUE)
dbWriteTable(con, "claim_raw", df_claim, overwrite = TRUE)

message("Ingested raw CSV data.")

# Execute every SQL statement in he pipeline
sql_script <- paste(readLines(here("scripts", "pipeline.sql")), collapse = "\n")

sql_statements <- strsplit(sql_script, ";")[[1]]
sql_statements <- trimws(sql_statements)
sql_statements <- sql_statements[nchar(sql_statements) > 0]

for (stmt in sql_statements) {
  dbExecute(con, stmt)
}
message("Executed SQL pipeline script")

db_final = dbReadTable(con, "modeling_data")
write_csv(db_final, here("data", "modeling_data.csv"))
message("Exported clean CSV modeling data!")

dbDisconnect(con)