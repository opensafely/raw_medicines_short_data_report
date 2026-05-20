import pandas as pd
import numpy as np

meds = pd.read_csv('dummy_tables/medications_raw.csv')

quantity = (
    pd.read_csv('local_codelists/quantity.csv')['quantity']
    .dropna()
    .tolist()
)

meds['quantity'] = np.random.choice(quantity, size=len(meds), replace=True)

# columns that should remain integer-like
int_columns = [
    'consultation_id',
    'medication_status',
    'repeat_medication_id',
]

for col in int_columns:
    meds[col] = pd.to_numeric(meds[col], errors='coerce').astype('Int64')

# write to a new file
meds.to_csv('dummy_tables/medications_raw.csv', index=False)

#same for repeat meds
rep_meds = pd.read_csv('dummy_tables/repeat_medications_raw.csv')

quantity = (
    pd.read_csv('local_codelists/quantity.csv')['quantity']
    .dropna()
    .tolist()
)

rep_meds['quantity'] = np.random.choice(quantity, size=len(rep_meds), replace=True)

# columns that should remain integer-like
int_columns = [
    'consultation_id',
    'medication_status',
    'repeat_medication_id',
]

for col in int_columns:
    rep_meds[col] = pd.to_numeric(rep_meds[col], errors='coerce').astype('Int64')

# write to a new file
rep_meds.to_csv('dummy_tables/repeat_medications_raw.csv', index=False)
