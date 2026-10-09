# script for a broadly flexible set of checks for any prescription
library(here)
library(arrow)
library(readr)
library(tidyverse)
library(ggplot2)
library(scales)

# define the expected column names
col_names <- function(prescription) {
  paste0(
    prescription,
    c(
      "_issue", "_repeat", "_repeat_issue",
      "_issue_quantity", "_issue_code",
      "_repeat_quantity", "_repeat_code",
      "_repeat_issue_quantity", "_repeat_issue_code"
    )
  )
}

# import the dataset
df <- read_feather(here::here("output", "dataset.arrow")) %>%
  filter(meds_exist) %>%
  select(
    patient_id,
    all_of(c(
      col_names("acute_med_1"),
      col_names("acute_med_2"),
      col_names("repeat_med_1"),
      col_names("repeat_med_2"),
      col_names("field_test")
    ))
  )

# create output directory
fs::dir_create(here::here("output", "generic_prescriptions"))

# skim the data
capture.output(
  df %>% skimr::skim_without_charts(),
  file = here::here("output", "generic_prescriptions", "generic_prescriptions_skim.txt"),
  split = FALSE
)

# get summary of counts 
summarise_counts <- function(prescription) {
  
  issue_col <- paste0(prescription, "_issue")
  repeat_col <- paste0(prescription, "_repeat")
  repeat_issue_col <- paste0(prescription, "_repeat_issue")
  
  sums <- df %>%
    summarise(
      av_issues = mean(.data[[issue_col]], na.rm = TRUE),
      av_repeats = mean(.data[[repeat_col]], na.rm = TRUE),
      av_repeat_issues = mean(.data[[repeat_issue_col]], na.rm = TRUE)
    )
  
  write_csv(sums, here::here("output", "generic_prescriptions", 
                             paste0(prescription, "_prescribing.csv")))
  
}

summarise_counts("acute_med_1")
summarise_counts("acute_med_2")
summarise_counts("repeat_med_1")
summarise_counts("repeat_med_2")
summarise_counts("field_test")

## quantities

# get missing quantities
text_based_missing <- df %>%
  select(contains("quantity")) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "value"
  ) %>%
  count(variable, value) %>%
  group_by(variable) %>%
  mutate(prop = n / sum(n)) %>%
  filter(is.na(value)|value == "") %>%
  ungroup()

# save
write_csv(text_based_missing, here::here("output", "generic_prescriptions", "missing_quantities.csv"))

# keep only top 10 categories per variable for plotting
plot_data <- df %>%
  select(contains("quantity")) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "value"
  ) %>%
  filter(!is.na(value) & value != "") %>%
  count(variable, value) %>%
  group_by(variable) %>%
  mutate(prop = n / sum(n)) %>%
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
    title = "Proportion of Quantity Categories",
    x = NULL,
    y = "Proportion"
  ) +
  theme_minimal()

# save 
ggsave(here::here("output", "generic_prescriptions", "quantity_summary_plot.png"))

# look at the medications associated with the quantity
dmds_for_quants <- df %>%
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
ggsave(here::here("output", "generic_prescriptions", "dmd_summary_plot.png"))

# summarise unit of measure (uom) for each prescription type
summarise_uom <- function(prescription, codelist) {
  
  # select relevant rows for the prescription (relevant if you have multiple)
  df_sub <- df %>% 
    select(c(patient_id, col_names(prescription)))
  
  # import the UOM information from local codelists
  uom_cl <- read_csv(
    here::here("local_codelists", codelist),
    col_types = cols(
      code = col_character(),
      term = col_character(),
      dmd_id = col_character(),
      dmd_type = col_character(),
      uom = col_character()
    )
  )
  
  # create function to join the UOM to quantity data
  join_uom <- function(data, code_col) {
    left_join(
      data,
      uom_cl %>%
        select(code, term, uom) %>%
        rename(
          !!paste0(prescription, code_col, "_term") := term,
          !!paste0(prescription, code_col, "_uom") := uom
        ),
      by = setNames("code", paste0(prescription, code_col, "_code"))
    )
  }
  
  # join all the relevant fields to the quantity info
  uom_presc <- df_sub %>%
    join_uom("_issue") %>%
    join_uom("_repeat") %>%
    join_uom("_repeat_issue")
  
  # longer alternatives first so repeat_issue is not split into repeat + issue
  record_pat <- "(repeat_issue|repeat|issue)"
  value_pat <- "(quantity|code|term|uom)"
  col_regex <- paste0("^", prescription, "_", record_pat, "_", value_pat, "$")
  
  # pivot the information to collate by prescription
  uom_long <- uom_presc %>%
    pivot_longer(
      cols = matches(col_regex),
      names_to = c("record", ".value"),
      names_pattern = col_regex,
      values_drop_na = FALSE
    ) %>%
    mutate(med = prescription, .before = 2) %>%
    filter(!is.na(code))
  
  # summarise the UOM contained in the quantity
  uom_sums <- uom_long %>%
    group_by(med, record) %>%
    summarise(
      n = n(),
      n_quantity_contains_uom = sum(str_detect(quantity, uom), na.rm = TRUE),
      perc = (n_quantity_contains_uom/n)*100,
      .groups = "drop"
    )
  
  # save the result
  write_csv(uom_sums, here::here("output", "generic_prescriptions", paste0(prescription,"_quantity_uoms.csv")))
  
  # look at the medications associated with the quantity
  terms_for_quants <- uom_presc %>%
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
  ggsave(here::here("output", "generic_prescriptions", paste0(prescription, "_term_summary_plot.png")))
  
}

summarise_uom("acute_med_1", "user-chriswood-example-acute-medications-uom.csv")
summarise_uom("acute_med_2", "user-chriswood-example-acute-medications-tramadol-uom.csv")
summarise_uom("repeat_med_1", "user-chriswood-example-repeat-medications-atorvastatin-uom.csv")
summarise_uom("repeat_med_2", "user-chriswood-example-repeat-medications-ramipril-uom.csv")
summarise_uom("field_test", "user-chriswood-example-quantity-test-medications-uom.csv")
