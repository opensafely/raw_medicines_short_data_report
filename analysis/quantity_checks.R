library(tidyverse)
library(here)
library(arrow)
library(readr)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>% 
  select(c(patient_id, statin_quantity, statin_code, statin_quantity_rep, statin_code_rep,
           statin_code_med_with_rep, statin_quantity_med_with_rep, opioids_quantity, opioids_code,
           opioids_quantity_rep, opioids_code_rep, opioids_code_med_with_rep, opioids_quantity_med_with_rep,
           injections_quantity, injections_code, injections_oxy_quantity, injections_oxy_code, 
           inhalers_quantity, inhalers_code))

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
uom_injections <- read_csv(
  here::here("local_codelists", "opensafely-long-acting-injectable-and-depot-antipsychotics-dmd-uom.csv"),
  col_types = cols(code = col_character(),
                   term = col_character(),
                   dmd_id = col_character(),
                   dmd_type = col_character(),
                   uom = col_character())
  )
uom_injections_oxy <- read_csv(
  here::here("local_codelists", "opensafely-oxycodone-subcutaneous-dmd-uom.csv"),
  col_types = cols(code = col_character(),
                   term = col_character(),
                   dmd_id = col_character(),
                   dmd_type = col_character(),
                   uom = col_character())
  )
uom_inhalers <- read_csv(
  here::here("local_codelists", "user-emprestige-all-inhalers-dmd-uom.csv"),
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
  ) %>%
  left_join(
    uom_injections_oxy %>% select(c(code, term, uom)) %>% rename(injections_oxy_term = term, injections_oxy_uom = uom),
    by = c("injections_oxy_code" = "code")
  ) %>%
  left_join(
    uom_injections %>% select(c(code, term, uom)) %>% rename(injections_term = term, injections_uom = uom),
    by = c("injections_code" = "code")
  ) %>%
  left_join(
    uom_inhalers %>% select(c(code, term, uom)) %>% rename(inhalers_term = term, inhalers_uom = uom),
    by = c("inhalers_code" = "code")
  )

df_long <- df_with_uom %>%
  pivot_longer(
    cols = matches("^(statin|opioids|injections_oxy|injections|inhalers)_(quantity|code|term|uom)"),
    names_to = c("med", ".value", "record"),
    names_pattern = "^(statin|opioids|injections_oxy|injections|inhalers)_(quantity|code|term|uom)(_rep)?$",
    values_drop_na = FALSE
  ) %>%
  mutate(record = if_else(is.na(record), "issue", "repeat")) %>%
  filter(!is.na(code))  # optional: keep rows with a prescription

# check to see how often the uom appears in the quantity
sum <- df_long %>%
  group_by(med, record) %>%
  summarise(
    n = n(),
    n_quantity_contains_uom = sum(str_detect(quantity, uom), na.rm = TRUE)
  ) #%>%
#  mutate(med_type = "statins")

# save
write_csv(sums, here::here("output", "quantity_uoms.csv"))