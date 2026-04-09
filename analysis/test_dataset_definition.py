# import python functions
from datetime import date
# import the dataset generation mechanism to test against
from dataset_definition import dataset 

# create test data to check dataset def is working
test_data = {

    # expected in population
    1 : {
        "practice_registrations": [
            {
                "start_date": date(2014, 5, 26),
                "end_date": None
            }
        ],
        "patients": [
            {
                "date_of_birth": date(1982, 3, 1),
                "date_of_death": None
            }
        ],
        "ons_deaths": [
            {
                "date": None
            }
        ],
        "medications_raw": [
            {
                "date": date(2025, 2, 1),
                "dmd_code": "10983311000001107",
                "repeat_medication_id": -1,
                "medication_status": 0,
                "consultation_id": 45
            },
            {
                "date": date(2025, 4, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3,
                "medication_status": 0,
                "consultation_id": 454
            },
            {
                "date": date(2025, 5, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3,
                "medication_status": 0,
                "consultation_id": 4519
            },
            {
                "date": date(2025, 6, 6),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "consultation_id": 4522
            },
            {
                "date": date(2025, 8, 12),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "consultation_id": 4
            },
            {
                "date": date(2025, 10, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "consultation_id": 45092
            },
            {
                "date": date(2025, 12, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "consultation_id": 45
            },
            {
                "date": date(2026, 1, 15),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "consultation_id": 45
            }
        ],
        "repeat_medications_raw": [
            {
                "date": date(2025, 4, 1),
                "start_date": date(2025, 4, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3,
                "medication_status": 0,
                "end_date": date(2026, 3, 5),
                "consultation_id": 459
            },
            {
                "date": date(2025, 5, 1),
                "start_date": date(2025, 5, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3,
                "medication_status": 0,
                "end_date": date(2026, 8, 5),
                "consultation_id": 492
            },
            {
                "date": date(2025, 6, 6),
                "start_date": date(2025, 6, 6),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "end_date": date(2025, 12, 5),
                "consultation_id": 45249
            },
            {
                "date": date(2025, 8, 12),
                "start_date": date(2025, 9, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "end_date": date(2025, 11, 1),
                "consultation_id": 4512345
            },
            {
                "date": date(2025, 10, 1),
                "start_date": date(2025, 10, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "end_date": date(2026, 1, 1),
                "consultation_id": 45234567
            },
            {
                "date": date(2025, 12, 1),
                "start_date": date(2025, 12, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "end_date": date(2026, 8, 1),
                "consultation_id": 5
            },
            {
                "date": date(2026, 1, 15),
                "start_date": date(2026, 2, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8,
                "medication_status": 0,
                "end_date": date(2026, 2, 5),
                "consultation_id": 45098765
            }
        ],
        "expected_in_population": True,
        "expected_columns": {
            "active_repeats": 2,
            "meds_sample_date": date(2025, 2, 1),
            "repeats_sample_date": date(2025, 4, 1),
            "repeats_sample_start_date": date(2025, 4, 1),
            "repeats_sample_end_date": date(2026, 3, 5),
            "meds_row_no": 8,
            "meds_rep_id_no": 2,
            "meds_consult_id_no": 6,
            "repeats_row_no": 7,
            "repeats_rep_id_no": 2,
            "repeats_consult_id_no": 7,
            "rep_ids_differ": False,
            "concordant_dates": 5,
            "discordant_dates": 2,
            "medications_status_0": 8,
            "medications_status_1": 0,
            "medications_status_2": 0,
            "medications_status_3": 0,
            "medications_status_4": 0,
            "medications_status_5": 0,
            "medications_status_6": 0,
            "medications_status_7": 0,
            "medications_status_8": 0,
            "medications_status_9": 0,
            "medications_status_10": 0,
            "medications_status_11": 0,
            "medications_status_12": 0,
            "medications_status_13": 0,
            "medications_status_14": 0,
            "medications_status_15": 0,
            "medications_status_16": 0,
            "medications_status_17": 0,
            "medications_status_18": 0,
            "medications_status_19": 0,
            "medications_status_20": 0,
            "medications_status_21": 0,
            "medications_status_22": 0,
            "medications_status_23": 0,
            "medications_status_24": 0,
            "medications_status_25": 0,
            "medications_status_26": 0,
            "medications_status_27": 0,
            "medications_status_28": 0,
            "repeats_status_0": 7,
            "repeats_status_1": 0,
            "repeats_status_2": 0,
            "repeats_status_3": 0,
            "repeats_status_4": 0,
            "repeats_status_5": 0,
            "repeats_status_6": 0,
            "repeats_status_7": 0,
            "repeats_status_8": 0,
            "repeats_status_9": 0,
            "repeats_status_10": 0,
            "repeats_status_11": 0,
            "repeats_status_12": 0,
            "repeats_status_13": 0,
            "repeats_status_14": 0,
            "repeats_status_15": 0,
            "repeats_status_16": 0,
            "repeats_status_17": 0,
            "repeats_status_18": 0,
            "repeats_status_19": 0,
            "repeats_status_20": 0,
            "repeats_status_21": 0,
            "repeats_status_22": 0,
            "repeats_status_23": 0,
            "repeats_status_24": 0,
            "repeats_status_25": 0,
            "repeats_status_26": 0,
            "repeats_status_27": 0,
            "repeats_status_28": 0
        }
    },

    # not expected in population - not registered
    2 : {
        "practice_registrations": [
            {
                "start_date": date(2014, 5, 26),
                "end_date": date(2024, 12, 24)
            }
        ],
        "patients": [
            {
                "date_of_birth": date(1967, 7, 1),
                "date_of_death": None
            }
        ],
        "ons_deaths": [
            {
                "date": None
            }
        ],
        "medications_raw": [],
        "repeat_medications_raw": [],
        "expected_in_population": False
    },

    # not expected in population - not alive
    3 : {
        "practice_registrations": [
            {
                "start_date": date(2019, 1, 2),
                "end_date": None
            }
        ],
        "patients": [
            {
                "date_of_birth": date(2002, 9, 1),
                "date_of_death": None
            }
        ],
        "ons_deaths": [
            {
                "date": date(2024, 2, 24)
            }
        ],
        "medications_raw": [],
        "repeat_medications_raw": [],
        "expected_in_population": False
    }

}