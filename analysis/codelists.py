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