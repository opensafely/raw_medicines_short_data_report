# Using dummy tables with this repo

To first get the neccessary dummy tables for running this project locally we ran the code `opensafely exec ehrql:v1 create-dummy-tables analysis/dataset_definition.py dummy_tables`.

Subsequently, we used the `modify_dummy_tables.py` script to make some modifications to the quantity fields in both the `medications_raw` table and `repeat_medications_raw` table. 

