library(zoltr)
library(dplyr)
library(jsonlite)

source("code/nba_csv_to_json.R")

## connect to Zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))

## urls obtained from API: https://zoltardata.com/api/project/328/
elo_model_url <- "https://zoltardata.com/api/model/772/" 
raptor_model_url <- "https://zoltardata.com/api/model/771/" 
bpi_model_url <- "https://zoltardata.com/api/model/784/"

## load, transform and push data

## RAPTOR model
raptor_files <- list.files("data/538-RAPTOR", full.names = TRUE) 
raptor_dates <- list.files("data/538-RAPTOR") |> 
  substr(12, 21)
raptor_jobs <- vector("list", length(raptor_files))

for(i in 1:length(raptor_files)) {
  raptor_json <- nba_csv_to_json(raptor_files[i])
  job_url <- upload_forecast(zoltar_connection, 
                             raptor_model_url,
                             timezero_date = raptor_dates[i],
                             forecast_data = parse_json(raptor_json))
  raptor_jobs[[i]] <- job_info(zoltar_connection, job_url)
}

## Elo model
elo_files <- list.files("data/538-Elo", full.names = TRUE) 
elo_dates <- list.files("data/538-Elo") |> 
  substr(9, 18)
elo_jobs <- vector("list", length(elo_files))

for(i in 1:length(elo_files)) {
  elo_json <- nba_csv_to_json(elo_files[i])
  job_url <- upload_forecast(zoltar_connection, 
                             elo_model_url,
                             timezero_date = elo_dates[i],
                             forecast_data = parse_json(elo_json))
  elo_jobs[[i]] <- job_info(zoltar_connection, job_url)
}

# jobs weren't finished
# sapply(elo_jobs, function(x) x$status)
