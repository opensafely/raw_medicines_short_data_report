# import ehrql libraries
from ehrql import create_measures, years, case, when, months
# import the measures functionality
from ehrql.measures import INTERVAL
from ehrql.tables.tpp import patients, practice_registrations, ons_deaths
from ehrql.tables.raw.tpp import repeat_medications, medications

# define start of period of interest
index_date = "2025-01-01"

# require registration to exist 
has_registration = practice_registrations.for_patient_on(
    INTERVAL.start_date
).exists_for_patient()

# require patient to be alive/dead: use ONS record if present, otherwise use GP record
death_date = ons_deaths.date.when_null_then(patients.date_of_death)
was_alive = death_date.is_after(INTERVAL.start_date) | death_date.is_null()

# define the interevals to be used for the measures
intervals_years = years(2).starting_on(index_date)

# create ehrQL generated dummy measures
measures = create_measures()

# define the size of a dummy population
measures.configure_dummy_data(population_size = 250)

# for the interval count the number of medication rows per patient
meds_no_int = (
    medications.where(medications.date.is_during(INTERVAL))
    .count_for_patient()
)
meds_no = medications.count_for_patient()

# for the interval count the number of unique repeat IDs
meds_rep_id_no_int = (
    medications.where(medications.date.is_during(INTERVAL))
    .repeat_medication_id.count_distinct_for_patient()
)
meds_rep_id_no = (
    medications.repeat_medication_id
    .count_distinct_for_patient()
)

# for the interval count the number of repeat medication
repeat_meds_no_int = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .count_for_patient()
)
repeat_meds_no = repeat_medications.count_for_patient()

# for the interval count the number of unique repeat IDs
repeat_rep_id_no_int = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .repeat_medication_id.count_distinct_for_patient()
)
repeat_rep_id_no = (
    repeat_medications.repeat_medication_id.count_distinct_for_patient()
)

# get number of occasions start_date and consultation date are same per patient
concordant_dates = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .where(repeat_medications.date == repeat_medications.start_date)
    .date
    .count_distinct_for_patient()
)

# get number of occasions start_date and consultation date are different per patient
discordant_dates = (
    repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
    .where(repeat_medications.date != repeat_medications.start_date)
    .date
    .count_distinct_for_patient()
)

## define measures

# number of rows per patient in interval compared to all time
measures.define_measure(
    "medications_rows",
    numerator = meds_no_int,
    denominator = meds_no,
    intervals = intervals_years
)

# number of unique rep ids in interval compared to all time
measures.define_measure(
    "medications_rep_ids",
    numerator = meds_rep_id_no_int,
    denominator = meds_rep_id_no,
    intervals = intervals_years
)

# number of rows per patient in interval compared to all time
measures.define_measure(
    "repeats_rows",
    numerator = repeat_meds_no_int,
    denominator = repeat_meds_no,
    intervals = intervals_years
)

# number of unique rep ids in interval compared to all time
measures.define_measure(
    "repeats_rep_ids",
    numerator = repeat_rep_id_no_int,
    denominator = repeat_rep_id_no,
    intervals = intervals_years
)

# number of concordant dates out of number of rows
measures.define_measure(
    "concordant_dates",
    numerator = concordant_dates,
    denominator = repeat_meds_no_int,
    intervals = intervals_years
)

# number of discordant dates out of number of rows
measures.define_measure(
    "discordant_dates",
    numerator = discordant_dates,
    denominator = repeat_meds_no,
    intervals = intervals_years
)
