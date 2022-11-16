## scrape ESPN prediction data from
##  https://www.espn.com/nba/story/_/page/BPI-Playoff-Odds/espn-nba-basketball-power-index-playoff-odds
## and upload to zoltar

library(rvest)
library(dplyr)
library(stringr)
library(readr)
library(zoltr)

source("code/nba_csv_to_json.R")

today <- Sys.Date()

## read data, collapse to one DF
tabs <- read_html("https://www.espn.com/nba/story/_/page/BPI-Playoff-Odds/espn-nba-basketball-power-index-playoff-odds") |> 
  html_table() |> 
  (\(x) do.call(what=rbind, args=x))()

## put in correct format
nbacsv <- tabs |> 
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

filename <- paste0("model-output/espn-bpi/ESPN-BPI-", today, ".csv")
write_csv(nbacsv, file=filename)

bpi_json <- nba_csv_to_json(filename)

## write out raw data
write_csv(tabs, file=paste0("model-output/ESPN-BPI/espn-bpi-raw-", today, ".csv"))

## upload to zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))
bpi_model_url <- "https://zoltardata.com/api/model/784/"
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
                           bpi_model_url,
                           timezero_date = as.character(today),
                           forecast_data = parse_json(bpi_json))

Sys.sleep(5)

job_info(zoltar_connection, job_url)


