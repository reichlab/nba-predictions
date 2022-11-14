## upload truth
library(zoltr)
library(dplyr)

zoltar_connection <- new_connection()
zoltar_authenticate(zoltar_connection, Sys.getenv("Z_USERNAME"), Sys.getenv("Z_PASSWORD"))
project_url <- "https://zoltardata.com/api/project/328/"

## manually entered timezeros for the two seasons
s1_t0 <- c(as.Date("2020-12-01"), as.Date("2020-12-17"))
s2_t0 <- c(as.Date("2021-10-13"), as.Date("2021-10-19"))

## load the two seasons' truth data
s1_truth <- read.csv("target-data/nba-truth-2020-2021.csv") |> 
  mutate(value = tolower(value))  
s2_truth <- read.csv("target-data/nba-truth-2021-2022.csv") |> 
  mutate(value = tolower(value))  

## function to append timezero column to truth data
append_truth <- function(timezero, truthdata){
  cbind(timezero = timezero, truthdata)
}

## bind and load truth
s1_truth_all <- do.call(rbind, lapply(s1_t0, FUN=append_truth, truthdata=s1_truth))
s2_truth_all <- do.call(rbind, lapply(s2_t0, FUN=append_truth, truthdata=s2_truth))


tmp_path <- "target-data/nba-truth-all-timezeroes.csv"
write.csv(rbind(s1_truth_all, s2_truth_all), 
          file = tmp_path, 
          quote=FALSE, row.names = FALSE)
tmp <- upload_truth(zoltar_connection, project_url, truth_csv_file = tmp_path)
job_info(zoltar_connection, tmp)
