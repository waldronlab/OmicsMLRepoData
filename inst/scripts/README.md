# Cross-Variable Biomedical Plausibility Validation

## Overview

`cross_variable_validation.R` performs rule-based cross-validation across
curated metadata columns to detect biomedically implausible combinations.
While individual curation workflows validate values *within* a single column
(e.g., ontology term lookup, completeness), this script validates that
combinations of values *across* columns are consistent with biomedical
knowledge.

**Example violation:** A sample annotated as `curated_sex = "female"` with
`curated_disease = "prostate cancer"` is anatomically impossible and
indicates a curation or data-entry error.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              run_cross_validation()                      │
│  Main entry point, parameterized by database type        │
├──────────────┬──────────────────────────────────────┬────┤
│  database    │  curated_dir    output_dir   verbose │    │
│  "cMD" or    │  (path to       (optional    (print  │    │
│  "cBioPortal"│   curated CSVs)  CSV output)  msgs)  │    │
└──────┬───────┴──────────────────────────────────────┘    │
       │                                                   │
       ▼                                                   │
┌──────────────────────────────────────────────────────────┤
│  1. Load curated tables                                  │
│     - Dynamic file discovery via pattern matching        │
│     - Database-specific table selection                  │
│                                                          │
│  2. Execute Rules 1-11                                   │
│     - Each rule joins relevant tables on curation_id     │
│     - Applies biomedical knowledge constraints           │
│     - Flags violations with human-readable reasons       │
│                                                          │
│  3. Summary report (console)                             │
│     - Per-rule PASS/FLAG counts                          │
│     - Total violation count                              │
│                                                          │
│  4. Export (optional)                                     │
│     - Combined CSV: {database}_cross_validation_report   │
│     - Per-rule CSVs: {database}_rule_NN_*.csv            │
└──────────────────────────────────────────────────────────┘
```

### Convenience wrappers

| Function              | Description                          |
|-----------------------|--------------------------------------|
| `validate_cMD()`      | Runs validation for curatedMetagenomicData |
| `validate_cBioPortal()` | Runs validation for cBioPortalData  |

### Key design decisions

- **Dynamic column detection.** Column names are matched via `grep` patterns
  rather than hardcoded strings, accommodating naming variations between
  databases (e.g., `curated_disease` vs. `curated_disease_type`).
- **Graceful degradation.** If a curated table is missing, the corresponding
  rule is skipped with a `[SKIP]` message rather than raising an error.
- **Severity levels.** `ERROR` for biologically impossible combinations;
  `WARNING` for implausible-but-possible cases (e.g., male breast cancer).
- **Metastasis awareness (Rule 4).** When metastasis annotation is available
  (cBioPortal), body-site/disease mismatches are excluded for metastatic
  samples to avoid false positives.
- **Extensible knowledge bases.** Disease lists, body-site lists, staging
  rules, and OncoTree mappings are defined as vectors/tibbles that can be
  expanded without modifying the validation logic.

### Join strategy

All curated tables share a `curation_id` column:

| Database    | Format                           |
|-------------|----------------------------------|
| cMD         | `study_name:sample_id`           |
| cBioPortal  | `studyId:patientId:sampleId`     |

Rules join exactly two (or occasionally three) curated tables at a time via
`left_join` on `curation_id`, keeping the operation lightweight and
debuggable.

## Rules

### Rule 1 — Sex vs. Disease

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_sex` + `curated_disease` |

Flags samples where a sex-specific disease is annotated for the wrong sex.

| Sex    | Diseases that should NOT appear                                    |
|--------|--------------------------------------------------------------------|
| Female | Prostate cancer/adenocarcinoma, testicular cancer/seminoma, penile cancer, Klinefelter syndrome |
| Male   | Ovarian/cervical/uterine/endometrial/vulvar/vaginal/fallopian tube cancer, endometriosis, gestational trophoblastic disease, Turner syndrome, PCOS |

For cMD, `curated_disease_detailed` is also checked (Rule 1b).

### Rule 2 — Sex vs. Body Site

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR (most); WARNING for male + breast |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_sex` + `curated_body_site` |

Flags samples where the body site is anatomically exclusive to the opposite
sex.

- **Male-only sites:** prostate, testis, seminal vesicle, epididymis, penis,
  spermatic cord, scrotum
- **Female-only sites:** cervix, uterus, ovary, fallopian tube, vagina,
  vulva, endometrium, myometrium, placenta, breast

Male breast cancer exists (~1% of breast cancers) so male + breast is
flagged as `WARNING` for manual review rather than `ERROR`.

### Rule 3 — Age vs. Disease

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_age` + `curated_disease` |

Flags age/disease combinations that are epidemiologically implausible.

| Check | Threshold | Example diseases |
|-------|-----------|------------------|
| Adult with pediatric disease | age > 30 | Neuroblastoma, retinoblastoma, Wilms tumor, Ewing sarcoma, Kawasaki disease |
| Child with geriatric disease | age < 5 | Alzheimer's, Parkinson's, COPD, osteoarthritis, myelodysplastic syndrome |

Thresholds are deliberately generous to minimize false positives (e.g.,
age 30 for pediatric rather than 18).

### Rule 4 — Body Site vs. Disease

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_body_site` + `curated_disease` (+ `curated_metastasis` if available) |

Flags samples where a site-specific cancer is annotated at an anatomically
inconsistent body site, unless the sample has a metastasis annotation.

Covers 10 cancer-site pairs: lung, colorectal, liver, kidney, pancreatic,
gastric, bladder, brain, thyroid, and esophageal cancers.

### Rule 5 — OncoTree Code vs. Body Site

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cBioPortal only |
| **Tables joined** | `curated_oncotree` + `curated_body_site` |

Validates that the OncoTree code's tissue of origin matches the annotated
body site. Covers 27 OncoTree codes (BRCA, LUAD, LUSC, COAD, PRAD, GBM,
etc.) mapped to their expected anatomical sites.

### Rule 6 — OncoTree Code vs. Sex

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cBioPortal only |
| **Tables joined** | `curated_oncotree` + `curated_sex` |

Flags sex-specific OncoTree codes assigned to the wrong sex.

| Sex    | Flagged OncoTree codes |
|--------|------------------------|
| Female | PRAD, TGCT, PENIS |
| Male   | OV, UCEC, UCS, CESC, UCA, OVARY, VULVA, VMM |

### Rule 7 — Disease vs. Treatment

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_disease` + `curated_treatment` |

Flags healthy controls receiving cancer-specific treatments (chemotherapy,
immunotherapy, targeted therapy, specific drug names like cisplatin,
pembrolizumab, etc.). The cancer treatment list includes 40+ terms covering
drug classes and individual agents.

### Rule 8 — BMI vs. BMI Category

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD |
| **Tables joined** | `curated_bmi` (numeric + category within same table) |

Validates that the BMI category is consistent with the numeric BMI value
per WHO classification:

| Category    | BMI range     |
|-------------|---------------|
| Underweight | < 18.5        |
| Normal      | 18.5 – 24.9   |
| Overweight  | 25.0 – 29.9   |
| Obese       | ≥ 30.0        |

### Rule 9 — Disease vs. Disease Stage

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD, cBioPortal |
| **Tables joined** | `curated_disease_stage` + `curated_disease` |

Two sub-checks:

1. **Staging system mismatch.** Disease-specific staging systems applied to
   the wrong disease type:

   | Staging system   | Valid only for                                    |
   |------------------|---------------------------------------------------|
   | Gleason          | Prostate cancer                                   |
   | Ann Arbor        | Hodgkin/Non-Hodgkin lymphoma                      |
   | FIGO             | Ovarian, cervical, uterine, endometrial, vulvar   |
   | Clark/Breslow    | Melanoma                                          |
   | Child-Pugh       | Liver disease, hepatocellular carcinoma            |
   | Dukes            | Colorectal cancer                                 |
   | BCLC             | Hepatocellular carcinoma                          |

2. **Healthy control with staging.** A sample annotated as healthy/control
   should not have any disease staging information.

### Rule 10 — FMT vs. Disease

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cMD only |
| **Tables joined** | `curated_fmt` + `curated_disease` |

Flags FMT (Fecal Microbiota Transplant) recipients whose disease is
annotated as "healthy" or "control." An FMT recipient should have a
clinical indication (typically recurrent *C. difficile* infection, IBD, or
similar). FMT *donors* are expected to be healthy and are not flagged.

### Rule 11 — Specimen Type vs. Body Site

| Property       | Value |
|----------------|-------|
| **Severity**   | ERROR |
| **Databases**  | cBioPortal |
| **Tables joined** | `curated_specimen` + `curated_body_site` |

Flags specimen/body-site combinations that are anatomically inconsistent:

| Specimen type | Incompatible body sites |
|---------------|-------------------------|
| Stool/feces   | brain, lung, breast, skin, prostate, kidney, bladder, thyroid, bone |
| Saliva/oral   | lung, liver, kidney, breast, prostate, brain, colon, bladder, bone |
| CSF           | colon, breast, liver, prostate, kidney, lung, skin, bladder |
| Urine         | brain, breast, lung, colon, liver, skin, bone |
| Sputum/BAL    | colon, breast, liver, prostate, kidney, brain, skin, bladder |

## Usage

```r
source("inst/scripts/cross_variable_validation.R")

# curatedMetagenomicData
cMD_violations <- validate_cMD(
    curated_dir = "curatedMetagenomicData/data",
    output_dir  = "curatedMetagenomicData/validation_reports"
)

# cBioPortalData
cbio_violations <- validate_cBioPortal(
    curated_dir = "cBioPortalData/data",
    output_dir  = "cBioPortalData/validation_reports"
)

# Inspect specific rule results
cMD_violations$rule_01_sex_disease
cbio_violations$rule_05_oncotree_bodysite
```

## Output

When `output_dir` is provided, the script writes:

| File | Content |
|------|---------|
| `{database}_cross_validation_report.csv` | All violations combined, sorted by rule and `curation_id` |
| `{database}_rule_01_sex_disease.csv` | Rule 1 violations only |
| `{database}_rule_02_sex_body_site.csv` | Rule 2 violations only |
| … | One file per rule with ≥1 violation |

Each violation row contains:

| Column | Description |
|--------|-------------|
| `rule` | Rule name (e.g., `Sex_vs_Disease`) |
| `curation_id` | Unique sample identifier |
| curated columns | The conflicting curated values |
| `violation_reason` | Human-readable explanation |
| `severity` | `ERROR` or `WARNING` (where applicable) |

## Dependencies

- `dplyr`, `tidyr`, `readr`, `stringr`, `purrr` (tidyverse)
