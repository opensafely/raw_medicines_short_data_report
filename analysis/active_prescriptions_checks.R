library(tidyverse)
library(here)
library(arrow)
library(readr)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>% 
  filter(meds_exist) %>%
  select(c(patient_id, contains("matching"))) %>% 
  filter(matching_row)

# skim the data
capture.output(
  df %>% skimr::skim_without_charts(),
  file = here::here("output", "active_prescriptions_skim.txt"),
  split = FALSE
)
