### This script imports cBioPortal curation maps created in Google Sheet


# Import curation maps from Google Sheet ----
## Bodysite
url <- "https://docs.google.com/spreadsheets/d/1DKuoIt2xgSnkdkhYWffubmwrXLA7V7Z7pcqgb1TUXxo/edit?usp=sharing"
ss <- googledrive::as_id(url)
bodysite_map <- googlesheets4::read_sheet(ss = ss, sheet = "cBioPortal_bodysite_map")

## Diseases
url <- "https://docs.google.com/spreadsheets/d/1IgrVEdgCZdvBmWrER21A57lSkfDjdRdV3RbK_yoqMl4/edit?usp=sharing"
ss <- googledrive::as_id(url)
disease_map <- googlesheets4::read_sheet(ss = ss, sheet = "cBioPortal_diseases_map")

## Country
## We curated to high-level, i.e., country. (e.g., 'PA' to 'United States')
url <- "https://docs.google.com/spreadsheets/d/1OqLt5gBQswFz6HD0T5zYornMmdP_rcplfe5dgyGyN98/edit?usp=sharing"
ss <- googledrive::as_id(url)
country_map <- googlesheets4::read_sheet(ss = ss, sheet = "cBioPortal_location_map")

## Population_ancestry
url <- "https://docs.google.com/spreadsheets/d/1Mq1uXYtOElx324n7yyP_jKLdkSDpnQv5yx6HHt0CKx4/edit?usp=sharing"
ss <- googledrive::as_id(url)
population_map <- googlesheets4::read_sheet(ss = ss, sheet = "cBioPortal_population_ancestry_map")

## Sex
url <- "https://docs.google.com/spreadsheets/d/1O_W_QDUZKWRNy4GbDQp3RCObb0FCBSVZPrkQA-0zdPk/edit?usp=sharing"
ss <- googledrive::as_id(url)
sex_map <- googlesheets4::read_sheet(ss = ss, sheet = "cBioPortal_sex_map")

# ## Study_design
# url <- "https://docs.google.com/spreadsheets/d/1u7-r_a2hhbgBbZGOWmvJHIeRetol8lBKdOVNCGP83pA/edit?usp=sharing"
# ss <- googledrive::as_id(url)
# study_design_map <- googlesheets4::read_sheet(ss = ss, sheet = "study_design_map")


## Treatment_*
url <- "https://docs.google.com/spreadsheets/d/1E6Xr1Aa8gxu6MgujOQ7kxarlZ7O8-Iy8XsCp7-0BHXY/edit?usp=sharing"
ss <- googledrive::as_id(url)

treatment_name_map <- googlesheets4::read_sheet(ss = ss, sheet = "treatment_name_map")
treatment_type_map <- googlesheets4::read_sheet(ss = ss, sheet = "treatment_type_map")
treatment_unit_map <- googlesheets4::read_sheet(ss = ss, sheet = "treatment_amount_time_map")
treatment_case_map <- googlesheets4::read_sheet(ss = ss, sheet = "treatment_case_map")


