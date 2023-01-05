## scrape basketball refrence prediction data from
## https://www.basketball-reference.com/friv/playoff_prob.html
## and upload to zoltar

library(rvest)
library(dplyr)
library(stringr)
library(readr)
library(zoltr)
library(tidyr)

source("code/nba_csv_to_json.R")

today <- Sys.Date()

# the column names in original data are the first 2 rows
brm_colnames <- function(x){
  for (k in 1:length(x)) {
    old_names <- colnames(x[[k]]) 
    first_row <- x[[k]][1,]
    new_names <- paste0(old_names,first_row)
    new_names[2] <- "TEAM"
    colnames(x[[k]]) <- new_names
    x[[k]] <- x[[k]][-1,]
  }
  return(x)
}

## read data, collapse to one DF
message("reading and munging data")
tabs <- read_html("https://www.basketball-reference.com/friv/playoff_prob.html") |> 
  html_table() |>
  brm_colnames() |>
  (\(x) do.call(what=rbind, args=x))()

## load team name and units information
espn_names <- read_csv("code/espn-names.csv")

## put in correct format
nbacsv <- tabs |> 
  dplyr::select(-dplyr::starts_with(c("NA","First Round","Pre Play"))) |>
  dplyr::filter(!TEAM == "") |>
  mutate(# extract wins 
    TEAM = ifelse(TEAM == "Los Angeles Clippers", "LA Clippers", TEAM),
    wins = round(as.numeric(W),0),
    ## extract playoff probability, take care of extreme values
    Playoffs = ifelse(Playoffs == "", 0, Playoffs),
    make_playoffs = as.numeric(gsub( "%.*", "", Playoffs))/100,
    ## extract finals win probability, take care of extreme values
    `Win Finals` = ifelse(`Win Finals` == "", 0, `Win Finals`),
    win_finals = as.numeric(gsub( "%.*", "", `Win Finals`))/100)  %>%  
  # add unit column with abbreviation based on team name
  dplyr::full_join(x=.,y=espn_names, by = c("TEAM"="Team")) 
message("writing data")
filename <- paste0("model-output/BasketballRef/BasketballRef-", today, ".csv")
write_csv(nbacsv, file=filename)

BasketballRef_json <- nba_csv_to_json(filename)

## write out raw data
write_csv(tabs, file=paste0("model-output/BasketballRef/BasketballRef-raw-", today, ".csv"))

message("uploading data to zoltar")
## upload to zoltar
zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))
BasketballRef_model_url <- "https://zoltardata.com/api/model/804/"
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
                           BasketballRef_model_url,
                           timezero_date = as.character(today),
                           forecast_data = parse_json(BasketballRef_json))

Sys.sleep(5)

message("printing zoltar upload job info")
job_info(zoltar_connection, job_url)


