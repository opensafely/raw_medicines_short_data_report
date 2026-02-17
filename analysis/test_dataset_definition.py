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
                "repeat_medication_id": None
            },
            {
                "date": date(2025, 4, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3
            },
            {
                "date": date(2025, 5, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3
            },
            {
                "date": date(2025, 6, 6),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 8, 12),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 10, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 12, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2026, 1, 15),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            }
        ],
        "repeat_medications_raw": [
            {
                "date": date(2025, 4, 1),
                "start_date": date(2025, 4, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3
            },
            {
                "date": date(2025, 5, 1),
                "start_date": date(2025, 5, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 3
            },
            {
                "date": date(2025, 6, 6),
                "start_date": date(2025, 6, 6),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 8, 12),
                "start_date": date(2025, 9, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 10, 1),
                "start_date": date(2025, 10, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2025, 12, 1),
                "start_date": date(2025, 12, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            },
            {
                "date": date(2026, 1, 15),
                "start_date": date(2026, 2, 1),
                "dmd_code" : "3214311000001108",
                "repeat_medication_id": 8
            }
        ],
        "expected_in_population": True,
        "expected_columns": {
            "meds_row_no": 8,
            "meds_rep_id_no": 2,
            "repeats_row_no": 7,
            "repeats_rep_id_no": 2,
            "rep_ids_differ": False,
            "concordant_dates": 5,
            "discordant_dates": 2
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