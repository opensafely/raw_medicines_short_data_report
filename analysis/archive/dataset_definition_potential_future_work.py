"""Exploratory ehrQL analyses removed from the main paper dataset.

These blocks were useful during data discovery, or may support future work, but
are not required for the current paper's core questions. They are kept here so
that the work is not lost and can be reintroduced deliberately if needed.
"""

from datetime import date

from ehrql import create_dataset, days, case, when
from ehrql.tables.tpp import patients, practice_registrations, ons_deaths
from ehrql.tables.raw.tpp import repeat_medications, medications

import codelists


# Shared cohort setup ----------------------------------------------------------
medications = medications.where(medications.medication_status != 6)
repeat_medications = repeat_medications.where(repeat_medications.medication_status != 6)

dataset = create_dataset()
index_date = "2025-01-01"

has_registration = practice_registrations.for_patient_on(index_date).exists_for_patient()
death_date = ons_deaths.date.when_null_then(patients.date_of_death)
was_alive = death_date.is_after(index_date) | death_date.is_null()
correct_age = (patients.age_on(index_date) > 0) & (patients.age_on(index_date) <= 110)
dataset.define_population(has_registration & was_alive & correct_age)
dataset.configure_dummy_data(population_size=50)


# 1. General table/data-quality diagnostics -----------------------------------
dataset.meds_exist = (
    medications.where(medications.date.is_on_or_after(index_date)).exists_for_patient()
)

dataset.active_repeats = (
    repeat_medications
    .where(repeat_medications.end_date.is_after(index_date))
    .repeat_medication_id.count_distinct_for_patient()
)

dataset.meds_row_no = (
    medications.where(medications.date.is_on_or_after(index_date)).count_for_patient()
)
dataset.meds_rep_id_no = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id != -1)
    .repeat_medication_id.count_distinct_for_patient()
)
dataset.meds_consult_id_no = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .consultation_id.count_distinct_for_patient()
)

dataset.repeats_row_no = (
    repeat_medications.where(repeat_medications.date.is_on_or_after(index_date)).count_for_patient()
)
dataset.repeats_rep_id_no = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.repeat_medication_id != -1)
    .repeat_medication_id.count_distinct_for_patient()
)
dataset.repeats_consult_id_no = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .consultation_id.count_distinct_for_patient()
)
dataset.rep_ids_differ = dataset.meds_rep_id_no != dataset.repeats_rep_id_no

dataset.medications_missing_rep_id = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id == -1)
    .count_for_patient()
)
dataset.repeats_missing_rep_id = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.repeat_medication_id == -1)
    .count_for_patient()
)
dataset.medications_missing_date = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.date.is_after(date.today()))
    .count_for_patient()
)
dataset.rep_missing_date = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.date.is_after(date.today()))
    .count_for_patient()
)
dataset.rep_missing_start_date = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(~repeat_medications.start_date.is_between_but_not_on(index_date - days(1), "9999-12-31"))
    .count_for_patient()
)
dataset.rep_missing_end_date = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(~repeat_medications.end_date.is_between_but_not_on(index_date - days(1), "9999-12-31"))
    .count_for_patient()
)
dataset.rep_end_date_in_future = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.end_date.is_after(date.today()))
    .count_for_patient()
)


# 2. Consultation date vs repeat start-date exploration -----------------------
dataset.concordant_dates = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.date == repeat_medications.start_date)
    .date.count_distinct_for_patient()
)
dataset.discordant_dates = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.date != repeat_medications.start_date)
    .date.count_distinct_for_patient()
)
dataset.start_date_first = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.start_date.is_after("1900-01-01"))
    .where(repeat_medications.date > repeat_medications.start_date)
    .count_for_patient()
)
dataset.start_date_second = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.start_date.is_on_or_between(index_date, "9999-12-31"))
    .where(repeat_medications.date < repeat_medications.start_date)
    .count_for_patient()
)


# 3. Medication-status exploration -------------------------------------------
# This produces 6 x 29 columns and is intentionally kept out of the main paper
# dataset unless medication_status becomes necessary to interpret Section 1.
for status in range(29):
    dataset.add_column(
        f"medications_status_{status}",
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"repeats_status_{status}",
        repeat_medications
        .where(repeat_medications.date.is_on_or_after(index_date))
        .where(repeat_medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"medications_status_with_rep_id_{status}",
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.repeat_medication_id != -1)
        .where(medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"nhs_issues_status_{status}",
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.dmd_code.is_in(codelists.nhs_issues))
        .where(medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"private_issues_status_{status}",
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.dmd_code.is_in(codelists.private_issues))
        .where(medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"installment_issues_status_{status}",
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.dmd_code.is_in(codelists.installment))
        .where(medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"nhs_issues_rep_status_{status}",
        repeat_medications
        .where(repeat_medications.date.is_on_or_after(index_date))
        .where(repeat_medications.dmd_code.is_in(codelists.nhs_issues))
        .where(repeat_medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"private_issues_rep_status_{status}",
        repeat_medications
        .where(repeat_medications.date.is_on_or_after(index_date))
        .where(repeat_medications.dmd_code.is_in(codelists.private_issues))
        .where(repeat_medications.medication_status.is_in([status]))
        .count_for_patient(),
    )
    dataset.add_column(
        f"installment_issues_rep_status_{status}",
        repeat_medications
        .where(repeat_medications.date.is_on_or_after(index_date))
        .where(repeat_medications.dmd_code.is_in(codelists.installment))
        .where(repeat_medications.medication_status.is_in([status]))
        .count_for_patient(),
    )


# 4. Arbitrary first-row sampling ---------------------------------------------
# Superseded in the paper by selecting a repeat first and then linking issues to
# that repeat_medication_id.
medications_rows = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .sort_by(medications.date)
    .first_for_patient()
)
repeat_rows = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .sort_by(repeat_medications.date)
    .first_for_patient()
)
dataset.meds_sample_date = medications_rows.date
dataset.repeats_sample_date = repeat_rows.date
dataset.repeats_sample_start_date = repeat_rows.start_date
dataset.repeats_sample_end_date = repeat_rows.end_date
dataset.has_matching_repeat_med = case(
    when(medications_rows.repeat_medication_id == repeat_rows.repeat_medication_id).then(True),
    otherwise=False,
)
dataset.sample_issue_quantity = medications_rows.quantity
dataset.sample_repeat_quantity = repeat_rows.quantity
dataset.sample_issue_med = medications_rows.dmd_code
dataset.sample_repeat_med = repeat_rows.dmd_code


# 5. Bespoke statin/opioid blocks ---------------------------------------------
# Superseded by the generic codelist function in the main dataset.
dataset.statin_prescriptions = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id == -1)
    .where(medications.dmd_code.is_in(codelists.statins))
    .count_for_patient()
)
dataset.statin_repeats = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.dmd_code.is_in(codelists.statins))
    .exists_for_patient()
)
dataset.statin_repeat_issues = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id != -1)
    .where(medications.dmd_code.is_in(codelists.statins))
    .count_for_patient()
)
dataset.opioids_prescriptions = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id == -1)
    .where(medications.dmd_code.is_in(codelists.opioids))
    .count_for_patient()
)
dataset.opioids_repeats = (
    repeat_medications
    .where(repeat_medications.date.is_on_or_after(index_date))
    .where(repeat_medications.dmd_code.is_in(codelists.opioids))
    .exists_for_patient()
)
dataset.opioids_repeat_issues = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id != -1)
    .where(medications.dmd_code.is_in(codelists.opioids))
    .count_for_patient()
)


# 6. Standalone formulation-specific quantity exploration --------------------
# Keep for future quantity work; the main paper extraction now uses the generic
# issue characterisation and can add a prototype-specific extraction later.
for name, codelist in [
    ("injections", codelists.injections),
    ("injections_oxy", codelists.injections_oxy),
    ("inhalers", codelists.inhalers),
]:
    first_row = (
        medications
        .where(medications.date.is_on_or_after(index_date))
        .where(medications.dmd_code.is_in(codelist))
        .sort_by(medications.date)
        .first_for_patient()
    )
    dataset.add_column(f"{name}_quantity", first_row.quantity)
    dataset.add_column(f"{name}_code", first_row.dmd_code)


# 7. Previous "active repeat" experiment -------------------------------------
# Archived because it assumes end_date > run date identifies an active repeat,
# while the current paper explicitly tests whether end_date can be interpreted
# that way.
active_repeat_row = (
    repeat_medications
    .where(repeat_medications.end_date.is_between_but_not_on(date.today(), "9999-12-31"))
    .where(repeat_medications.repeat_medication_id != -1)
    .sort_by(repeat_medications.start_date)
    .first_for_patient()
)
active_repeat_dmd_code = active_repeat_row.dmd_code
active_repeat_id = active_repeat_row.repeat_medication_id

dataset.matching_id = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id == active_repeat_id)
    .exists_for_patient()
)
dataset.matching_dmd_code = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.dmd_code == active_repeat_dmd_code)
    .exists_for_patient()
)
dataset.matching_both = (
    medications
    .where(medications.date.is_on_or_after(index_date))
    .where(medications.repeat_medication_id == active_repeat_id)
    .where(medications.dmd_code == active_repeat_dmd_code)
    .exists_for_patient()
)
dataset.matching_row = dataset.matching_id | dataset.matching_dmd_code | dataset.matching_both

dataset.matching_id_first_date = (
    medications
    .where(medications.repeat_medication_id == active_repeat_id)
    .sort_by(medications.date)
    .first_for_patient().date
)
dataset.matching_id_last_date = (
    medications
    .where(medications.repeat_medication_id == active_repeat_id)
    .sort_by(medications.date)
    .last_for_patient().date
)
dataset.matching_dmd_code_first_date = (
    medications
    .where(medications.dmd_code == active_repeat_dmd_code)
    .sort_by(medications.date)
    .first_for_patient().date
)
dataset.matching_dmd_code_last_date = (
    medications
    .where(medications.dmd_code == active_repeat_dmd_code)
    .sort_by(medications.date)
    .last_for_patient().date
)
dataset.matching_both_first_date = (
    medications
    .where(medications.repeat_medication_id == active_repeat_id)
    .where(medications.dmd_code == active_repeat_dmd_code)
    .sort_by(medications.date)
    .first_for_patient().date
)
dataset.matching_both_last_date = (
    medications
    .where(medications.repeat_medication_id == active_repeat_id)
    .where(medications.dmd_code == active_repeat_dmd_code)
    .sort_by(medications.date)
    .last_for_patient().date
)
