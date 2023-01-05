library(rvest)
library(dplyr)
library(stringr)
library(readr)

read_html("https://www.espn.com/basketball/story/_/id/30427736/2020-21-nba-preview-wins-standings-projected-all-30-nba-teams") |> 
  html_elements("p:nth-child(111) , :nth-child(105), :nth-child(102), :nth-child(99), :nth-child(95), :nth-child(92), :nth-child(88), :nth-child(85), :nth-child(82), :nth-child(79), :nth-child(76), :nth-child(73), :nth-child(70), :nth-child(67), :nth-child(64), :nth-child(59), :nth-child(56), :nth-child(53), :nth-child(50), :nth-child(47), :nth-child(44), :nth-child(41), :nth-child(38), :nth-child(35), :nth-child(32), :nth-child(29), :nth-child(26), :nth-child(23), :nth-child(20), p:nth-child(17)")

tabs <- read_html("https://projects.fivethirtyeight.com/2022-nba-predictions/") |> 
  html_node("table") |> 
  html_node("tbody") |> 
  html_node("tr")

html <- read_html("https://projects.fivethirtyeight.com/2023-nba-predictions/")

## gets projected record
read_html("https://projects.fivethirtyeight.com/2023-nba-predictions/") |> 
  html_elements(".proj-rec") |> 
  html_text2()

## gets team
read_html("https://projects.fivethirtyeight.com/2023-nba-predictions/") |> 
  html_elements("#standings-table a") |> 
  html_text2()

## gets make playoff probability
read_html("https://projects.fivethirtyeight.com/2023-nba-predictions/") |> 
  html_elements(".make-playoffs") |> 
  html_text2()

## gets title win probability
read_html("https://projects.fivethirtyeight.com/2023-nba-predictions/") |> 
  html_elements(".pct:nth-child(12)") |> 
  html_text2()


## specifying a different forecast model

search <- html_form(html)[[3]] |>  ## picks the model field
  html_form_set(model = "Show our Elo forecast")

resp <- html_form_submit(search)
read_html(resp)
