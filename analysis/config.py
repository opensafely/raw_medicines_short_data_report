# -----------------------------------------------------------------------------
# Tractable analysis configuration
# -----------------------------------------------------------------------------

from ehrql import codelists


# -----------------------------------------------------------------------------
# Objective 1a: identify repeat prescribing from Medication Issues
# -----------------------------------------------------------------------------

ISSUE_COMPARISON_MEDICINES = {
    "acute_med_1": codelists.acute_1,
    "acute_med_2": codelists.acute_2,
    "repeat_med_1": codelists.repeat_1,
    "repeat_med_2": codelists.repeat_2,
}


# -----------------------------------------------------------------------------
# Objective 1b: investigate quantity in Medication Issues
# -----------------------------------------------------------------------------

QUANTITY_MEDICINES = {
    "statins": codelists.statins,
    "opioids": codelists.opioids,
    "injections": codelists.injections,
    "injections_oxy": codelists.injections_oxy,
    "inhalers": codelists.inhalers,
}


# -----------------------------------------------------------------------------
# Objective 2: investigate additional information in repeat_medications
# -----------------------------------------------------------------------------

REPEAT_TABLE_MEDICINES = {
    "repeat_med_1": codelists.repeat_1,
    "repeat_med_2": codelists.repeat_2,
}