## convert and upload raw ESPN forecasts

library(zoltr)
library(dplyr)
library(jsonlite)
library(readr)

source("code/nba_csv_to_json.R")

## connect to Zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))

## urls obtained from API: https://zoltardata.com/api/project/328/
bpi_model_url <- "https://zoltardata.com/api/model/784/"

## load, transform and push data
bpi_files <- list.files("data/ESPN-BPI", pattern = "espn-bpi-raw", full.names = TRUE) 
bpi_dates <- list.files("data/ESPN-BPI", pattern = "espn-bpi-raw") |> 
  substr(14, 23)
bpi_jobs <- vector("list", length(bpi_files))

for(i in 1:length(bpi_files)) {
  nbacsv <- read_csv(bpi_files[i]) |> 
    mutate(unit = tolower(TEAM),
           unit = ifelse(unit=="uth", "uta", unit),
           # extract wins 
           wins = gsub( "-.*", "", `WIN-LOSS`),
           ## extract playoff probability, take care of extreme values
           `PLAY-OFFS` = ifelse(`PLAY-OFFS` == ">99.9%", 100, `PLAY-OFFS`),
           `PLAY-OFFS` = ifelse(`PLAY-OFFS` == "<0.1%", 0, `PLAY-OFFS`),
           make_playoffs = as.numeric(gsub( "%.*", "", `PLAY-OFFS`))/100,
           ## extract finals win probability, take care of extreme values
           `NBATITLE` = ifelse(`NBATITLE` == ">99.9%", 100, `NBATITLE`),
           `NBATITLE` = ifelse(`NBATITLE` == "<0.1%", 0, `NBATITLE`),
           win_finals = as.numeric(gsub( "%.*", "", `NBATITLE`))/100) 
  
  filename <- paste0("data/espn-bpi/ESPN-BPI-", bpi_dates[i], ".csv")
  write_csv(nbacsv, file=filename)
  
  bpi_json <- nba_csv_to_json(filename)
  bpi_jobs[[i]] <- upload_forecast(zoltar_connection, 
                                   bpi_model_url,
                                   timezero_date = bpi_dates[i],
                                   forecast_data = parse_json(bpi_json))
}

sapply(bpi_jobs, FUN=function(x) job_info(zoltar_connection, x)$status)
