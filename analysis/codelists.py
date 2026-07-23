# import ehrql function for importing codelists
from ehrql import (
  codelist_from_csv
)

# statins
statins = codelist_from_csv(
    "codelists/user-emprestige-all-statins-dmd.csv",
    column = "code"
)

# codeine products
codeine = codelist_from_csv(
    "codelists/user-emprestige-codeine-for-pain-dmd.csv",
    column = "code"
)

# opioids 
opioids = codelist_from_csv(
    "codelists/opensafely-high-dose-long-acting-opioids-openprescribing-dmd.csv",
    column = "code"
)

# nhs issues
nhs_issues = codelist_from_csv(
    "codelists/user-chriswood-repeat-table-sdr-nhs-issue.csv",
    column = "code"
)

# private issue
private_issues = codelist_from_csv(
    "codelists/user-chriswood-sdr-private-issue.csv",
    column = "code"
)

# installment dispensed issue
installment = codelist_from_csv(
    "codelists/user-chriswood-repeat-table-sdr-instalment-dispensed-issue.csv",
    column = "code"
)

# other types of meds
injections = codelist_from_csv(
    "codelists/opensafely-long-acting-injectable-and-depot-antipsychotics-dmd.csv",
    column = "code"
)
injections_oxy = codelist_from_csv(
    "codelists/opensafely-oxycodone-subcutaneous-dmd.csv",
    column = "code"
)
inhalers = codelist_from_csv(
    "codelists/user-emprestige-all-inhalers-dmd.csv",
    column = "code"
)

# testing
acute_1 = codelist_from_csv(
    "codelists/user-chriswood-example-acute-medications.csv",
    column = "code"
)
acute_2 = codelist_from_csv(
    "codelists/user-chriswood-example-acute-medications-tramadol.csv",
    column = "code"
)
repeat_1 = codelist_from_csv(
    "codelists/user-chriswood-example-repeat-medications-atorvastatin.csv",
    column = "code"
)
repeat_2 = codelist_from_csv(
    "codelists/user-chriswood-example-repeat-medications-ramipril.csv",
    column = "code" 
)
quantity_test = codelist_from_csv(
    "codelists/user-chriswood-example-quantity-test-medications.csv",
    column = "code"
)