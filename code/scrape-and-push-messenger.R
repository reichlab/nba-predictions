## scrape basketball refrence prediction data from
## https://themessenger.com/sports/nba-prediction-model-2023-24
## and upload to zoltar

library(rvest)
library(dplyr)
library(stringr)
library(readr)
library(zoltr)
library(tidyr)

source("code/nba_csv_to_json.R")

today <- Sys.Date()

## these links appear to be the "base" links at datawrapper for where the data live
base_url_composite_forecast <- "https://datawrapper.dwcdn.net/ybwJ6/"
base_url_messenger_forecast <- "https://datawrapper.dwcdn.net/9Dk2C/"
## after some exploration of the source, I found the following links to csv files
##    https://datawrapper.dwcdn.net/9Dk2C/29/dataset.csv
## the number before "dataset.csv" appears to maybe be the version of the forecast
## it appears to increment by one each day, website shows early AM updates.

## this function extracts the url with the version number
get_base_url <- function(url){
  require(rvest)
  require(stringr)
  read_html(url) |> 
    html_elements("meta") |> 
    (\(x) x[[1]])() |> 
    as.character() |> 
    ## url match pattern from https://stackoverflow.com/a/3809435/2942906
    stringr::str_extract(pattern = "https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)")
}

message("reading and munging data")

## get links to today's forecast versions
this_messenger_url <- get_base_url(base_url_messenger_forecast)
this_composite_url <- get_base_url(base_url_composite_forecast)

## read the data in
mess_only_raw <- read_tsv(paste0(this_messenger_url, "dataset.csv"), skip = 1)
mess_comp_raw <- read_tsv(paste0(this_composite_url, "dataset.csv"), skip = 1)

## load team name and units information
espn_names <- read_csv("code/espn-names.csv")

## put both forecasts in correct format
## noting that we are saying >99% = .99 and <0.1% =  0.001
mess_only <- mess_only_raw |> 
  left_join(espn_names, by=c("Team" = "messenger_team")) |> 
  mutate(
    wins = round(W),
    #`PO%` = ifelse(`PO%` == "—", "0", `PO%`),
    `Champ%` = ifelse(`Champ%` == "—", "0", `Champ%`),
    make_playoffs = ifelse(`CF%` == "—", "0", 1),
    win_finals = as.numeric(gsub( ">|<", "", `Champ%`))/100
  )

mess_comp <- mess_comp_raw |> 
  left_join(espn_names, by=c("Team" = "messenger_team")) |> 
  mutate(
    `Playoffs%` = ifelse(`Playoffs%` == "—", "0", `Playoffs%`),
    `Champ%` = ifelse(`Champ%` == "—", "0", `Champ%`),
    make_playoffs = as.numeric(gsub( ">|<", "", `Playoffs%`))/100,
    win_finals = as.numeric(gsub( ">|<", "", `Champ%`))/100
  )

## write out and transform both models
message("writing data")
filename <- paste0("model-output/Mess-only/Mess-only-", today, ".csv")
write_csv(mess_only, file=filename)
mess_only_json <- nba_csv_to_json(filename)

filename_comp <- paste0("model-output/Mess-comp/Mess-comp-", today, ".csv")
write_csv(mess_comp, file=filename_comp)
mess_comp_json <- nba_csv_to_json(filename_comp)


## write out raw data
write_csv(mess_only_raw, file=paste0("model-output/Mess-only/Mess-only-raw-", today, ".csv"))
write_csv(mess_comp_raw, file=paste0("model-output/Mess-comp/Mess-comp-raw-", today, ".csv"))

message("uploading data to zoltar")
## upload to zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))
Mess_only_model_url <- "https://zoltardata.com/api/model/891/"
Mess_comp_model_url <- "https://zoltardata.com/api/model/890/"
project_url <- "https://zoltardata.com/api/project/328/"

## check to see if timezero exists
all_t0 <- timezeros(zoltar_connection, project_url)
if(!(today %in% all_t0$timezero_date)){
  create_timezero(zoltar_connection, project_url,
                  timezero_date = today, 
                  data_version_date = NA)
}

## requires appropriate timezero
job_url <- upload_forecast(zoltar_connection, 
                           Mess_only_model_url,
                           timezero_date = as.character(today),
                           forecast_data = parse_json(mess_only_json))

job_url_comp <- upload_forecast(zoltar_connection, 
                                Mess_comp_model_url,
                                timezero_date = as.character(today),
                                forecast_data = parse_json(mess_comp_json))

Sys.sleep(5)

message("printing zoltar upload job info")
job_info(zoltar_connection, job_url)
job_info(zoltar_connection, job_url_comp)



