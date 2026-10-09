"""Main ehrQL dataset for the repeat-prescribing methods paper.

Paper structure
---------------
1. What information could we additionally provide with the Medication Issues table in OpenSAFELY
    a. Can we identify repeat prescriptions by exposing the repeat_medication_id field?
    b. Can we explore prescribing behaviours by exposing the quantity field?
2. Can the repeat table provide any additional information for research into repeat prescribing such as:
    a. whether dosage and/or quantity changes in prescriptions create a new identifier for repeats - via concordance between products and quantities between repeat and issue tables
    b. whether temporal information can be learned from date information such as:
        i. whether a repeat prescription is actively being prescribed via the end_date field
        ii. whether issues of a repeat medication occur prior to the start_date and/or after the end_date
        iii. consequently, whether we can determine treatment duration
3. Practical guidance

Patient-level outputs only. Record-level comparisons are made by selecting one
repeat record per patient and reducing linked issue records to counts/first/last
records.
"""

from ehrql import create_dataset, case, when, minimum_of
from ehrql.tables.tpp import patients, practice_registrations, ons_deaths
from ehrql.tables.raw.tpp import repeat_medications, medications

import config


# -----------------------------------------------------------------------------
# Cohort setup
# -----------------------------------------------------------------------------

# Remove private prescriptions.
medications = medications.where(medications.medication_status != 6)
repeat_medications = repeat_medications.where(repeat_medications.medication_status != 6)

dataset = create_dataset()

# define study period
index_date = "2025-01-01"
end_date = "2026-10-01"

has_registration = practice_registrations.for_patient_on(index_date).exists_for_patient()
death_date = ons_deaths.date.when_null_then(patients.date_of_death)
was_alive = death_date.is_after(index_date) | death_date.is_null()
correct_age = (patients.age_on(index_date) >= 18) & (patients.age_on(index_date) <= 110)

dataset.define_population(has_registration & was_alive & correct_age)
dataset.configure_dummy_data(population_size = 250)

# define end of follow-up to account for censoring
followup_end = minimum_of(death_date, practice_registrations.end_date.for_patient_on(index_date), end_date)
dataset.add_column("followup_end", followup_end)

# Basic patient descriptors retained for stratified summaries if required.
dataset.patient_age = patients.age_on(index_date)
dataset.patient_sex = patients.sex
dataset.age_cat = case(
    when(patients.age_on(index_date) < 25).then("<25"),
    when((patients.age_on(index_date) >= 25) & (patients.age_on(index_date) < 55)).then("25-54"),
    when((patients.age_on(index_date) >= 55) & (patients.age_on(index_date) < 65)).then("55-64"),
    when(patients.age_on(index_date) >= 65).then("65+"),
    otherwise="Unknown",
)

# get medications from config file
ISSUE_COMPARISON_MEDICINES = config.ISSUE_COMPARISON_MEDICINES
QUANTITY_MEDICINES = config.QUANTITY_MEDICINES
REPEAT_TABLE_MEDICINES = config.REPEAT_TABLE_MEDICINES

# -----------------------------------------------------------------------------
# Sections 1 and 2: issue-table characterisation
# -----------------------------------------------------------------------------

def add_issue_characterisation(name, codelist):
    """Add issue-table measures for one medicine/codelist."""
    non_repeat_issues = (
        medications
        .where(medications.date.is_on_or_between(index_date, followup_end))
        .where(medications.repeat_medication_id == -1)
        .where(medications.dmd_code.is_in(codelist))
    )
    repeat_linked_issues = (
        medications
        .where(medications.date.is_on_or_between(index_date, followup_end))
        .where(medications.repeat_medication_id != -1)
        .where(medications.dmd_code.is_in(codelist))
    )

    dataset.add_column(f"{name}_issue", non_repeat_issues.count_for_patient())
    dataset.add_column(f"{name}_repeat_issue", repeat_linked_issues.count_for_patient())

def add_repeat_table_comparison(name, codelist):
    """Add repeat-table linkage, duplication and temporal measures for a medicine.

    The selected repeat is the first eligible repeat for the supplied codelist,
    so the complete Section 2 analysis can be rerun for any medicine by changing
    only the configuration dictionaries above.
    """
    selected_repeat = (
        repeat_medications
        .where(repeat_medications.date.is_on_or_between(index_date, followup_end))
        .where(repeat_medications.repeat_medication_id != -1)
        .where(repeat_medications.dmd_code.is_in(codelist))
        .sort_by(repeat_medications.date)
        .first_for_patient()
    )
    selected_repeat_id = selected_repeat.repeat_medication_id
    selected_repeat_dmd = selected_repeat.dmd_code
    selected_repeat_end = selected_repeat.end_date

    dataset.add_column(f"{name}_repeat_date", selected_repeat.date)
    dataset.add_column(f"{name}_repeat_start_date", selected_repeat.start_date)
    dataset.add_column(f"{name}_repeat_end_date", selected_repeat_end)
    dataset.add_column(f"{name}_repeat_dmd_code", selected_repeat_dmd)
    dataset.add_column(f"{name}_repeat_quantity", selected_repeat.quantity)

    # Exact linkage by repeat_medication_id.
    linked_issues = (
        medications
        .where(medications.date.is_on_or_before(followup_end))
        .where(medications.repeat_medication_id == selected_repeat_id)
    )
    first_linked_issue = linked_issues.sort_by(medications.date).first_for_patient()
    last_linked_issue = linked_issues.sort_by(medications.date).last_for_patient()

    dataset.add_column(f"{name}_linked_issue_exists", linked_issues.exists_for_patient())
    dataset.add_column(f"{name}_linked_issue_count", linked_issues.count_for_patient())
    dataset.add_column(f"{name}_first_linked_issue_date", first_linked_issue.date)
    dataset.add_column(f"{name}_first_linked_issue_dmd_code", first_linked_issue.dmd_code)
    dataset.add_column(f"{name}_first_linked_issue_quantity", first_linked_issue.quantity)
    dataset.add_column(f"{name}_last_linked_issue_date", last_linked_issue.date)
    dataset.add_column(f"{name}_last_linked_issue_dmd_code", last_linked_issue.dmd_code)
    dataset.add_column(f"{name}_last_linked_issue_quantity", last_linked_issue.quantity)

    # Same DMD irrespective of repeat ID, to distinguish record ending from
    # cessation of prescribing of the medicine itself.
    same_dmd_issues = (
        medications
        .where(medications.date.is_on_or_before(followup_end))
        .where(medications.dmd_code == selected_repeat_dmd)
    )
    #first_same_dmd_issue = same_dmd_issues.sort_by(medications.date).first_for_patient()
    last_same_dmd_issue = same_dmd_issues.sort_by(medications.date).last_for_patient()
    #dataset.add_column(f"{name}_first_same_dmd_issue_date", first_same_dmd_issue.date)
    dataset.add_column(f"{name}_last_same_dmd_issue_date", last_same_dmd_issue.date)

    linked_issues_after_end = linked_issues.where(medications.date > selected_repeat_end)
    same_dmd_issues_after_end = same_dmd_issues.where(medications.date > selected_repeat_end)
    first_linked_issue_after_end = (
        linked_issues_after_end.sort_by(medications.date).first_for_patient()
    )
    first_same_dmd_issue_after_end = (
        same_dmd_issues_after_end.sort_by(medications.date).first_for_patient()
    )

    dataset.add_column(
        f"{name}_first_linked_issue_after_end_date",
        first_linked_issue_after_end.date,
    )
    dataset.add_column(
        f"{name}_first_same_dmd_issue_after_end_date",
        first_same_dmd_issue_after_end.date,
    )

def add_quantity_characterisation(name, codelist):
    """Add quantity/DMD information for selected issue records."""

    non_repeat_issues = (
        medications
        .where(medications.date.is_on_or_between(index_date, followup_end))
        .where(medications.repeat_medication_id == -1)
        .where(medications.dmd_code.is_in(codelist))
    )

    repeat_linked_issues = (
        medications
        .where(medications.date.is_on_or_between(index_date, followup_end))
        .where(medications.repeat_medication_id != -1)
        .where(medications.dmd_code.is_in(codelist))
    )

    first_non_repeat_issue = (
        non_repeat_issues
        .sort_by(medications.date)
        .first_for_patient()
    )

    first_repeat_linked_issue = (
        repeat_linked_issues
        .sort_by(medications.date)
        .first_for_patient()
    )

    dataset.add_column(
        f"{name}_issue_quantity",
        first_non_repeat_issue.quantity,
    )
    dataset.add_column(
        f"{name}_issue_code",
        first_non_repeat_issue.dmd_code,
    )
    dataset.add_column(
        f"{name}_repeat_issue_quantity",
        first_repeat_linked_issue.quantity,
    )
    dataset.add_column(
        f"{name}_repeat_issue_code",
        first_repeat_linked_issue.dmd_code,
    )

# -----------------------------------------------------------------------------
# Run the same analysis consistently across configured medicines
# -----------------------------------------------------------------------------

for medicine_name, medicine_codelist in ISSUE_COMPARISON_MEDICINES.items():
    add_issue_characterisation(
        medicine_name,
        medicine_codelist,
    )

for medicine_name, medicine_codelist in QUANTITY_MEDICINES.items():
    add_quantity_characterisation(
        medicine_name,
        medicine_codelist,
    )

for medicine_name, medicine_codelist in REPEAT_TABLE_MEDICINES.items():
    add_repeat_table_comparison(
        medicine_name,
        medicine_codelist,
    )
    
# Derive downstream in R:
#
# Section 1: Medication Issues table
# - proportion of issues carrying repeat_medication_id
# - quantity completeness and interpretability
#
# Section 2a: repeat-ID / record concordance
# - DMD concordance:
#     repeat vs first linked issue vs last linked issue
# - quantity concordance:
#     repeat vs first linked issue vs last linked issue
# - whether DMD/quantity change while repeat_medication_id remains the same
#
# Section 2b: temporal information
# - recorded repeat duration = repeat_end_date - repeat_start_date
# - observed linked-issue duration =
#     last_linked_issue_date - first_linked_issue_date
# - first linked issue before repeat_start_date
# - last linked issue after repeat_end_date
# - time from repeat end to first subsequent linked issue
# - same-DMD issue after repeat end irrespective of repeat_medication_id
