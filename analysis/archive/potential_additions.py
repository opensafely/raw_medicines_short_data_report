# # get number of occasions start_date and consultation date are same per patient
# dataset.concordant_dates = (
#     repeat_medications.where(repeat_medications.date == repeat_medications.start_date)
#     .date
#     .count_distinct_for_patient()
# )

# # get number of occasions start_date and consultation date are different per patient
# dataset.discordant_dates = (
#     repeat_medications.where(repeat_medications.date != repeat_medications.start_date)
#     .date
#     .count_distinct_for_patient()
# )

# # get T/F about statin repeat
# dataset.statins = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.statins))
#     .exists_for_patient()
# )

# # count how many times this appears
# dataset.statins_count = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.statins))
#     .date
#     .count_distinct_for_patient()
# )

# # similarly, get the count from the medications table
# dataset.statins_counts_med_tab = (
#     medications.where(medications.dmd_code.is_in(codelists.statins))
#     .date
#     .count_distinct_for_patient()
# )

# # get T/F about codeine-containing meds repeat
# dataset.codeine = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.codeine))
#     .exists_for_patient()
# )

# # count how many times this appears
# dataset.codeine_count = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.codeine))
#     .date
#     .count_distinct_for_patient()
# )

# # similarly, get the count from the medications table
# dataset.codeine_counts_med_tab = (
#     medications.where(medications.dmd_code.is_in(codelists.codeine))
#     .date
#     .count_distinct_for_patient()
# )

# show(dataset)

# statins_med = (
#     medications.where(medications.dmd_code.is_in(codelists.statins))
#     .sort_by(medications.date)
# )
# statins_rep = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.stains))
#     .sort_by(repeat_medications.date)
# )
# codeine_med = (
#     medications.where(medications.dmd_code.is_in(codelists.codeine))
#     .sort_by(medications.date)
# )
# codeine_rep = (
#     repeat_medications.where(repeat_medications.dmd_code.is_in(codelists.codeine))
#     .sort_by(repeat_medications.date)
# )
# concordant_dates = (
#     repeat_medications.where(repeat_medications.date == repeat_medications.start_date)
#     .date
# )
# discordant_dates = (
#     repeat_medications.where(repeat_medications.date != repeat_medications.start_date)
#     .date
# )

# selected_medications_dict = {
#     "statins_med": statins_med,
#     "statins_rep": statins_rep,
#     "codeine_med": codeine_med,
#     "codeine_rep": codeine_rep
# }

# # Count all medication status
# # This will add 6 x 28 = 168 new columns
# for desc, selected_medications in selected_medications_dict.items():
#     for status in range(29):
#         count_med_status_query = selected_medications.where(
#             selected_medications.medication_status.is_in([status])
#         ).count_for_patient()
#         dataset.add_column(f"{desc}_status{status}", count_med_status_query)


##------- measures definition -------##

# # get number of occasions start_date and consultation date are same per patient
# concordant_dates = (
#     repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
#     .where(repeat_medications.date == repeat_medications.start_date)
#     .date
#     .count_distinct_for_patient()
# )

# # get number of occasions start_date and consultation date are different per patient
# discordant_dates = (
#     repeat_medications.where(repeat_medications.date.is_during(INTERVAL))
#     .where(repeat_medications.date != repeat_medications.start_date)
#     .date
#     .count_distinct_for_patient()
# )

# ## define measures

# # number of rows per patient in interval compared to all time
# measures.define_measure(
#     "medications_rows",
#     numerator = meds_no_int,
#     denominator = meds_no,
#     intervals = intervals_years
# )

# # number of unique rep ids in interval compared to all time
# measures.define_measure(
#     "medications_rep_ids",
#     numerator = meds_rep_id_no_int,
#     denominator = meds_rep_id_no,
#     intervals = intervals_years
# )

# # number of rows per patient in interval compared to all time
# measures.define_measure(
#     "repeats_rows",
#     numerator = repeat_meds_no_int,
#     denominator = repeat_meds_no,
#     intervals = intervals_years
# )

# # number of unique rep ids in interval compared to all time
# measures.define_measure(
#     "repeats_rep_ids",
#     numerator = repeat_rep_id_no_int,
#     denominator = repeat_rep_id_no,
#     intervals = intervals_years
# )

# # number of concordant dates out of number of rows
# measures.define_measure(
#     "concordant_dates",
#     numerator = concordant_dates,
#     denominator = repeat_meds_no_int,
#     intervals = intervals_years
# )

# # number of discordant dates out of number of rows
# measures.define_measure(
#     "discordant_dates",
#     numerator = discordant_dates,
#     denominator = repeat_meds_no,
#     intervals = intervals_years
# )