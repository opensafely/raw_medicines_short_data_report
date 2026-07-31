library(tidyverse)
library(here)
library(arrow)
library(readr)
library(ggplot2)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>% 
  filter(meds_exist) %>%
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
sums <- df_long %>%
  group_by(med, record) %>%
  summarise(
    n = n(),
    n_quantity_contains_uom = sum(str_detect(quantity, uom), na.rm = TRUE),
    perc = (n_quantity_contains_uom/n)*100
  ) #%>%
#  mutate(med_type = "statins")

# save
write_csv(sums, here::here("output", "quantity_uoms.csv"))

# look at the medications associated with the quantity
dmds_for_quants <- df_with_uom %>%
  select(contains("code")) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "value"
  ) %>%
  #filter(!is.na(value) & value != "") %>%
  count(variable, value) %>%
  group_by(variable) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

# keep only top 10 categories per variable for plotting
plot_data <- dmds_for_quants %>%
  group_by(variable) %>%
  slice_max(order_by = prop, n = 10, with_ties = FALSE) %>%
  ungroup()

# visualise
visual_sum <- ggplot(
  plot_data,
  aes(
    x = reorder(value, prop),
    y = prop,
    fill = variable
  )
) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  facet_wrap(~ variable, scales = "free_y") +
  scale_y_continuous(labels = percent_format()) +
  geom_text(
    aes(label = percent(prop, accuracy = 0.1)),
    hjust = -0.1,
    size = 3
  ) +
  #expand_limits(y = max(text_based$prop) * 1.15) +
  labs(
    title = "Proportion of dm+d Codes",
    x = NULL,
    y = "Proportion"
  ) +
  theme_minimal()

# save 
ggsave(here::here("output", "dmd_from_quants_summary_plot.png"))

# look at the medications associated with the quantity
terms_for_quants <- df_with_uom %>%
  select(contains("term")) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "value"
  ) %>%
  #filter(!is.na(value) & value != "") %>%
  count(variable, value) %>%
  group_by(variable) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

# keep only top 10 categories per variable for plotting
plot_data <- terms_for_quants %>%
  group_by(variable) %>%
  slice_max(order_by = prop, n = 10, with_ties = FALSE) %>%
  ungroup()

# visualise
visual_sum_terms <- ggplot(
  plot_data,
  aes(
    x = reorder(value, prop),
    y = prop,
    fill = variable
  )
) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  facet_wrap(~ variable, scales = "free_y") +
  scale_y_continuous(labels = percent_format()) +
  geom_text(
    aes(label = percent(prop, accuracy = 0.1)),
    hjust = -0.1,
    size = 3
  ) +
  #expand_limits(y = max(text_based$prop) * 1.15) +
  labs(
    title = "Proportion of Terms",
    x = NULL,
    y = "Proportion"
  ) +
  theme_minimal()

# save 
ggsave(here::here("output", "dmd_from_quants_summary_plot.png"))
