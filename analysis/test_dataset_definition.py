"""
Assurance tests for the paper-facing patient-level ehrQL extraction.

Place alongside dataset_definition.py and config.py in analysis/.

The codes below come from the configured codelists rather than being invented.
This keeps the tests usable when the example medicines are changed. Each
expected_columns dictionary contains only columns relevant to that scenario;
ehrQL assurance tests do not require expectations for every dataset column.

Run: opensafely exec ehrql:v1 assure analysis/test_dataset_definition.py
"""

from datetime import date

from dataset_definition import dataset  # noqa: F401 - used by ehrQL assure
import config

INDEX = date(2025, 1, 1)
END = date(2026, 10, 1)


def example_code(codelist):
    """Select an actual dm+d code from a configured ehrQL codelist."""
    return str(next(iter(codelist)))


def person(born=date(1982, 3, 1), sex="female"):
    return [{"date_of_birth": born, "date_of_death": None, "sex": sex}]


def registration(end=None):
    return [{"start_date": date(2014, 5, 26), "end_date": end}]


def issue(day, code, repeat_id=-1, quantity="28 tablet", status=0):
    return {
        "date": day,
        "dmd_code": code,
        "repeat_medication_id": repeat_id,
        "quantity": quantity,
        "medication_status": status,
    }


def repeat(day, start, end, code, repeat_id, quantity="28 tablet", status=0):
    return {
        "date": day,
        "start_date": start,
        "end_date": end,
        "dmd_code": code,
        "repeat_medication_id": repeat_id,
        "quantity": quantity,
        "medication_status": status,
    }


def record(patient, issues=None, repeats=None, *, registered_until=None,
           born=date(1982, 3, 1), sex="female", death=None):
    return {
        "patients": person(born, sex),
        "practice_registrations": registration(registered_until),
        "ons_deaths": [{"date": death}] if death else [],
        "medications_raw": issues or [],
        "repeat_medications_raw": repeats or [],
    }


# A test medicine is drawn from the actual configuration; no assumptions about
# codelist attribute names (e.g. codelists.statins) are necessary here.
issue_name, issue_list = next(iter(config.ISSUE_COMPARISON_MEDICINES.items()))
issue_code = example_code(issue_list)
quantity_name, quantity_list = next(iter(config.QUANTITY_MEDICINES.items()))
quantity_code = example_code(quantity_list)
repeat_name, repeat_list = next(iter(config.REPEAT_TABLE_MEDICINES.items()))
repeat_code = example_code(repeat_list)


def expected_issue_counts(events):
    """Expected Objective 1a counts for the supplied synthetic issue events."""
    result = {}
    for name, codes in config.ISSUE_COMPARISON_MEDICINES.items():
        members = set(map(str, codes))
        qualifying = [
            row for row in events
            if INDEX <= row["date"] <= END
            and row["medication_status"] != 6
            and row["dmd_code"] in members
        ]
        result[f"{name}_issue"] = sum(
            row["repeat_medication_id"] == -1 for row in qualifying
        )
        result[f"{name}_repeat_issue"] = sum(
            row["repeat_medication_id"] != -1 for row in qualifying
        )
    return result


# Patient 1: selected repeat with issues before start, after end, changed
# quantity and changed DMD under the SAME repeat ID; later same-DMD issue under
# a DIFFERENT ID. A private issue must not affect any extracted values.
patient_1_issues = [
    issue(date(2024, 12, 20), repeat_code, 100, "28 tablet"),
    issue(date(2025, 2, 1), repeat_code, 100, "28 tablet"),
    issue(date(2025, 4, 1), repeat_code, 100, "56 tablet"),
    issue(date(2025, 6, 1), repeat_code, 101, "56 tablet"),
    issue(date(2025, 7, 1), repeat_code, 100, "84 tablet", status=6),
]
patient_1_repeat = repeat(
    date(2025, 1, 10), date(2025, 1, 1), date(2025, 3, 1),
    repeat_code, 100, "28 tablet",
)

# Patient 2: same-DMD prescribing continues after end under a NEW ID, but
# no linked issue occurs after end for the selected repeat ID.
patient_2_issues = [
    issue(date(2025, 2, 1), repeat_code, 200, "28 tablet"),
    issue(date(2025, 5, 1), repeat_code, 201, "56 tablet"),
]
patient_2_repeat = repeat(
    date(2025, 1, 10), date(2025, 1, 1), date(2025, 3, 1),
    repeat_code, 200, "28 tablet",
)

# Patient 3: registration ends mid-study. Later issues and repeat records
# must not be selected for Objective 1a or Objective 2.
patient_3_issues = [
    issue(date(2025, 2, 1), issue_code, -1),
    issue(date(2025, 7, 1), issue_code, -1),
]

# Patient 4: first non-repeat and repeat-linked quantity records, plus a
# private issue which should not be selected.
patient_4_issues = [
    issue(date(2025, 2, 1), quantity_code, -1, "28 tablet"),
    issue(date(2025, 3, 1), quantity_code, 400, "56 tablet"),
    issue(date(2025, 1, 15), quantity_code, -1, "999 tablet", status=6),
]

# Patient 5: no linked issue for the selected repeat ID.
patient_5_repeat = repeat(
    date(2025, 2, 1), date(2025, 2, 1), date(2025, 8, 1),
    repeat_code, 500,
)


test_data = {
    1: {
        **record(1, patient_1_issues, [patient_1_repeat]),
        "expected_in_population": True,
        "expected_columns": {
            "patient_age": 42,
            "patient_sex": "female",
            "age_cat": "25-54",
            "followup_end": END,
            **expected_issue_counts(patient_1_issues),
            f"{repeat_name}_repeat_date": date(2025, 1, 10),
            f"{repeat_name}_repeat_start_date": date(2025, 1, 1),
            f"{repeat_name}_repeat_end_date": date(2025, 3, 1),
            f"{repeat_name}_repeat_dmd_code": repeat_code,
            f"{repeat_name}_repeat_quantity": "28 tablet",
            f"{repeat_name}_linked_issue_exists": True,
            f"{repeat_name}_linked_issue_count": 3,
            f"{repeat_name}_first_linked_issue_date": date(2024, 12, 20),
            f"{repeat_name}_first_linked_issue_dmd_code": repeat_code,
            f"{repeat_name}_first_linked_issue_quantity": "28 tablet",
            f"{repeat_name}_last_linked_issue_date": date(2025, 4, 1),
            f"{repeat_name}_last_linked_issue_quantity": "56 tablet",
            f"{repeat_name}_first_linked_issue_after_end_date": date(2025, 4, 1),
            f"{repeat_name}_first_same_dmd_issue_after_end_date": date(2025, 4, 1),
        },
    },
    2: {
        **record(2, patient_2_issues, [patient_2_repeat]),
        "expected_in_population": True,
        "expected_columns": {
            "followup_end": END,
            f"{repeat_name}_linked_issue_exists": True,
            f"{repeat_name}_linked_issue_count": 1,
            f"{repeat_name}_first_linked_issue_after_end_date": None,
            f"{repeat_name}_first_same_dmd_issue_after_end_date": date(2025, 5, 1),
        },
    },
    3: {
        **record(3, patient_3_issues, registered_until=date(2025, 4, 1)),
        "expected_in_population": True,
        "expected_columns": {
            "followup_end": date(2025, 4, 1),
            **expected_issue_counts(patient_3_issues[:1]),
        },
    },
    4: {
        **record(4, patient_4_issues),
        "expected_in_population": True,
        "expected_columns": {
            "followup_end": END,
            f"{quantity_name}_issue_quantity": "28 tablet",
            f"{quantity_name}_issue_code": quantity_code,
            f"{quantity_name}_repeat_issue_quantity": "56 tablet",
            f"{quantity_name}_repeat_issue_code": quantity_code,
            **expected_issue_counts(patient_4_issues),
        },
    },
    5: {
        **record(5, [], [patient_5_repeat]),
        "expected_in_population": True,
        "expected_columns": {
            f"{repeat_name}_linked_issue_exists": False,
            f"{repeat_name}_linked_issue_count": 0,
            f"{repeat_name}_first_linked_issue_date": None,
        },
    },
    6: {
        **record(6, born=date(2008, 1, 2)),
        "expected_in_population": False,  # 16 at index
    },
    7: {
        **record(7, born=date(2007, 1, 1)),
        "expected_in_population": True,  # exactly 18 at index
        "expected_columns": {
            "patient_age": 18,
            "age_cat": "<25",
            "followup_end": END,
        },
    },
    8: {
        **record(8, registered_until=date(2024, 12, 24)),
        "expected_in_population": False,
    },
    9: {
        **record(9, death=date(2024, 2, 24)),
        "expected_in_population": False,
    },
    10: {
        **record(10, death=date(2025, 5, 1)),
        "expected_in_population": True,
        "expected_columns": {
            "followup_end": date(2025, 5, 1),
        },
    },
}
