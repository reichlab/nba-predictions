## scrape 538-Elo and 538-RAPTOR prediction data from
## https://projects.fivethirtyeight.com/2023-nba-predictions/
## and upload to zoltar

library(rvest)
library(dplyr)
library(stringr)
library(readr)
library(zoltr)
library(tidyr)
library(XML)
library(rjson)

source("code/nba_csv_to_json.R")

today <- Sys.Date()


# load 538 data
data_538 <- rjson::fromJSON(file="https://projects.fivethirtyeight.com/2023-nba-predictions/data.json")

# find and extract the most recent data for each of the two models
forecast_dates <- data.frame(index = 1:length(data_538$weekly_forecasts$forecasts),
                             date = sapply(data_538$weekly_forecasts$forecasts,"[[",1))

latest_date_index <- forecast_dates[which(forecast_dates$date == max(forecast_dates$date)),]$index

last_forecast <- data_538$weekly_forecasts$forecasts[[latest_date_index]]$types


elo <- last_forecast$elo
raptor <- last_forecast$carmelo

elo.df <- as.data.frame(t(sapply(elo,c))) %>% 
  mutate_if(is.list,as.character)
raptor.df <- as.data.frame(t(sapply(raptor,c))) %>% 
  mutate_if(is.list,as.character)


# put in correct format 
nbacsv_elo <- elo.df |> 
  dplyr::transmute(TEAM = tolower(name),
                   unit = TEAM,
                   wins = as.numeric(wins),
                   make_playoffs = as.numeric(make_playoffs),
                   win_finals = as.numeric(win_finals)
                   )


nbacsv_raptor <- raptor.df |> 
  dplyr::transmute(TEAM = tolower(name),
                   unit = TEAM,
                   wins = as.numeric(wins),
                   make_playoffs = as.numeric(make_playoffs),
                   win_finals = as.numeric(win_finals)
  )



message("writing data")
filename_elo <- paste0("model-output/538-Elo/538-Elo-", today, ".csv")
filename_raptor <- paste0("model-output/538-RAPTOR/538-RAPTOR-", today, ".csv")
write_csv(nbacsv_elo, file=filename_elo)
write_csv(nbacsv_raptor, file=filename_raptor)

elo_json <- nba_csv_to_json(filename_elo)
raptor_json <- nba_csv_to_json(filename_raptor)

## write out raw data
write_csv(elo.df, file=paste0("model-output/538-Elo/538-Elo-raw-", today, ".csv"))
write_csv(raptor.df, file=paste0("model-output/538-RAPTOR/538-RAPTOR-raw-", today, ".csv"))

message("uploading data to zoltar")
## upload to zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))
elo_model_url <- "https://zoltardata.com/api/model/772/"
raptor_model_url <- "https://zoltardata.com/api/model/771/"
project_url <- "https://zoltardata.com/api/project/328/"

## check to see if timezero exists
all_t0 <- timezeros(zoltar_connection, project_url)
if(!(today %in% all_t0$timezero_date)){
  create_timezero(zoltar_connection, project_url,
                  timezero_date = today, 
                  data_version_date = NA)
}

## requires appropriate timezero
job_url_elo <- upload_forecast(zoltar_connection, 
                           elo_model_url,
                           timezero_date = as.character(today),
                           forecast_data = parse_json(elo_json))
job_url_raptor <- upload_forecast(zoltar_connection, 
                               raptor_model_url,
                               timezero_date = as.character(today),
                               forecast_data = parse_json(raptor_json))

Sys.sleep(10)

message("printing zoltar upload job info")
job_info(zoltar_connection, job_url_elo)
job_info(zoltar_connection, job_url_raptor)
