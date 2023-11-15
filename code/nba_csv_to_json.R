#' Convert an NBA CSV predictions file to JSON
#'
#' @param filename path to file for reading in
#'
#' @return Zoltar-ready Forecast file in JSON format
#'
#' @details CSV file in filename should have following columns
#'   - unit
#'   - wins
#'   - make_playoffs
#'   - win_finals

nba_csv_to_json <- function(filename) {
  require(dplyr)
  require(tidyr)
  require(jsonlite)
  nbacsv <- read.csv(filename, row.names = NULL)
  
  ## make binned forecasts for binary targets
  nbacsv_binary <- nbacsv |> 
    select(unit, make_playoffs, win_finals) |>
    rename(`make playoffs` = make_playoffs,
           `win finals` = win_finals) |> 
    pivot_longer(cols = -unit, names_to = "target", values_to = "prob") |> 
    mutate(class = "bin") 
  
  ## make nested list for cat field
  nbacsv_binary$cat <- replicate(nrow(nbacsv_binary), c(TRUE, FALSE), simplify=FALSE)
  
  ## make a list of lists with probabilities and insert as new column
  problist <- replicate(nrow(nbacsv_binary), c(TRUE, FALSE), simplify=FALSE)
  for(i in 1:nrow(nbacsv_binary)){
    problist[[i]] <- c(nbacsv_binary$prob[i], 1-nbacsv_binary$prob[i])
  }
  nbacsv_binary$prob <- problist
  
  ## make nested tibble for binary targets
  binary_nest <- tibble(nbacsv_binary[,c("unit", "target", "class")])
  binary_preds <- replicate(nrow(binary_nest), list(NULL), simplify=FALSE)
  for(i in 1:length(binary_preds)){
    binary_preds[[i]] <- list(cat = unlist(nbacsv_binary$cat[i]), 
                              prob = unlist(nbacsv_binary$prob[i]))
  }
  binary_nest$prediction <- binary_preds
  
  
  if("wins" %in% colnames(nbacsv)){
    ## make point forecasts for discrete target
    nbacsv_discrete <- nbacsv |> 
      select(unit, wins) |>
      rename(`season wins` = wins) |> 
      pivot_longer(cols = -unit, names_to = "target") |> 
      mutate(class = "point")
    
    ## make discrete nested tibble
    discrete_nest <- tibble(nbacsv_discrete[,c("unit", "target", "class")])
    discrete_preds <- replicate(nrow(discrete_nest), list(NULL), simplify=FALSE)
    for(i in 1:length(discrete_preds)){
      discrete_preds[[i]] <- as.list(nbacsv_discrete[i,"value"])
    }
    discrete_nest$prediction <- discrete_preds

    nba_nest <- bind_rows(discrete_nest, binary_nest)
  } else {
    nba_nest <- binary_nest
  }
  
  # toJSON(list(meta = NULL, predictions = discrete_nest),
  #        auto_unbox = TRUE, pretty=TRUE)

  # toJSON(list(meta = NULL, predictions = binary_nest),
  #        #auto_unbox = TRUE,
  #        #simplifyVector = TRUE,
  #        pretty=TRUE)
  
    
  # ## format for binary "categorical" prediction, from https://zoltardata.com/api/forecast/9753/data/
  # {
  #   "unit": "loc2",
  #   "target": "above baseline",
  #   "class": "bin",
  #   "prediction": {
  #     "cat": [
  #       true,
  #       false
  #     ],
  #     "prob": [
  #       0.9,
  #       0.1
  #     ]
  #   }
  #   }
  
  
  return(toJSON(list(meta = NULL, predictions = nba_nest), 
                auto_unbox = TRUE, pretty=TRUE))
}