# =============================================================================
# Objective 2: Can the repeat table provide additional information for
# research into repeat prescribing?
#
# 2a. Do product and/or quantity changes relate to repeat identifiers?
#     Assess concordance between repeat records and linked medication issues:
#       - DMD/product concordance
#       - quantity concordance
#       - changes between first and last issues carrying the same repeat ID
#
# 2b. Can repeat-table dates provide additional temporal information?
#     i.   Can end_date indicate whether a repeat is actively being prescribed?
#     ii.  Do linked issues occur before start_date or after end_date?
#     iii. Can repeat dates help characterise treatment duration?
#
# Patient-level analysis: one repeat record is selected per patient/medicine
# in dataset_definition.py.
#
# Tractable analysis: medicines are discovered from
# <medicine>_repeat_start_date columns. Changing REPEAT_TABLE_MEDICINES
# therefore does not require changes to this script.
# =============================================================================


library(here)
library(arrow)
library(readr)
library(tidyverse)


# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

output_dir <- here::here("output", "repeat_table_checks")
fs::dir_create(output_dir)

raw_df <- read_feather(
  here::here("output", "dataset.arrow")
)


# -----------------------------------------------------------------------------
# Identify configured medicines
# -----------------------------------------------------------------------------

medicines <- names(raw_df) %>%
  str_subset("_repeat_start_date$") %>%
  str_remove("_repeat_start_date$")

if (length(medicines) == 0) {
  stop("No <medicine>_repeat_start_date columns found.")
}


# -----------------------------------------------------------------------------
# Create patient-level long dataset
# -----------------------------------------------------------------------------

repeat_long <- map_dfr(medicines, function(medicine) {

  get_col <- function(suffix) {
    raw_df[[paste0(medicine, suffix)]]
  }

  tibble(
    patient_id = raw_df$patient_id,
    medicine = medicine,

    # Selected repeat record
    repeat_date = get_col("_repeat_date"),
    repeat_start_date = get_col("_repeat_start_date"),
    repeat_end_date = get_col("_repeat_end_date"),
    repeat_dmd_code = as.character(
      get_col("_repeat_dmd_code")
    ),
    repeat_quantity = get_col("_repeat_quantity"),

    # Issues linked by repeat_medication_id
    linked_issue_exists = get_col("_linked_issue_exists"),
    linked_issue_count = get_col("_linked_issue_count"),

    first_linked_issue_date =
      get_col("_first_linked_issue_date"),
    first_linked_issue_dmd_code =
      as.character(get_col("_first_linked_issue_dmd_code")),
    first_linked_issue_quantity =
      get_col("_first_linked_issue_quantity"),

    last_linked_issue_date =
      get_col("_last_linked_issue_date"),
    last_linked_issue_dmd_code =
      as.character(get_col("_last_linked_issue_dmd_code")),
    last_linked_issue_quantity =
      get_col("_last_linked_issue_quantity"),

    # Same DMD irrespective of repeat ID
    last_same_dmd_issue_date =
      get_col("_last_same_dmd_issue_date"),

    # First issues observed after repeat end
    first_linked_issue_after_end_date =
      get_col("_first_linked_issue_after_end_date"),

    first_same_dmd_issue_after_end_date =
      get_col("_first_same_dmd_issue_after_end_date")
  )
}) %>%

  # Patients without a selected repeat record are not part of Objective 2.
  filter(!is.na(repeat_dmd_code)) %>%

  # Standardise quantity strings before assessing completeness/concordance.
  mutate(
    repeat_quantity = str_squish(repeat_quantity),
    first_linked_issue_quantity =
      str_squish(first_linked_issue_quantity),
    last_linked_issue_quantity =
      str_squish(last_linked_issue_quantity)
  ) %>%

  mutate(

    # -------------------------------------------------------------------------
    # 2a. DMD/product concordance
    # -------------------------------------------------------------------------

    first_dmd_comparable =
      !is.na(repeat_dmd_code) &
      !is.na(first_linked_issue_dmd_code),

    last_dmd_comparable =
      !is.na(repeat_dmd_code) &
      !is.na(last_linked_issue_dmd_code),

    first_last_dmd_comparable =
      !is.na(first_linked_issue_dmd_code) &
      !is.na(last_linked_issue_dmd_code),

    first_dmd_matches_repeat = if_else(
      first_dmd_comparable,
      repeat_dmd_code == first_linked_issue_dmd_code,
      NA
    ),

    last_dmd_matches_repeat = if_else(
      last_dmd_comparable,
      repeat_dmd_code == last_linked_issue_dmd_code,
      NA
    ),

    first_last_dmd_match = if_else(
      first_last_dmd_comparable,
      first_linked_issue_dmd_code ==
        last_linked_issue_dmd_code,
      NA
    ),


    # -------------------------------------------------------------------------
    # 2a. Quantity concordance
    # -------------------------------------------------------------------------

    repeat_quantity_present =
      !is.na(repeat_quantity) &
      repeat_quantity != "",

    first_quantity_present =
      !is.na(first_linked_issue_quantity) &
      first_linked_issue_quantity != "",

    last_quantity_present =
      !is.na(last_linked_issue_quantity) &
      last_linked_issue_quantity != "",

    first_quantity_comparable =
      repeat_quantity_present &
      first_quantity_present,

    last_quantity_comparable =
      repeat_quantity_present &
      last_quantity_present,

    first_last_quantity_comparable =
      first_quantity_present &
      last_quantity_present,

    first_quantity_matches_repeat = if_else(
      first_quantity_comparable,
      repeat_quantity ==
        first_linked_issue_quantity,
      NA
    ),

    last_quantity_matches_repeat = if_else(
      last_quantity_comparable,
      repeat_quantity ==
        last_linked_issue_quantity,
      NA
    ),

    first_last_quantity_match = if_else(
      first_last_quantity_comparable,
      first_linked_issue_quantity ==
        last_linked_issue_quantity,
      NA
    ),


    # -------------------------------------------------------------------------
    # 2b. Temporal information
    # -------------------------------------------------------------------------

    # Duration recorded in the repeat table.
    # This is not assumed to represent true treatment duration.
    repeat_duration_days = as.numeric(
      repeat_end_date - repeat_start_date
    ),

    # Observed span between first and last issues carrying the selected
    # repeat_medication_id.
    linked_issue_duration_days = as.numeric(
      last_linked_issue_date -
        first_linked_issue_date
    ),

    # Relationship between issue dates and recorded repeat dates.
    first_linked_issue_before_start =
      first_linked_issue_date <
        repeat_start_date,

    last_linked_issue_after_end =
      last_linked_issue_date >
        repeat_end_date,

    # Presence of an issue after end can be derived from the corresponding
    # date rather than requiring an additional ehrQL boolean.
    same_id_issue_after_end =
      !is.na(first_linked_issue_after_end_date),

    same_dmd_issue_after_end =
      !is.na(first_same_dmd_issue_after_end_date),

    # Time from recorded end to subsequent issue.
    days_to_first_linked_issue_after_end =
      as.numeric(
        first_linked_issue_after_end_date -
          repeat_end_date
      ),

    days_to_first_same_dmd_issue_after_end =
      as.numeric(
        first_same_dmd_issue_after_end_date -
          repeat_end_date
      ),

    # Other useful intervals for interpreting start/end dates.
    start_to_first_linked_issue_days =
      as.numeric(
        first_linked_issue_date -
          repeat_start_date
      ),

    last_linked_issue_to_end_days =
      as.numeric(
        repeat_end_date -
          last_linked_issue_date
      )
  )


# =============================================================================
# 2a. Can repeat records be linked to medication issues?
# =============================================================================

linkage_summary <- repeat_long %>%
  group_by(medicine) %>%
  summarise(

    n_patients_with_selected_repeat = n(),

    n_with_linked_issue =
      sum(linked_issue_exists, na.rm = TRUE),

    proportion_with_linked_issue =
      n_with_linked_issue /
      n_patients_with_selected_repeat,

    median_linked_issue_count =
      median(linked_issue_count, na.rm = TRUE),

    q1_linked_issue_count =
      quantile(
        linked_issue_count,
        0.25,
        na.rm = TRUE
      ),

    q3_linked_issue_count =
      quantile(
        linked_issue_count,
        0.75,
        na.rm = TRUE
      ),

    .groups = "drop"
  )


# =============================================================================
# 2a. Does the repeat table duplicate product/quantity information?
# =============================================================================

concordance_summary <- repeat_long %>%
  group_by(medicine) %>%
  summarise(

    # -------------------------------------------------------------------------
    # DMD: repeat record vs first linked issue
    # -------------------------------------------------------------------------

    n_first_dmd_comparable =
      sum(first_dmd_comparable),

    n_first_dmd_match =
      sum(first_dmd_matches_repeat, na.rm = TRUE),

    proportion_first_dmd_match = if_else(
      n_first_dmd_comparable > 0,
      n_first_dmd_match /
        n_first_dmd_comparable,
      NA_real_
    ),


    # -------------------------------------------------------------------------
    # DMD: repeat record vs last linked issue
    # -------------------------------------------------------------------------

    n_last_dmd_comparable =
      sum(last_dmd_comparable),

    n_last_dmd_match =
      sum(last_dmd_matches_repeat, na.rm = TRUE),

    proportion_last_dmd_match = if_else(
      n_last_dmd_comparable > 0,
      n_last_dmd_match /
        n_last_dmd_comparable,
      NA_real_
    ),


    # -------------------------------------------------------------------------
    # DMD: first vs last issue carrying the same repeat ID
    # -------------------------------------------------------------------------

    n_first_last_dmd_comparable =
      sum(first_last_dmd_comparable),

    n_first_last_dmd_match =
      sum(first_last_dmd_match, na.rm = TRUE),

    proportion_first_last_dmd_match = if_else(
      n_first_last_dmd_comparable > 0,
      n_first_last_dmd_match /
        n_first_last_dmd_comparable,
      NA_real_
    ),


    # -------------------------------------------------------------------------
    # Quantity: repeat record vs first linked issue
    # -------------------------------------------------------------------------

    n_first_quantity_comparable =
      sum(first_quantity_comparable),

    n_first_quantity_match =
      sum(first_quantity_matches_repeat, na.rm = TRUE),

    proportion_first_quantity_match = if_else(
      n_first_quantity_comparable > 0,
      n_first_quantity_match /
        n_first_quantity_comparable,
      NA_real_
    ),


    # -------------------------------------------------------------------------
    # Quantity: repeat record vs last linked issue
    # -------------------------------------------------------------------------

    n_last_quantity_comparable =
      sum(last_quantity_comparable),

    n_last_quantity_match =
      sum(last_quantity_matches_repeat, na.rm = TRUE),

    proportion_last_quantity_match = if_else(
      n_last_quantity_comparable > 0,
      n_last_quantity_match /
        n_last_quantity_comparable,
      NA_real_
    ),


    # -------------------------------------------------------------------------
    # Quantity: first vs last issue carrying the same repeat ID
    # -------------------------------------------------------------------------

    n_first_last_quantity_comparable =
      sum(first_last_quantity_comparable),

    n_first_last_quantity_match =
      sum(first_last_quantity_match, na.rm = TRUE),

    proportion_first_last_quantity_match = if_else(
      n_first_last_quantity_comparable > 0,
      n_first_last_quantity_match /
        n_first_last_quantity_comparable,
      NA_real_
    ),

    .groups = "drop"
  )


# =============================================================================
# 2b. Can repeat-table dates provide additional temporal information?
# =============================================================================

temporal_summary <- repeat_long %>%
  group_by(medicine) %>%
  summarise(

    # -------------------------------------------------------------------------
    # Recorded repeat duration
    # -------------------------------------------------------------------------

    n_with_start_end =
      sum(
        !is.na(repeat_start_date) &
        !is.na(repeat_end_date)
      ),

    median_repeat_duration_days =
      median(
        repeat_duration_days,
        na.rm = TRUE
      ),

    q1_repeat_duration_days =
      quantile(
        repeat_duration_days,
        0.25,
        na.rm = TRUE
      ),

    q3_repeat_duration_days =
      quantile(
        repeat_duration_days,
        0.75,
        na.rm = TRUE
      ),


    # -------------------------------------------------------------------------
    # Observed linked-issue duration
    # -------------------------------------------------------------------------

    n_with_first_last_linked_issue =
      sum(
        !is.na(first_linked_issue_date) &
        !is.na(last_linked_issue_date)
      ),

    median_linked_issue_duration_days =
      median(
        linked_issue_duration_days,
        na.rm = TRUE
      ),

    q1_linked_issue_duration_days =
      quantile(
        linked_issue_duration_days,
        0.25,
        na.rm = TRUE
      ),

    q3_linked_issue_duration_days =
      quantile(
        linked_issue_duration_days,
        0.75,
        na.rm = TRUE
      ),


    # -------------------------------------------------------------------------
    # 2b.i / 2b.ii: issues before start_date
    # -------------------------------------------------------------------------

    n_before_start_comparable =
      sum(
        !is.na(first_linked_issue_date) &
        !is.na(repeat_start_date)
      ),

    n_first_linked_issue_before_start =
      sum(
        first_linked_issue_before_start,
        na.rm = TRUE
      ),

    proportion_first_linked_issue_before_start =
      if_else(
        n_before_start_comparable > 0,
        n_first_linked_issue_before_start /
          n_before_start_comparable,
        NA_real_
      ),


    # -------------------------------------------------------------------------
    # 2b.i / 2b.ii: same repeat ID issued after end_date
    # -------------------------------------------------------------------------

    n_end_date_comparable =
      sum(!is.na(repeat_end_date)),

    n_same_id_issue_after_end =
      sum(
        same_id_issue_after_end,
        na.rm = TRUE
      ),

    proportion_same_id_issue_after_end =
      if_else(
        n_end_date_comparable > 0,
        n_same_id_issue_after_end /
          n_end_date_comparable,
        NA_real_
      ),

    median_days_to_same_id_issue_after_end =
      median(
        days_to_first_linked_issue_after_end,
        na.rm = TRUE
      ),


    # -------------------------------------------------------------------------
    # 2b.i / 2b.ii: same DMD issued after end_date irrespective of repeat ID
    # -------------------------------------------------------------------------

    n_same_dmd_issue_after_end =
      sum(
        same_dmd_issue_after_end,
        na.rm = TRUE
      ),

    proportion_same_dmd_issue_after_end =
      if_else(
        n_end_date_comparable > 0,
        n_same_dmd_issue_after_end /
          n_end_date_comparable,
        NA_real_
      ),

    median_days_to_same_dmd_issue_after_end =
      median(
        days_to_first_same_dmd_issue_after_end,
        na.rm = TRUE
      ),

    .groups = "drop"
  )


# =============================================================================
# Save outputs
# =============================================================================

write_csv(
  linkage_summary,
  file.path(
    output_dir,
    "linkage_summary.csv"
  )
)

write_csv(
  concordance_summary,
  file.path(
    output_dir,
    "dmd_quantity_concordance.csv"
  )
)

write_csv(
  temporal_summary,
  file.path(
    output_dir,
    "temporal_summary.csv"
  )
)


# Retain patient-level derived data for further disclosure-controlled summaries.
write_csv(
  repeat_long,
  file.path(
    output_dir,
    "repeat_table_derived_patient_level.csv"
  )
)


# =============================================================================
# Figure: distribution of recorded repeat duration
# =============================================================================

plot_duration <- repeat_long %>%
  filter(!is.na(repeat_duration_days)) %>%
  ggplot(
    aes(x = repeat_duration_days)
  ) +
  geom_histogram(bins = 30) +
  facet_wrap(
    ~ medicine,
    scales = "free_y"
  ) +
  labs(
    title = "Recorded duration of selected repeat records",
    x = "Repeat end date - repeat start date (days)",
    y = "Patients"
  ) +
  theme_minimal()

ggsave(
  file.path(
    output_dir,
    "repeat_duration_distribution.png"
  ),
  plot_duration
)
