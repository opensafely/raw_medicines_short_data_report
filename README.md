# raw_medicines_short_data_report

[View on OpenSAFELY](https://jobs.opensafely.org/repo/https%253A%252F%252Fgithub.com%252Fopensafely%252Fraw_medicines_short_data_report)

Details of the purpose and any published outputs from this project can be found at the link above.

The contents of this repository MUST NOT be considered an accurate or valid representation of the study or its purpose. 
This repository may reflect an incomplete or incorrect analysis with no further ongoing work.
The content has ONLY been made public to support the OpenSAFELY [open science and transparency principles](https://www.opensafely.org/about/#contributing-to-best-practice-around-open-science) and to support the sharing of re-usable code for other subsequent users.
No clinical, policy or safety conclusions must be drawn from the contents of this repository.

# About this project

This repository was created to carry out a short data report (SDR) on the quality of medicines data in the `raw.tpp` schema. The main focuses of the work are on:

- the `quantity` field in the `medications` table
    - a semi-structured field offering information on the quantity of medications prescribed
- the `repeat_medications` table
    - a table providing information on prescriptions which are identified as repeats 
    - this table also contains a `quantity` field which we will compare to that in the `medications` table

# About the OpenSAFELY framework

The OpenSAFELY framework is a Trusted Research Environment (TRE) for electronic
health records research in the NHS, with a focus on public accountability and
research quality.

Read more at [OpenSAFELY.org](https://opensafely.org).

# Licences
As standard, research projects have a MIT license. 
