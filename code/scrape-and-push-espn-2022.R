## scrape ESPN prediction data from
##  https://www.espn.com/nba/story/_/page/BPI-Playoff-Odds/espn-nba-basketball-power-index-playoff-odds
## and upload to zoltar

library(rvest)
library(dplyr)
library(stringr)
library(readr)
library(zoltr)
library(tidyr)

source("code/nba_csv_to_json.R")

today <- Sys.Date()

## read data, collapse to one DF
message("reading and munging data")
tabs <- read_html("https://www.espn.com/nba/bpi/_/view/projections") |> 
  html_table() |> 
  (\(x) do.call(what=cbind, args=x))() |> 
  left_join(read_csv("code/espn-names.csv"))

## read in and munge playoff probs
tabs_playoffs <- read_html("https://www.espn.com/nba/bpi/_/view/playoffs") |> 
  html_table() |> 
  (\(x) do.call(what=cbind, args=x))()
## move double-layered header rows to colnames
colnames(tabs_playoffs) <- tabs_playoffs[1,]
## remove first row of data and merge with unit names
tabs_playoffs <- tabs_playoffs[-1,] |> 
  left_join(read_csv("code/espn-names.csv")) |> 
  mutate(win_finals = as.numeric(`WIN TITLE%`)/100) |> 
  select(unit, win_finals)


## put in correct format
nbacsv <- tabs |> 
  mutate(# extract wins 
         wins = round(as.numeric(gsub( "-.*", "", `OVR W-L`))),
         make_playoffs = as.numeric(`PLAYOFF%`)/100) |> 
  left_join(tabs_playoffs) |> 
  select(unit, wins, make_playoffs, win_finals)

message("writing data")
filename <- paste0("model-output/ESPN-BPI/ESPN-BPI-", today, ".csv")
write_csv(nbacsv, file=filename)

bpi_json <- nba_csv_to_json(filename)

## write out raw data, commented out Dec 2022
## write_csv(tabs, file=paste0("model-output/ESPN-BPI/espn-bpi-raw-", today, ".csv"))

message("uploading data to zoltar")
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

message("printing zoltar upload job info")
job_info(zoltar_connection, job_url)


