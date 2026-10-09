# =============================================================================
# Section 1a: Can the issue table identify repeat prescribing?
#
# Compare medicines expected to be predominantly acute with medicines expected
# to be predominantly prescribed on repeat.
#
# Tractable analysis: medicine names are discovered from columns ending in
# `_issue` and `_repeat_issue`. Changing medicines in dataset_definition.py
# therefore does not require changes to this script.
# =============================================================================

library(here)
library(arrow)
library(readr)
library(tidyverse)
library(scales)

output_dir <- here::here("output", "repeat_identification")
fs::dir_create(output_dir)

raw_df <- read_feather(here::here("output", "dataset.arrow"))


# -----------------------------------------------------------------------------
# Identify configured medicines
# -----------------------------------------------------------------------------

# Identify medicines for which both issue-count variables are present.
issue_names <- names(raw_df) %>%
  str_subset("_issue$") %>%
  str_remove("_issue$")

repeat_issue_names <- names(raw_df) %>%
  str_subset("_repeat_issue$") %>%
  str_remove("_repeat_issue$")

medicines <- intersect(issue_names, repeat_issue_names)

if (length(medicines) == 0) {
  stop(
    "No paired <medicine>_issue and <medicine>_repeat_issue columns found."
  )
}

count_columns <- unlist(
  map(
    medicines,
    ~ c(
      paste0(.x, "_issue"),
      paste0(.x, "_repeat_issue")
    )
  )
)

df <- raw_df %>%
  select(
    patient_id,
    any_of(c("patient_age", "patient_sex", "age_cat")),
    all_of(count_columns)
  )


# -----------------------------------------------------------------------------
# Create patient-level summary
# -----------------------------------------------------------------------------

# One row per patient per configured medicine.
#
# `_issue` contains the number of issues without a repeat_medication_id.
# `_repeat_issue` contains the number of issues with a repeat_medication_id.
#
# Missing counts are treated as zero.
patient_summary <- map_dfr(medicines, function(medicine) {

  issue_col <- paste0(medicine, "_issue")
  repeat_issue_col <- paste0(medicine, "_repeat_issue")

  df %>%
    transmute(
      patient_id,
      medicine = medicine,

      non_repeat_issues = coalesce(.data[[issue_col]], 0L),
      repeat_issues = coalesce(.data[[repeat_issue_col]], 0L),

      total_issues = non_repeat_issues + repeat_issues,

      ever_non_repeat_issue = non_repeat_issues > 0,
      ever_repeat_issue = repeat_issues > 0,

      issue_pattern = case_when(
        total_issues == 0 ~ "no issues",
        ever_repeat_issue & !ever_non_repeat_issue ~ "repeat only",
        !ever_repeat_issue & ever_non_repeat_issue ~ "non-repeat only",
        ever_repeat_issue & ever_non_repeat_issue ~ "mixed"
      )
    )
})


# -----------------------------------------------------------------------------
# Medicine-level summary
# -----------------------------------------------------------------------------

# Although ehrQL outputs one row per patient, count_for_patient() retains the
# number of medication issues for each patient. Summing these patient-level
# counts therefore reconstructs the number of medication issues represented
# within the study cohort.
#
# Patient-level proportions use patients with at least one issue of the
# relevant medicine as their denominator.

medicine_summary <- patient_summary %>%
  group_by(medicine) %>%
  summarise(

    # Population with the medicine
    n_patients_with_issue = sum(total_issues > 0),

    # Issue-level counts
    total_issues = sum(total_issues),
    non_repeat_issues = sum(non_repeat_issues),
    repeat_issues = sum(repeat_issues),

    # Proportion of all issues carrying repeat_medication_id
    proportion_issues_repeat = if_else(
      total_issues > 0,
      repeat_issues / total_issues,
      NA_real_
    ),

    # Patient-level repeat prescribing
    n_patients_ever_repeat = sum(ever_repeat_issue),

    proportion_patients_ever_repeat = if_else(
      n_patients_with_issue > 0,
      n_patients_ever_repeat / n_patients_with_issue,
      NA_real_
    ),

    # Patient-level prescribing patterns
    n_patients_repeat_only = sum(issue_pattern == "repeat only"),
    n_patients_non_repeat_only = sum(issue_pattern == "non-repeat only"),
    n_patients_mixed = sum(issue_pattern == "mixed"),

    proportion_patients_repeat_only = if_else(
      n_patients_with_issue > 0,
      n_patients_repeat_only / n_patients_with_issue,
      NA_real_
    ),

    proportion_patients_non_repeat_only = if_else(
      n_patients_with_issue > 0,
      n_patients_non_repeat_only / n_patients_with_issue,
      NA_real_
    ),

    proportion_patients_mixed = if_else(
      n_patients_with_issue > 0,
      n_patients_mixed / n_patients_with_issue,
      NA_real_
    ),

    .groups = "drop"
  )


# -----------------------------------------------------------------------------
# Patient prescribing-pattern summary
# -----------------------------------------------------------------------------

# Restrict to patients with at least one issue of the relevant medicine.
# Patients with no issues are part of the overall study population but are not
# informative when describing whether prescribing of a particular medicine is
# repeat or non-repeat.
pattern_summary <- patient_summary %>%
  filter(total_issues > 0) %>%
  count(
    medicine,
    issue_pattern,
    name = "n"
  ) %>%
  group_by(medicine) %>%
  mutate(
    proportion = n / sum(n)
  ) %>%
  ungroup()


# -----------------------------------------------------------------------------
# Save tables
# -----------------------------------------------------------------------------

write_csv(
  medicine_summary,
  file.path(
    output_dir,
    "repeat_identification_summary.csv"
  )
)

write_csv(
  pattern_summary,
  file.path(
    output_dir,
    "repeat_identification_patient_patterns.csv"
  )
)


# -----------------------------------------------------------------------------
# Plot: proportion of issues identified as repeat
# -----------------------------------------------------------------------------

plot_repeat <- medicine_summary %>%
  ggplot(
    aes(
      x = reorder(medicine, proportion_issues_repeat),
      y = proportion_issues_repeat
    )
  ) +
  geom_col() +
  coord_flip() +
  scale_y_continuous(
    labels = percent_format(),
    limits = c(0, 1)
  ) +
  labs(
    title = "Proportion of medication issues linked to a repeat medication ID",
    x = NULL,
    y = "Proportion of issues"
  ) +
  theme_minimal()

ggsave(
  file.path(
    output_dir,
    "repeat_issue_proportion.png"
  ),
  plot_repeat
)
