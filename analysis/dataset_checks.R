# =============================================================================
# Dataset quality checks
#
# Lightweight QC for the paper-facing patient-level dataset.
#
# Research analyses belong in:
#   - repeat_identification.R   (Objective 1a)
#   - quantity_checks.R         (Objective 1b)
#   - repeat_table_checks.R     (Objective 2)
#
# Exploratory checks remain in the archive.
#
# Medicine groups are detected independently because the paper now uses:
#   - ISSUE_COMPARISON_MEDICINES for repeat identification
#   - QUANTITY_MEDICINES for quantity analysis
#   - REPEAT_TABLE_MEDICINES for repeat-table analysis
# =============================================================================

library(here)
library(arrow)
library(tidyverse)
library(skimr)

index_date <- as.Date("2025-01-01")
input_file <- here::here("output", "dataset.arrow")

output_files <- list(
  skim = here::here("output", "dataset_skim.txt"),
  summary = here::here("output", "dataset_check.csv"),
  variables = here::here("output", "dataset_variable_inventory.csv"),
  missingness = here::here("output", "dataset_missingness.csv"),
  count_checks = here::here("output", "dataset_count_checks.csv"),
  date_checks = here::here("output", "dataset_date_checks.csv")
)


# -----------------------------------------------------------------------------
# Helpers: detect medicines independently for each objective
# -----------------------------------------------------------------------------

get_repeat_identification_medicines <- function(data) {
  issue_names <- names(data) %>%
    str_subset("_issue$") %>%
    str_remove("_issue$")

  repeat_issue_names <- names(data) %>%
    str_subset("_repeat_issue$") %>%
    str_remove("_repeat_issue$")

  intersect(issue_names, repeat_issue_names)
}


get_quantity_medicines <- function(data) {
  quantity_names <- names(data) %>%
    str_subset("_issue_quantity$") %>%
    str_remove("_issue_quantity$")

  code_names <- names(data) %>%
    str_subset("_issue_code$") %>%
    str_remove("_issue_code$")

  intersect(quantity_names, code_names)
}


get_repeat_table_medicines <- function(data) {
  names(data) %>%
    str_subset("_repeat_start_date$") %>%
    str_remove("_repeat_start_date$")
}


safe_pct <- function(numerator, denominator) {
  ifelse(
    denominator == 0,
    NA_real_,
    100 * numerator / denominator
  )
}


# -----------------------------------------------------------------------------
# Read data and detect configured medicines
# -----------------------------------------------------------------------------

df <- read_feather(input_file)

repeat_identification_medicines <-
  get_repeat_identification_medicines(df)

quantity_medicines <-
  get_quantity_medicines(df)

repeat_table_medicines <-
  get_repeat_table_medicines(df)


# -----------------------------------------------------------------------------
# 1. Basic dataset checks
# -----------------------------------------------------------------------------

required_columns <- c(
  "patient_id",
  "patient_age",
  "patient_sex",
  "age_cat",
  "followup_end"
)

missing_required_columns <- setdiff(
  required_columns,
  names(df)
)

if (length(missing_required_columns) > 0) {
  stop(
    "Dataset is missing required columns: ",
    paste(
      missing_required_columns,
      collapse = ", "
    )
  )
}


dataset_summary <- tibble(
  n_patients =
    n_distinct(df$patient_id),

  n_rows =
    nrow(df),

  n_columns =
    ncol(df),

  duplicate_patient_rows =
    nrow(df) - n_distinct(df$patient_id),

  n_repeat_identification_medicines =
    length(repeat_identification_medicines),

  n_quantity_medicines =
    length(quantity_medicines),

  n_repeat_table_medicines =
    length(repeat_table_medicines),

  age_missing_n =
    sum(is.na(df$patient_age)),

  age_out_of_range_n =
    sum(
      !is.na(df$patient_age) &
        (
          df$patient_age <= 0 |
            df$patient_age > 110
        )
    ),

  sex_missing_n =
    sum(is.na(df$patient_sex)),

  age_cat_missing_n =
    sum(is.na(df$age_cat)),

  followup_end_missing_n =
    sum(is.na(df$followup_end))
)

write_csv(
  dataset_summary,
  output_files$summary
)


# -----------------------------------------------------------------------------
# 2. Dataset skim
# -----------------------------------------------------------------------------

# Replace all-missing dates only in this temporary object so skimr can produce
# a useful report. The analysis dataset itself is not changed.
df_for_skim <- df %>%
  mutate(
    across(
      where(~ inherits(.x, "Date")),
      ~ if (all(is.na(.x))) {
        replace(
          .x,
          is.na(.x),
          as.Date("1800-01-01")
        )
      } else {
        .x
      }
    )
  )

capture.output(
  df_for_skim %>%
    skim_without_charts(),
  file = output_files$skim,
  split = FALSE
)


# -----------------------------------------------------------------------------
# 3. Variable inventory
# -----------------------------------------------------------------------------

# Records which variables have been generated after changing the tractable
# medicine configuration.
variable_inventory <- tibble(
  variable = names(df),
  class = map_chr(
    df,
    ~ paste(
      class(.x),
      collapse = "/"
    )
  )
) %>%
  mutate(
    analysis_area = case_when(

      variable %in% required_columns ~
        "cohort_or_demographics",

      str_detect(
        variable,
        "_repeat_start_date$|_repeat_end_date$"
      ) ~
        "repeat_table_temporal",

      str_detect(
        variable,
        "_linked_issue|_same_dmd_issue"
      ) ~
        "repeat_table_comparison",

      str_detect(
        variable,
        "_issue_quantity$|_repeat_issue_quantity$"
      ) ~
        "quantity",

      str_detect(
        variable,
        "_issue_code$|_repeat_issue_code$"
      ) ~
        "quantity_dmd",

      str_detect(
        variable,
        "_issue$|_repeat_issue$"
      ) ~
        "repeat_identification",

      TRUE ~
        "other"
    )
  )

write_csv(
  variable_inventory,
  output_files$variables
)


# -----------------------------------------------------------------------------
# 4. Missingness
# -----------------------------------------------------------------------------

# This is QC only. Interpretation of quantity completeness belongs in
# quantity_checks.R rather than being duplicated here.
missingness <- tibble(
  variable = names(df),

  missing_n =
    map_int(
      df,
      ~ sum(is.na(.x))
    ),

  non_missing_n =
    map_int(
      df,
      ~ sum(!is.na(.x))
    )
) %>%
  mutate(
    total_n =
      missing_n + non_missing_n,

    missing_pct =
      safe_pct(
        missing_n,
        total_n
      )
  ) %>%
  arrange(
    desc(missing_pct),
    variable
  )

write_csv(
  missingness,
  output_files$missingness
)


# -----------------------------------------------------------------------------
# 5. Count-variable sanity checks
# -----------------------------------------------------------------------------

count_columns <- names(df)[
  str_detect(
    names(df),
    "(_issue$|_repeat_issue$|_linked_issue_count$)"
  )
]


if (length(count_columns) > 0) {

  count_checks <- map_dfr(
    count_columns,
    function(var) {

      x <- df[[var]]

      tibble(
        variable = var,

        missing_n =
          sum(is.na(x)),

        negative_n =
          sum(
            x < 0,
            na.rm = TRUE
          ),

        zero_n =
          sum(
            x == 0,
            na.rm = TRUE
          ),

        positive_n =
          sum(
            x > 0,
            na.rm = TRUE
          ),

        min =
          if (all(is.na(x))) {
            NA_real_
          } else {
            min(
              x,
              na.rm = TRUE
            )
          },

        max =
          if (all(is.na(x))) {
            NA_real_
          } else {
            max(
              x,
              na.rm = TRUE
            )
          }
      )
    }
  )

} else {

  count_checks <- tibble(
    variable = character(),
    missing_n = integer(),
    negative_n = integer(),
    zero_n = integer(),
    positive_n = integer(),
    min = double(),
    max = double()
  )
}


write_csv(
  count_checks,
  output_files$count_checks
)


# -----------------------------------------------------------------------------
# 6. Date plausibility checks
# -----------------------------------------------------------------------------

# Pre-index dates are descriptive rather than errors. Objective 2 deliberately
# searches linked medication issues before index_date to test their relationship
# with repeat start_date.
date_columns <- names(df)[
  map_lgl(
    df,
    ~ inherits(.x, "Date")
  )
]


if (length(date_columns) > 0) {

  date_checks <- map_dfr(
    date_columns,
    function(var) {

      x <- df[[var]]

      tibble(
        variable = var,

        missing_n =
          sum(is.na(x)),

        placeholder_9999_n =
          sum(
            x == as.Date("9999-12-31"),
            na.rm = TRUE
          ),

        pre_1900_n =
          sum(
            x < as.Date("1900-01-01"),
            na.rm = TRUE
          ),

        pre_index_n =
          sum(
            x < index_date,
            na.rm = TRUE
          ),

        min_date =
          if (all(is.na(x))) {
            as.Date(NA)
          } else {
            min(
              x,
              na.rm = TRUE
            )
          },

        max_date =
          if (all(is.na(x))) {
            as.Date(NA)
          } else {
            max(
              x,
              na.rm = TRUE
            )
          }
      )
    }
  )

} else {

  date_checks <- tibble(
    variable = character(),
    missing_n = integer(),
    placeholder_9999_n = integer(),
    pre_1900_n = integer(),
    pre_index_n = integer(),
    min_date = as.Date(character()),
    max_date = as.Date(character())
  )
}


write_csv(
  date_checks,
  output_files$date_checks
)


# -----------------------------------------------------------------------------
# 7. Structural checks: Objective 1a
#    Can the Medication Issues table identify repeat prescribing?
# -----------------------------------------------------------------------------

expected_repeat_identification_suffixes <- c(
  "_issue",
  "_repeat_issue"
)


for (medicine in repeat_identification_medicines) {

  expected <- paste0(
    medicine,
    expected_repeat_identification_suffixes
  )

  missing <- setdiff(
    expected,
    names(df)
  )

  if (length(missing) > 0) {
    warning(
      "Incomplete repeat-identification output for ",
      medicine,
      ": ",
      paste(
        missing,
        collapse = ", "
      )
    )
  }
}


# -----------------------------------------------------------------------------
# 8. Structural checks: Objective 1b
#    Can Medication Issues provide information about quantity prescribed?
# -----------------------------------------------------------------------------

expected_quantity_suffixes <- c(
  "_issue_quantity",
  "_issue_code",
  "_repeat_issue_quantity",
  "_repeat_issue_code"
)


for (medicine in quantity_medicines) {

  expected <- paste0(
    medicine,
    expected_quantity_suffixes
  )

  missing <- setdiff(
    expected,
    names(df)
  )

  if (length(missing) > 0) {
    warning(
      "Incomplete quantity output for ",
      medicine,
      ": ",
      paste(
        missing,
        collapse = ", "
      )
    )
  }
}


# -----------------------------------------------------------------------------
# 9. Structural checks: Objective 2
#    Does repeat_medications provide additional information?
# -----------------------------------------------------------------------------

expected_repeat_table_suffixes <- c(
  "_repeat_date",
  "_repeat_start_date",
  "_repeat_end_date",
  "_repeat_dmd_code",
  "_repeat_quantity",
  "_linked_issue_exists",
  "_linked_issue_count",
  "_first_linked_issue_date",
  "_first_linked_issue_dmd_code",
  "_first_linked_issue_quantity",
  "_last_linked_issue_date",
  "_last_linked_issue_dmd_code",
  "_last_linked_issue_quantity",
  "_last_same_dmd_issue_date",
  "_first_linked_issue_after_end_date",
  "_first_same_dmd_issue_after_end_date"
)


for (medicine in repeat_table_medicines) {

  expected <- paste0(
    medicine,
    expected_repeat_table_suffixes
  )

  missing <- setdiff(
    expected,
    names(df)
  )

  if (length(missing) > 0) {
    warning(
      "Incomplete repeat-table output for ",
      medicine,
      ": ",
      paste(
        missing,
        collapse = ", "
      )
    )
  }
}
