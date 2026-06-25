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