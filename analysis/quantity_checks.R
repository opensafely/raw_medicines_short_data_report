library(tidyverse)
library(here)
library(arrow)
library(readr)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>% 
  select(c(patient_id, statin_quantity, statin_code, statin_quantity_rep, statin_code_rep,
           opioids_quantity, opioids_code, opioids_quantity_rep, opioids_code_rep))

# import codelists with uom
uom_statin <- read_csv(
  here::here("local_codelists", "user-emprestige-all-statins-uom.csv"),
  col_types = cols(code = col_character(),
                   term = col_character(),
                   dmd_id = col_character(),
                   dmd_type = col_character(),
                   uom = col_character())
  )
uom_opioids <- read_csv(
  here::here("local_codelists", "opensafely-high-dose-long-acting-opioids-openprescribing-dmd-uom.csv"),
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
    by = c("statin_code" = "code")
  ) %>%
  left_join(
    uom_statin %>% select(c(code, term, uom)) %>% rename(statin_term_rep = term, statin_uom_rep = uom),
    by = c("statin_code_rep" = "code")
  ) %>%
  left_join(
    uom_opioids %>% select(c(code, term, uom)) %>% rename(opioids_term = term, opioids_uom = uom),
    by = c("opioids_code" = "code")
  ) %>%
  left_join(
    uom_opioids %>% select(c(code, term, uom)) %>% rename(opioids_term_rep = term, opioids_uom_rep = uom),
    by = c("opioids_code_rep" = "code")
  )

# check to see how often the uom appears in the quantity
statin_sum <- df_with_uom %>%
  group_by(statin_uom) %>%
  summarise(
    n = n(),
    n_quantity_contains_uom = sum(str_detect(statin_quantity, statin_uom), na.rm = TRUE),
    n_quantity_rep_contains_uom = sum(str_detect(statin_quantity_rep, statin_uom_rep), na.rm = TRUE)
  ) %>%
  mutate(med_type = "statins")
opioids_sum <- df_with_uom %>%
  group_by(opioids_uom) %>%
  summarise(
    n = n(),
    n_quantity_contains_uom = sum(str_detect(opioids_quantity, opioids_uom), na.rm = TRUE),
    n_quantity_rep_contains_uom = sum(str_detect(opioids_quantity_rep, opioids_uom_rep), na.rm = TRUE)
  ) %>%
  mutate(med_type = "opioids")
sums <- bind_rows(statin_sum, opioids_sum)

# save
write_csv(sums, here::here("output", "quantity_uoms.csv"))