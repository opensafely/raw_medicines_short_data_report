# import librarys
library(here)
library(arrow)
library(tidyverse)
library(ggplot2)
library(lubridate)

# import dataset
df <- read_feather(here::here("output", "dataset.arrow"))

# skim the data
capture.output(
  skimr::skim_without_charts(df),
  file = here::here("output", "dataset_skim.txt"),
  split=FALSE
)

# inspect data
df_check <- df %>%
  summarise(
    total = n_distinct(patient_id),
    av_meds = mean(meds_row_no),
    av_reps = mean(repeats_row_no),
    av_meds_id = mean(meds_rep_id_no),
    av_meds_consult_id = mean(meds_consult_id_no),
    av_reps_id = mean(repeats_rep_id_no),
    av_reps_consult_id = mean(repeats_consult_id_no),
    n_ids_differ = sum(rep_ids_differ),
    av_concord = mean(concordant_dates),
    total_conord = sum(concordant_dates),
    av_discord = mean(discordant_dates),
    total_discord = sum(discordant_dates),
    av_start_first = mean(start_date_first),
    av_start_second = mean(start_date_second),
    av_active_repeats = mean(active_repeats)
  )

# save summary
write_csv(df_check, here::here("output", "dataset_check.csv"))

# do some other checks
df_miss <- df %>% 
  summarise(
    meds_rep_id = sum(medications_missing_rep_id),
    rep_date = sum(rep_missing_date),
    rep_start_date = sum(rep_missing_start_date),
    rep_end_date = sum(rep_missing_end_date),
  ) %>% 
  pivot_longer(
    cols = everything(),
    names_to = "missing_type",
    values_to = "total"
  ) %>% 
  mutate(
    frac = total/nrow(df)
  )

# save summary
write_csv(df_miss, here::here("output", "dataset_missing.csv"))

# medication status
df_status_med <- df %>% 
  select(contains("medications_status")) %>% 
  summarise(across(.cols = everything(), ~ sum(.x))) %>% 
  pivot_longer(
    cols = everything(),
    names_to = "status_type",
    names_prefix = "medications_status_",
    values_to = "med_count"
  ) %>% 
  mutate(
    "status" = case_when(
      status_type == 0 ~ "Normal",
      status_type == 4 ~ "Historical",
      status_type == 5 ~ "Blue script",
      status_type == 6 ~ "Private",
      status_type == 7 ~ "Not in possession",
      status_type == 8 ~ "Repeat dispensed",
      status_type == 9 ~ "In possession",
      status_type == 10 ~ "Dental",
      status_type == 11 ~ "Hospital",
      status_type == 12 ~ "Problem substance",
      status_type == 13 ~ "From patient group direction",
      status_type == 14 ~ "To take out",
      status_type == 15 ~ "On admission",
      status_type == 16 ~ "Regular medication",
      status_type == 17 ~ "As required medication",
      status_type == 18 ~ "Variable dose medication",
      status_type == 19 ~ "Rate-controlled single regular",
      status_type == 20 ~ "Only once",
      status_type == 21 ~ "Outpatient",
      status_type == 22 ~ "Rate-controlled multiple regular",
      status_type == 23 ~ "Rate-controlled multiple only once",
      status_type == 24 ~ "Rate-controlled single only once",
      status_type == 25 ~ "Placeholder",
      status_type == 26 ~ "Unconfirmed",
      status_type == 27 ~ "Infusion",
      status_type == 28 ~ "Reducing dose blue script",
      TRUE ~ "Other"
    ),
    .after = 1
  )

# repeate medication status
df_status_rep <- df %>% 
  select(contains("repeats_status")) %>% 
  summarise(across(.cols = everything(), ~ sum(.x))) %>% 
  pivot_longer(
    cols = everything(),
    names_to = "status_type",
    names_prefix = "repeats_status_",
    values_to = "rep_count"
  ) %>% 
  mutate(
    "status" = case_when(
      status_type == 0 ~ "Normal",
      status_type == 4 ~ "Historical",
      status_type == 5 ~ "Blue script",
      status_type == 6 ~ "Private",
      status_type == 7 ~ "Not in possession",
      status_type == 8 ~ "Repeat dispensed",
      status_type == 9 ~ "In possession",
      status_type == 10 ~ "Dental",
      status_type == 11 ~ "Hospital",
      status_type == 12 ~ "Problem substance",
      status_type == 13 ~ "From patient group direction",
      status_type == 14 ~ "To take out",
      status_type == 15 ~ "On admission",
      status_type == 16 ~ "Regular medication",
      status_type == 17 ~ "As required medication",
      status_type == 18 ~ "Variable dose medication",
      status_type == 19 ~ "Rate-controlled single regular",
      status_type == 20 ~ "Only once",
      status_type == 21 ~ "Outpatient",
      status_type == 22 ~ "Rate-controlled multiple regular",
      status_type == 23 ~ "Rate-controlled multiple only once",
      status_type == 24 ~ "Rate-controlled single only once",
      status_type == 25 ~ "Placeholder",
      status_type == 26 ~ "Unconfirmed",
      status_type == 27 ~ "Infusion",
      status_type == 28 ~ "Reducing dose blue script",
      TRUE ~ "Other"
    ),
    .after = 1
  )

# combine
df_status <- merge(df_status_med, df_status_rep)

# save
write_csv(df_status, here::here("output", "dataset_status.csv"))

# sample date distributions
df_dates <- df %>% 
  select(c(meds_sample_date, repeats_sample_date, 
           repeats_sample_start_date, repeats_sample_end_date)) %>% 
  # filter data to include only people with medicines data
  filter(if_any(.cols = c(meds_sample_date, repeats_sample_date), ~ !is.na(.x)))

df_dates_outliers <- bind_rows(
  missing_identifier = df_dates %>% 
    filter(if_any(.cols = everything(), ~ .x == as.Date("9999-12-31"))) %>% 
    summarise(across(everything(), ~ sum(.x, na.rm = TRUE))),
  prior_to_index = df_dates %>% 
    filter(if_any(.cols = everything(), ~ .x < as.Date("2025-01-01"))) %>% 
    summarise(across(everything(), ~ sum(.x, na.rm = TRUE))),
  long_post_index = df_dates %>% 
    filter(
      if_any(.cols = everything(),
             ~ .x > as.Date("2030-01-01") & .x != as.Date("9999-12-31"))
      ) %>% 
    summarise(across(everything(), ~ sum(.x, na.rm = TRUE))),
  .id = "outlier_type"
)

# save
write_csv(df_dates_outliers, here::here("output", "dataset_date_outliers.csv"))

sapply(df_dates, class)

# plot the date distributions
df_dates <- df_dates %>% 
  mutate(across(everything(), ~ as.Date(.x))) %>% 
  filter(if_any(.cols = everything(), ~ .x != as.Date("9999-12-31") & .x > as.Date("2025-01-01")))
med_date_plot <- df_dates %>% 
  ggplot() + geom_histogram(aes(x = meds_sample_date), binwidth = 365) +
  scale_x_date(date_breaks = "50 years", date_labels = "%Y-%m")
ggsave(here::here("output", "sample_med_date_plot.png"))
rep_date_plot <- df_dates %>% 
  ggplot() + geom_histogram(aes(x = repeats_sample_date), binwidth = 365) +
  scale_x_date(date_breaks = "50 years", date_labels = "%Y-%m")
ggsave(here::here("output", "sample_rep_date_plot.png"))
rep_start_date_plot <- df_dates %>% 
  ggplot() + geom_histogram(aes(x = repeats_sample_start_date), binwidth = 365) +
  scale_x_date(date_breaks = "50 years", date_labels = "%Y-%m")
ggsave(here::here("output", "sample_rep_start_date_plot.png"))
rep_end_date_plot <- df_dates %>% 
  ggplot() + geom_histogram(aes(x = repeats_sample_end_date), binwidth = 365) +
  scale_x_date(date_breaks = "50 years", date_labels = "%Y-%m")
ggsave(here::here("output", "sample_rep_end_date_plot.png"))
