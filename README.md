# SCIMaP maps

Code to generate the maps for the Science \& Community Impacts Mapping Project website ([https://scienceimpacts.org]([url](https://scienceimpacts.org/))).

The scripts are used to calculate the following for both the NIH and NSF:

* baseline level of funding, economic impact, and jobs averaged across FY20-FY24
* raw loss, economic loss, and job loss due to grant terminations
* raw loss, economic loss, and job loss due to the proposed budget cuts for FY27.

In addition, the IDC\_map script calculates the loss projected from the proposed 15% cap on indirect costs. All scripts have outputs grouped at the city, county, congressional district, and state levels.

All output files are stored in the output folder.

## Project Structure
```
├── data/                                      # Raw data
│   ├── CD_pop2024.csv
│   ├── cbsa2fipsxw_2023.csv
│   ├── city_pop_2024.csv
│   ├── county_pop.csv
│   ├── geoid_dictionary.csv
│   ├── geoid_dictionary_july4.csv
│   ├── geoid_pop.csv
│   ├── nsf_budg_table.csv
│   ├── nsf_terminations.csv
│   ├── org_names_corrected.csv
│   ├── orgs.csv
│   ├── state-multiplier-urm.csv
│   ├── state_and_county_fips_master.csv
│   ├── state_mult_2026.csv
│   ├── state_pop.csv
│   ├── states.csv
│   ├── terminations_clean.csv
│   ├── tract_dictionary.csv
│   └── us_representatives_119th_congress.csv
├── nsf_data/                                  # Raw data for NSF
│   ├── NSF_addresses_US_tract_county_cong119.csv
│   └── nsf_grants.csv
├── IDC_map.Rmd                                # Generate figures and tables
├── NIH_baseline.Rmd                           # Baseline funding NIH
├── NIH_budget_fy27.Rmd                        # FY27 budget impact NIH
├── NIH_terminations.Rmd                       # Grant terminations NIH
├── NSF_baseline.Rmd                           # Baseline funding NSF
├── NSF_baseline_fy27.Rmd                      # Baseline funding NSF
├── NSF_budget_fy27.Rmd                        # FY27 budget impact NSF
├── NSF_terminations.Rmd                       # Grant terminations NSF
└── README.md
```
## Data

### \\data files

budg\_table: annual budget for NSF by office/directorate and year

CD\_pop2024.csv: population size for each district

cbsa2fipsxw\_2023.csv: dictionary mapping counties (CountyFIPS) to metro- and micropolitan areas (CBSA\_FIPS)

city\_pop\_2024.csv: population size for CBSAs

county\_pop.csv: population size for counties

geoid\_dictionary\_july4.csv: dictionary mapping congressional districts by GEOID code to name with additional information about each district

org\_names\_corrected.csv: helper file to clean organization names from Grant Witness

orgs.csv: dictionary of organization name, city, and state

state-multiplier-urm.csv: contains economic and job loss multipliers for FY2025 (used for IDC calculation), calculated by United for Medical Research

state\_and\_county\_fips\_master: dictionary that maps county FIPS codes to county names and states

state\_mult\_2026.csv: contains economic and job loss multipliers for FY2026 (used for all NIH calculations except for IDC calculation), calculated by United for Medical Research

state\_pop.csv: the population size of states

states.csv: dictionary of state names

tract\_dictionary.csv: maps NIH lat/lon coordinates to census tract and county FIPS

us\_representatives\_119th\_congress.csv: dictionary with information about Congressional Districts

### \\nsf\_data files:

NSF\_addresses\_US\_tract\_county\_cong119.csv: maps NSF grants to census tracts

nsf\_grants.csv: formatted dataframe of historical NSF grants

### from OSF (accessed remotely and not in repository):

home\_119\_workTR: commuter flows with Congressional District Cong\_ORIGIN and census tract Cong\_DESTINATION

NIH\_raw: large file of active NIH grants for fiscal year 2024 downloaded from RePORTER


