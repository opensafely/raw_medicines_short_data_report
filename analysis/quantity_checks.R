# =============================================================================
# Objective 1b: Can issue records provide information about quantity prescribed?
#
# Assess:
#   - completeness of the quantity field
#   - variation in quantity strings
#   - whether the expected unit of measure (UOM) is present in quantity
#   - whether quantity can subsequently be parsed into a usable value
#
# Patient-level limitation:
# Quantity is taken from the first selected issue per patient/medicine/issue
# type. Results therefore characterise selected issue records rather than all
# medication issue records.

# =============================================================================

library(here)
library(arrow)
library(readr)
library(tidyverse)
library(scales)

output_dir <- here::here("output", "quantity_checks")
fs::dir_create(output_dir)

raw_df <- read_feather(
  here::here("output", "dataset.arrow")
)

# -----------------------------------------------------------------------------
# Identify configured medicines

# -----------------------------------------------------------------------------
quantity_names <- names(raw_df) %>%
  str_subset("_issue_quantity$") %>%
  str_remove("_issue_quantity$")
code_names <- names(raw_df) %>%
  str_subset("_issue_code$") %>%
  str_remove("_issue_code$")
medicines <- intersect(
  quantity_names,
  code_names
)
if (length(medicines) == 0) {
  stop(
    "No paired <medicine>_issue_quantity and ",
    "<medicine>_issue_code columns found."
  )
}

# -----------------------------------------------------------------------------
# UOM configuration

# -----------------------------------------------------------------------------
#
# Map each configured medicine name to the local codelist containing its DMD
# code and unit-of-measure information.
#
# Edit this configuration when changing the medicines used for the quantity
# analysis.
#
# Expected codelist columns:
#   - code
#   - term
#   - uom
#
# Replace filenames below with the corresponding filenames in local_codelists.

UOM_CODELISTS <- c(
  "statins" =
    "user-emprestige-all-statins-uom.csv",
  "opioids" =
    "opensafely-high-dose-long-acting-opioids-openprescribing-dmd-uom.csv",
  "injections" =
    "opensafely-long-acting-injectable-and-depot-antipsychotics-dmd-uom.csv",
  "injections_oxy" =
    "opensafely-oxycodone-subcutaneous-dmd-uom.csv",
  "inhalers" =
    "user-emprestige-all-inhalers-dmd-uom.csv"
)
missing_uom_mapping <- setdiff(medicines, names(UOM_CODELISTS))
unused_uom_mapping <- setdiff(names(UOM_CODELISTS), medicines)
if (length(missing_uom_mapping) > 0) {
  warning(
    "No UOM codelist mapping for quantity medicine(s): ",
    paste(missing_uom_mapping, collapse = ", ")
  )
}
if (length(unused_uom_mapping) > 0) {
  message(
    "UOM mapping(s) not used by the current dataset: ",
    paste(unused_uom_mapping, collapse = ", ")
  )
}

# -----------------------------------------------------------------------------
# Create patient-level issue quantity dataset

# -----------------------------------------------------------------------------

issue_quantity_long <- map_dfr(
  medicines,
  function(medicine) {
    non_repeat_quantity <-
      paste0(medicine, "_issue_quantity")
    non_repeat_code <-
      paste0(medicine, "_issue_code")
    repeat_quantity <-
      paste0(medicine, "_repeat_issue_quantity")
    repeat_code <-
      paste0(medicine, "_repeat_issue_code")
    bind_rows(
      # First selected non-repeat issue
      raw_df %>%
        transmute(
          patient_id,
          medicine = medicine,
          issue_type = "non-repeat issue",
          quantity = .data[[non_repeat_quantity]],
          dmd_code = as.character(
            .data[[non_repeat_code]]
          )
        ),
      # First selected repeat-linked issue
      if (
        all(
          c(
            repeat_quantity,
            repeat_code
          ) %in% names(raw_df)
        )
      ) {
        raw_df %>%
          transmute(
            patient_id,
            medicine = medicine,
            issue_type = "repeat-linked issue",
            quantity = .data[[repeat_quantity]],
            dmd_code = as.character(
              .data[[repeat_code]]
            )
          )
      } else {
        tibble()
      }
    )
  }
) %>%
  mutate(
    quantity_trimmed =
      str_squish(quantity),
    quantity_missing =
      is.na(quantity) |
      quantity_trimmed == ""
  )

# =============================================================================
# 1b.i Quantity completeness

# =============================================================================

quantity_completeness <- issue_quantity_long %>%
  group_by(
    medicine,
    issue_type
  ) %>%
  summarise(
    n_selected_records = n(),
    n_quantity_missing =
      sum(quantity_missing),
    n_quantity_present =
      sum(!quantity_missing),
    proportion_quantity_present =
      n_quantity_present /
      n_selected_records,
    proportion_quantity_missing =
      n_quantity_missing /
      n_selected_records,
    .groups = "drop"
  )

# =============================================================================
# 1b.ii Variation and interpretability of quantity strings

# =============================================================================

common_quantities <- issue_quantity_long %>%
  filter(!quantity_missing) %>%
  count(
    medicine,
    issue_type,
    quantity_trimmed,
    name = "n"
  ) %>%
  group_by(
    medicine,
    issue_type
  ) %>%
  mutate(
    proportion = n / sum(n)
  ) %>%
  slice_max(
    proportion,
    n = 10,
    with_ties = FALSE
  ) %>%
  ungroup()
# DMD codes associated with selected issue records.

common_dmd_codes <- issue_quantity_long %>%
  filter(!is.na(dmd_code)) %>%
  count(
    medicine,
    issue_type,
    dmd_code,
    name = "n"
  ) %>%
  group_by(
    medicine,
    issue_type
  ) %>%
  mutate(
    proportion = n / sum(n)
  ) %>%
  slice_max(
    proportion,
    n = 10,
    with_ties = FALSE
  ) %>%
  ungroup()
# DMD × quantity combinations are useful for determining whether common
# quantity strings are interpretable for particular products.

common_dmd_quantity <- issue_quantity_long %>%
  filter(
    !quantity_missing,
    !is.na(dmd_code)
  ) %>%
  count(
    medicine,
    issue_type,
    dmd_code,
    quantity_trimmed,
    name = "n"
  ) %>%
  group_by(
    medicine,
    issue_type
  ) %>%
  mutate(
    proportion = n / sum(n)
  ) %>%
  slice_max(
    proportion,
    n = 10,
    with_ties = FALSE
  ) %>%
  ungroup()

# =============================================================================
# 1b.iii Unit-of-measure analysis

# =============================================================================
# Read configured UOM codelists and combine them into one lookup table.

uom_lookup <- imap_dfr(
  UOM_CODELISTS,
  function(filename, medicine) {
    read_csv(
      here::here(
        "analysis",
        "codelists",
        filename
      ),
      show_col_types = FALSE
    ) %>%
      transmute(
        medicine = medicine,
        dmd_code = as.character(code),
        dmd_term = term,
        uom = str_squish(uom)
      )
  }
)

if (nrow(uom_lookup) > 0) {
  issue_quantity_uom <- issue_quantity_long %>%
    left_join(
      uom_lookup,
      by = c(
        "medicine",
        "dmd_code"
      )
    ) %>%
    mutate(
      uom_present =
        !is.na(uom) &
        uom != "",
      # Case-insensitive fixed-string search avoids treating characters in the
      # UOM as a regular expression.
      quantity_contains_uom =
        case_when(
          quantity_missing ~ NA,
          !uom_present ~ NA,
          TRUE ~ str_detect(
            str_to_lower(quantity_trimmed),
            fixed(
              str_to_lower(uom)
            )
          )
        )
    )
  uom_summary <- issue_quantity_uom %>%
    group_by(
      medicine,
      issue_type
    ) %>%
    summarise(
      n_quantity_present =
        sum(!quantity_missing),
      n_with_uom_available =
        sum(
          !quantity_missing &
          uom_present
        ),
      n_quantity_contains_uom =
        sum(
          quantity_contains_uom,
          na.rm = TRUE
        ),
      # Denominator is records with both a non-empty quantity and a known UOM.
      proportion_quantity_contains_uom =
        if_else(
          n_with_uom_available > 0,
          n_quantity_contains_uom /
            n_with_uom_available,
          NA_real_
        ),
      .groups = "drop"
    )
} else {
  issue_quantity_uom <- tibble()
  uom_summary <- tibble(
    medicine = character(),
    issue_type = character(),
    n_quantity_present = integer(),
    n_with_uom_available = integer(),
    n_quantity_contains_uom = integer(),
    proportion_quantity_contains_uom = double()
  )
}

# =============================================================================
# Save outputs

# =============================================================================

write_csv(
  quantity_completeness,
  file.path(
    output_dir,
    "quantity_completeness.csv"
  )
)

write_csv(
  common_quantities,
  file.path(
    output_dir,
    "common_quantity_strings.csv"
  )
)

write_csv(
  common_dmd_codes,
  file.path(
    output_dir,
    "common_quantity_dmd_codes.csv"
  )
)

write_csv(
  common_dmd_quantity,
  file.path(
    output_dir,
    "common_dmd_quantity_combinations.csv"
  )
)

write_csv(
  uom_summary,
  file.path(
    output_dir,
    "quantity_uom_summary.csv"
  )
)

# =============================================================================
# Figure: common quantity strings

# =============================================================================

plot_quantities <- common_quantities %>%
  ggplot(
    aes(
      x = reorder(
        quantity_trimmed,
        proportion
      ),
      y = proportion
    )
  ) +
  geom_col() +
  coord_flip() +
  facet_grid(
    medicine ~ issue_type,
    scales = "free_y"
  ) +
  scale_y_continuous(
    labels = percent_format()
  ) +
  labs(
    title =
      "Most common quantity strings in medication issue records",
    x = NULL,
    y = "Proportion"
  ) +
  theme_minimal()

ggsave(
  file.path(
    output_dir,
    "common_quantity_strings.png"
  ),
  plot_quantities,
  height = 8
)

# =============================================================================
# Prototype of quantity-field usage

# =============================================================================
#
# Planned next step:
#
# 1. obtain expected UOM from DMD;
# 2. identify/remove that UOM from quantity_trimmed;
# 3. inspect the remaining string;
# 4. determine whether the remaining value can be converted reliably to a
#    numeric prescribed quantity;
# 5. compare parsing success across medication/formulation types.
#
# Keep this separate from the generic completeness/UOM analysis until the
# parsing rules have been validated.
