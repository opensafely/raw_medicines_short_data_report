# import ehrql libraries
from ehrql import create_measures, years, case, when, months
from datetime import date, datetime
# import the measures functionality
from ehrql.measures import INTERVAL
from ehrql.tables.tpp import patients, practice_registrations, ons_deaths
from ehrql.tables.raw.tpp import repeat_medications, medications

# define start of period of interest
index_date = "2025-01-01"
start_date = datetime.strptime(index_date, "%Y-%m-%d").date()

# require registration to exist 
has_registration = practice_registrations.for_patient_on(
    INTERVAL.start_date
).exists_for_patient()

# require patient to be alive/dead: use ONS record if present, otherwise use GP record
death_date = ons_deaths.date.when_null_then(patients.date_of_death)
was_alive = death_date.is_after(INTERVAL.start_date) | death_date.is_null()
correct_age = patients.age_on(INTERVAL.start_date) <= 110

# define the interevals to be used for the measures
intervals_months = [
    (date(start_date.year, 1, 1), date(start_date.year, 3, 31)),
    (date(start_date.year, 4, 1), date(start_date.year, 6, 30)),
    (date(start_date.year, 7, 1), date(start_date.year, 9, 30)),
    (date(start_date.year, 10, 1), date(start_date.year, 12, 31)),
]
intervals_years = years(1).starting_on(index_date)

# create ehrQL generated dummy measures
measures = create_measures()

# define the size of a dummy population
measures.configure_dummy_data(population_size = 250)

# for the interval count the number of medication rows per patient
meds_no_int = (
    medications.where(medications.date.is_during(INTERVAL))
    .count_for_patient()
)
# now get the count for those with a non-missing repeat medication id
meds_no_rep_int = (
    medications.where(medications.date.is_during(INTERVAL))
    .where(medications.repeat_medication_id != -1)
    .count_for_patient()
)

# for the interval count the number of repeat medication
repeat_meds_no_int = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .where(repeat_medications.repeat_medication_id != -1)
    .count_for_patient()
)

# for the interval count the number of unique repeat IDs
repeat_rep_id_no_int = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .where(repeat_medications.repeat_medication_id != -1)
    .repeat_medication_id.count_distinct_for_patient()
)

# for the interval count the number of unique repeat IDs
med_rep_id_no_int = (
    medications.where(medications.date.is_during(INTERVAL))
    .where(medications.repeat_medication_id != -1)
    .repeat_medication_id.count_distinct_for_patient()
)

# define the measure to look at proportion of monthly prescriptions which are repeats
measures.define_measure(
    "proportion_meds_rep_id",
    numerator = meds_no_rep_int,
    denominator = meds_no_int,
    intervals = intervals_months
)

# define the measure to look at proportion of monthly repeat meds with unique repeat medication id
measures.define_measure(
    "proportion_repeats_unique_id",
    numerator = repeat_rep_id_no_int,
    denominator = repeat_meds_no_int,
    intervals = intervals_months
)

# define the measure to look at proportion of monthly repeat prescriptions with unique repeat medication id
measures.define_measure(
    "proportion_meds_unique_rep_id",
    numerator = med_rep_id_no_int,
    denominator = meds_no_rep_int,
    intervals = intervals_months
)

# count the number of rows and group by number of repeat IDs for each table
measures.define_measure(
    "repeat_ids",
    group_by={"distinct_ids_repeat" : repeat_rep_id_no_int},
    numerator=repeat_meds_no_int,
    denominator=repeat_meds_no_int,
    intervals=intervals_years
)
measures.define_measure(
    "issue_repeat_ids",
    group_by={"distinct_ids_issue": med_rep_id_no_int},
    numerator=meds_no_rep_int,
    denominator=meds_no_rep_int,
    intervals=intervals_years
)