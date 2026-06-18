library(tidyverse)
library(here)
library(arrow)
library(readr)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>% 
  select(c(patient_id, statin_quantity, statin_term, statin_quantity_rep, statin_term_rep,
           codeine_quantity, codeine_term, codeine_quantity_rep, codeine_term_rep))

# import codelists with uom
uom_statin <- read_csv(
  here::here("local_codelists", "user-emprestige-all-statins-uom.csv"),
  col_types = cols(code = col_character(),
                   term = col_character(),
                   dmd_id = col_character(),
                   dmd_type = col_character(),
                   uom = col_character())
  )
uom_codeine <- read_csv(
  here::here("local_codelists", "user-emprestige-codeine-for-pain-uom.csv"),
  col_types = cols(code = col_character(),
                   term = col_character(),
                   dmd_id = col_character(),
                   dmd_type = col_character(),
                   uom = col_character())
  )

# attach term + uom for each code column
df_with_uom <- df %>%
  left_join(
    uom_statin %>% select(c(code, term, uom)) %>% rename(statin_term = term, statin_uom = uom),
    by = c("statin_term" = "code")
  ) %>%
  left_join(
    uom_statin %>% select(c(code, term, uom)) %>% rename(statin_term_rep = term, statin_uom_rep = uom),
    by = c("statin_term_rep" = "code")
  ) %>%
  left_join(
    uom_codeine %>% select(c(code, term, uom)) %>% rename(codeine_term = term, codeine_uom = uom),
    by = c("codeine_term" = "code")
  ) %>%
  left_join(
    uom_codeine %>% select(c(code, term, uom)) %>% rename(codeine_term_rep = term, codeine_uom_rep = uom),
    by = c("codeine_term_rep" = "code")
  )

# skim the data
capture.output(
  df_with_uom %>%
    skimr::skim_without_charts(),
  file = here::here("output", "quantity_skim.txt"),
  split = FALSE
)
