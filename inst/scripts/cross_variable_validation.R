# =============================================================================
# Cross-Variable Biomedical Plausibility Validation
# =============================================================================
# This script performs rule-based cross-validation across curated columns
# to detect biomedically implausible combinations of curated values.
#
# Covers:
#   Rule 1:  Sex ↔ Disease
#   Rule 2:  Sex ↔ Body Site
#   Rule 3:  Age ↔ Disease
#   Rule 4:  Body Site ↔ Disease
#   Rule 5:  OncoTree ↔ Body Site (cBioPortal only)
#   Rule 6:  OncoTree ↔ Sex (cBioPortal only)
#   Rule 7:  Disease ↔ Treatment
#   Rule 8:  BMI ↔ BMI Category
#   Rule 9:  Disease ↔ Disease Stage
#   Rule 10: FMT ↔ Disease
#   Rule 11: Specimen Type ↔ Body Site
# =============================================================================

suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(readr)
    library(stringr)
    library(purrr)
})

# =============================================================================
# CONFIGURATION
# =============================================================================

#' Run cross-variable validation for a given database
#'
#' @param database Character. One of "cMD" or "cBioPortal".
#' @param curated_dir Character. Path to the directory containing curated CSVs.
#' @param map_dir Character. Path to the directory containing curation maps.
#' @param output_dir Character. Path to write violation reports.
#' @param verbose Logical. Print progress messages.
#' @return A list of data frames, one per rule, containing flagged violations.
run_cross_validation <- function(database = c("cMD", "cBioPortal"),
                                 curated_dir,
                                 map_dir = NULL,
                                 output_dir = NULL,
                                 verbose = TRUE) {

    database <- match.arg(database)
    violations <- list()

    if (verbose) message("=== Cross-Variable Validation for ", database, " ===\n")

    # -------------------------------------------------------------------------
    # Load curated tables
    # -------------------------------------------------------------------------
    curated_files <- list.files(curated_dir, pattern = "\\.csv$", full.names = TRUE)

    load_curated <- function(pattern) {
        f <- curated_files[grep(pattern, basename(curated_files), ignore.case = TRUE)]
        if (length(f) == 0) return(NULL)
        if (length(f) > 1) {
            if (verbose) message("  Multiple files match '", pattern, "': using ", basename(f[1]))
            f <- f[1]
        }
        if (verbose) message("  Loading: ", basename(f))
        read_csv(f, show_col_types = FALSE)
    }

    # Standardize the join key
    id_col <- "curation_id"

    # Load available curated tables based on database
    if (database == "cMD") {
        ct_sex        <- load_curated("curated_sex")
        ct_disease    <- load_curated("curated_disease\\.csv")
        ct_disease_d  <- load_curated("curated_disease_details\\.csv")
        ct_body_site  <- load_curated("curated_body_site\\.csv")
        ct_age        <- load_curated("curated_age")
        ct_treatment  <- load_curated("curated_treatment")
        ct_bmi        <- load_curated("curated_bmi|curated_BMI")
        ct_stage      <- load_curated("curated_tumor_staging|curated_disease_stage")
        ct_fmt        <- load_curated("curated_fmt|curated_FMT")
        ct_study_cond <- load_curated("curated_study_condition|curated_Study_Condition")
        ct_target     <- load_curated("curated_target_condition")
        ct_specimen   <- NULL
        ct_oncotree   <- NULL
        ct_metastasis <- NULL
    } else {
        ct_sex        <- load_curated("curated_sex")
        ct_disease    <- load_curated("curated_disease|curated_Disease_Disease_Type")
        ct_disease_d  <- NULL
        ct_body_site  <- load_curated("curated_body_site|curated_Body_Site")
        ct_age        <- load_curated("curated_age")
        ct_treatment  <- load_curated("curated_treatment|curated_Treatment")
        ct_stage      <- load_curated("curated_disease_stage|curated_Disease_Stage")
        ct_specimen   <- load_curated("curated_specimen|curated_sample_specimen")
        ct_oncotree   <- load_curated("curated_oncotree")
        ct_metastasis <- load_curated("curated_metastasis|curated_Disease_Metastasis")
        ct_bmi        <- NULL
        ct_fmt        <- NULL
        ct_study_cond <- NULL
        ct_target     <- NULL
    }

    # -------------------------------------------------------------------------
    # Helper: safe left join
    # -------------------------------------------------------------------------
    safe_join <- function(x, y, by = id_col) {
        if (is.null(x) || is.null(y)) return(NULL)
        # Keep only the id and curated columns to avoid collision
        common <- intersect(names(x), names(y))
        common <- setdiff(common, by)
        if (length(common) > 0) {
            y <- y %>% select(-all_of(common))
        }
        left_join(x, y, by = by)
    }

    # -------------------------------------------------------------------------
    # Helper: report
    # -------------------------------------------------------------------------
    report_violations <- function(rule_name, df, key_cols) {
        if (is.null(df) || nrow(df) == 0) {
            if (verbose) message("  [PASS] ", rule_name, ": 0 violations")
            return(tibble())
        }
        if (verbose) message("  [FLAG] ", rule_name, ": ", nrow(df), " violations found")
        df %>%
            mutate(rule = rule_name) %>%
            select(rule, curation_id, all_of(key_cols))
    }

    # Common terms for "healthy" across rules
    healthy_terms <- c("healthy", "control", "healthy control", "no disease",
                       "normal", "unaffected")

    # =========================================================================
    # RULE 1: Sex ↔ Disease
    # =========================================================================
    # Biomedical knowledge: certain diseases are sex-specific
    if (verbose) message("\nRule 1: Sex vs Disease")

    male_only_diseases <- c(
        # Prostate
        "prostate cancer", "prostate adenocarcinoma", "prostate carcinoma",
        "prostatic neoplasm", "benign prostatic hyperplasia",
        "prostate neoplasm", "prostatic intraepithelial neoplasia",
        # Testicular
        "testicular cancer", "testicular germ cell tumor",
        "testicular seminoma", "testicular neoplasm",
        "seminoma", "nonseminomatous germ cell tumor",
        # Male reproductive - other
        "penile cancer", "penile carcinoma",
        "Klinefelter syndrome",
        # EFO / NCIT style
        "malignant prostate neoplasm",
        "carcinoma of prostate"
    )

    female_only_diseases <- c(
        # Ovarian
        "ovarian cancer", "ovarian carcinoma", "ovarian neoplasm",
        "ovarian serous carcinoma", "ovarian epithelial cancer",
        "high-grade serous ovarian cancer", "ovarian clear cell carcinoma",
        "ovarian mucinous carcinoma", "ovarian germ cell tumor",
        "malignant ovarian neoplasm",
        # Cervical
        "cervical cancer", "cervical carcinoma", "cervical neoplasm",
        "cervical squamous cell carcinoma", "cervical intraepithelial neoplasia",
        # Uterine / Endometrial
        "uterine cancer", "uterine carcinoma", "endometrial cancer",
        "endometrial carcinoma", "uterine corpus endometrial carcinoma",
        "endometrioid carcinoma", "uterine sarcoma",
        "uterine carcinosarcoma", "endometriosis",
        # Gestational
        "gestational trophoblastic disease", "gestational choriocarcinoma",
        "hydatidiform mole",
        # Other female-specific
        "vulvar cancer", "vulvar carcinoma", "vaginal cancer",
        "fallopian tube cancer", "fallopian tube carcinoma",
        "Rett syndrome", "Turner syndrome",
        "polycystic ovary syndrome", "PCOS"
    )

    sex_col <- NULL
    disease_col <- NULL

    if (!is.null(ct_sex) && !is.null(ct_disease)) {
        # Identify the curated disease column dynamically
        disease_col <- grep("^curated_disease$|^curated_disease_type$",
                            names(ct_disease), value = TRUE, ignore.case = TRUE)
        if (length(disease_col) == 0) {
            disease_col <- grep("curated.*disease", names(ct_disease),
                                value = TRUE, ignore.case = TRUE)
        }
        sex_col <- grep("^curated_sex$", names(ct_sex),
                         value = TRUE, ignore.case = TRUE)

        if (length(disease_col) > 0 && length(sex_col) > 0) {
            disease_col <- disease_col[1]
            sex_col <- sex_col[1]

            merged_sd <- safe_join(ct_sex, ct_disease)

            if (!is.null(merged_sd)) {
                v1 <- merged_sd %>%
                    filter(
                        (tolower(.data[[sex_col]]) == "female" &
                             tolower(.data[[disease_col]]) %in% tolower(male_only_diseases)) |
                        (tolower(.data[[sex_col]]) == "male" &
                             tolower(.data[[disease_col]]) %in% tolower(female_only_diseases))
                    ) %>%
                    mutate(
                        violation_reason = case_when(
                            tolower(.data[[sex_col]]) == "female" ~
                                paste0("Female with male-specific disease: ", .data[[disease_col]]),
                            tolower(.data[[sex_col]]) == "male" ~
                                paste0("Male with female-specific disease: ", .data[[disease_col]])
                        )
                    )
                violations$rule_01_sex_disease <- report_violations(
                    "Sex_vs_Disease", v1, c(sex_col, disease_col, "violation_reason"))
            }
        }
    }

    # Also check disease_detailed/disease_details for cMD
    if (!is.null(ct_sex) && !is.null(ct_disease_d) && !is.null(sex_col)) {
        dd_col <- grep("curated.*disease.*detail", names(ct_disease_d),
                        value = TRUE, ignore.case = TRUE)
        if (length(dd_col) > 0) {
            dd_col <- dd_col[1]
            merged_sdd <- safe_join(ct_sex, ct_disease_d)
            if (!is.null(merged_sdd)) {
                v1b <- merged_sdd %>%
                    filter(
                        (tolower(.data[[sex_col]]) == "female" &
                             tolower(.data[[dd_col]]) %in% tolower(male_only_diseases)) |
                        (tolower(.data[[sex_col]]) == "male" &
                             tolower(.data[[dd_col]]) %in% tolower(female_only_diseases))
                    )
                if (nrow(v1b) > 0) {
                    violations$rule_01b_sex_disease_detailed <- report_violations(
                        "Sex_vs_Disease_Detailed", v1b, c(sex_col, dd_col))
                }
            }
        }
    }

    # =========================================================================
    # RULE 2: Sex ↔ Body Site
    # =========================================================================
    if (verbose) message("\nRule 2: Sex vs Body Site")

    male_only_sites <- c(
        "prostate", "prostate gland", "testis", "testes",
        "seminal vesicle", "epididymis", "penis",
        "spermatic cord", "scrotum"
    )

    female_only_sites <- c(
        "cervix", "cervix uteri", "uterus", "uterine cervix",
        "ovary", "ovaries", "fallopian tube",
        "vagina", "vulva", "endometrium",
        "myometrium", "placenta", "breast"
        # Note: male breast cancer exists but is extremely rare (~1%);
        # we flag it for manual review rather than exclude
    )

    if (!is.null(ct_sex) && !is.null(ct_body_site) && !is.null(sex_col)) {
        bs_col <- grep("^curated_body_site$|^curated_bodysite$",
                        names(ct_body_site), value = TRUE, ignore.case = TRUE)
        if (length(bs_col) == 0) {
            bs_col <- grep("curated.*body.*site", names(ct_body_site),
                           value = TRUE, ignore.case = TRUE)
        }

        if (length(bs_col) > 0) {
            bs_col <- bs_col[1]
            merged_sb <- safe_join(ct_sex, ct_body_site)

            if (!is.null(merged_sb)) {
                v2 <- merged_sb %>%
                    filter(
                        (tolower(.data[[sex_col]]) == "female" &
                             tolower(.data[[bs_col]]) %in% tolower(male_only_sites)) |
                        (tolower(.data[[sex_col]]) == "male" &
                             tolower(.data[[bs_col]]) %in% tolower(female_only_sites))
                    ) %>%
                    mutate(
                        violation_reason = case_when(
                            tolower(.data[[sex_col]]) == "female" ~
                                paste0("Female sample from male-specific site: ", .data[[bs_col]]),
                            tolower(.data[[sex_col]]) == "male" ~
                                paste0("Male sample from female-specific site: ", .data[[bs_col]])
                        ),
                        # Male breast cancer is rare but real - flag for review, not error
                        severity = if_else(
                            tolower(.data[[sex_col]]) == "male" &
                                tolower(.data[[bs_col]]) == "breast",
                            "WARNING", "ERROR"
                        )
                    )
                violations$rule_02_sex_body_site <- report_violations(
                    "Sex_vs_BodySite", v2,
                    c(sex_col, bs_col, "violation_reason", "severity"))
            }
        }
    }

    # =========================================================================
    # RULE 3: Age ↔ Disease
    # =========================================================================
    if (verbose) message("\nRule 3: Age vs Disease")

    # Diseases that are almost exclusively pediatric (typically < 18 years)
    pediatric_diseases <- c(
        "neuroblastoma", "retinoblastoma", "Wilms tumor",
        "nephroblastoma", "medulloblastoma",
        "rhabdomyosarcoma", "Ewing sarcoma",
        "juvenile myelomonocytic leukemia",
        "infantile spasm", "Kawasaki disease",
        "necrotizing enterocolitis", "neonatal sepsis",
        "bronchopulmonary dysplasia", "croup",
        "cystic fibrosis"  # diagnosed in childhood
    )
    pediatric_age_max <- 30  # generous upper bound to catch clear violations

    # Diseases that are almost exclusively geriatric / late-onset (typically > 40)
    geriatric_diseases <- c(
        "Alzheimer disease", "Alzheimer's disease",
        "age-related macular degeneration",
        "Parkinson disease", "Parkinson's disease",
        "dementia", "vascular dementia", "Lewy body dementia",
        "amyotrophic lateral sclerosis",
        "benign prostatic hyperplasia",
        "chronic obstructive pulmonary disease", "COPD",
        "osteoarthritis", "osteoporosis",
        "presbycusis", "presbyopia",
        "myelodysplastic syndrome"
    )
    geriatric_age_min <- 5  # if someone under 5 has "Alzheimer's", that's implausible

    if (!is.null(ct_age) && !is.null(ct_disease)) {
        age_col <- grep("^curated_age$|^curated_age_years$", names(ct_age),
                         value = TRUE, ignore.case = TRUE)
        if (length(age_col) == 0) {
            age_col <- grep("curated_age", names(ct_age),
                            value = TRUE, ignore.case = TRUE)
            # Prefer numeric age column; exclude group/category columns
            age_col <- age_col[!grepl("group|category|source|ontology|min|max|unit",
                                       age_col, ignore.case = TRUE)]
        }
        d_col <- grep("^curated_disease$|^curated_disease_type$",
                       names(ct_disease), value = TRUE, ignore.case = TRUE)
        if (length(d_col) == 0) {
            d_col <- grep("curated.*disease", names(ct_disease),
                          value = TRUE, ignore.case = TRUE)
        }

        if (length(age_col) > 0 && length(d_col) > 0) {
            age_col <- age_col[1]
            d_col <- d_col[1]
            merged_ad <- safe_join(ct_age, ct_disease)

            if (!is.null(merged_ad)) {
                merged_ad <- merged_ad %>%
                    mutate(.age_numeric = suppressWarnings(as.numeric(.data[[age_col]])))

                v3 <- merged_ad %>%
                    filter(
                        (!is.na(.age_numeric)) & (
                            # Adult/elderly patient with pediatric-exclusive disease
                            (.age_numeric > pediatric_age_max &
                                 tolower(.data[[d_col]]) %in% tolower(pediatric_diseases)) |
                            # Very young patient with geriatric-exclusive disease
                            (.age_numeric < geriatric_age_min &
                                 tolower(.data[[d_col]]) %in% tolower(geriatric_diseases))
                        )
                    ) %>%
                    mutate(
                        violation_reason = case_when(
                            .age_numeric > pediatric_age_max ~
                                paste0("Age ", .age_numeric,
                                       " with pediatric disease: ", .data[[d_col]]),
                            .age_numeric < geriatric_age_min ~
                                paste0("Age ", .age_numeric,
                                       " with late-onset disease: ", .data[[d_col]])
                        )
                    ) %>%
                    select(-.age_numeric)

                violations$rule_03_age_disease <- report_violations(
                    "Age_vs_Disease", v3,
                    c(age_col, d_col, "violation_reason"))
            }
        }
    }

    # =========================================================================
    # RULE 4: Body Site ↔ Disease
    # =========================================================================
    if (verbose) message("\nRule 4: Body Site vs Disease")

    # Map of cancer types to expected body sites. If a cancer sample comes from
    # a body site that is anatomically inconsistent AND there is no metastasis
    # annotation, flag it.
    disease_bodysite_map <- tribble(
        ~disease_pattern,             ~expected_sites,
        "lung cancer|lung adenocarcinoma|lung squamous|non-small cell lung|small cell lung",
                                      c("lung", "bronchus", "respiratory tract"),
        "colorectal cancer|colon cancer|rectal cancer|colon adenocarcinoma",
                                      c("colon", "rectum", "large intestine",
                                        "colorectum", "gastrointestinal tract"),
        "liver cancer|hepatocellular carcinoma|hepatoblastoma",
                                      c("liver", "hepatobiliary system"),
        "kidney cancer|renal cell carcinoma|clear cell renal|renal carcinoma",
                                      c("kidney", "renal pelvis"),
        "pancreatic cancer|pancreatic adenocarcinoma|pancreatic ductal",
                                      c("pancreas"),
        "gastric cancer|stomach cancer|gastric adenocarcinoma",
                                      c("stomach", "gastric"),
        "bladder cancer|urothelial carcinoma|bladder carcinoma",
                                      c("bladder", "urinary bladder"),
        "brain cancer|glioblastoma|glioma|astrocytoma|meningioma",
                                      c("brain", "central nervous system", "cerebrum",
                                        "cerebellum", "frontal lobe", "temporal lobe"),
        "thyroid cancer|papillary thyroid|follicular thyroid|thyroid carcinoma",
                                      c("thyroid", "thyroid gland"),
        "esophageal cancer|esophageal adenocarcinoma|esophageal squamous",
                                      c("esophagus")
    )

    if (!is.null(ct_body_site) && !is.null(ct_disease)) {
        bs_col2 <- grep("^curated_body_site$|^curated_bodysite$",
                         names(ct_body_site), value = TRUE, ignore.case = TRUE)
        if (length(bs_col2) == 0) {
            bs_col2 <- grep("curated.*body.*site", names(ct_body_site),
                            value = TRUE, ignore.case = TRUE)
        }
        d_col2 <- grep("^curated_disease$|^curated_disease_type$",
                        names(ct_disease), value = TRUE, ignore.case = TRUE)
        if (length(d_col2) == 0) {
            d_col2 <- grep("curated.*disease", names(ct_disease),
                           value = TRUE, ignore.case = TRUE)
        }

        if (length(bs_col2) > 0 && length(d_col2) > 0) {
            bs_col2 <- bs_col2[1]
            d_col2 <- d_col2[1]
            merged_bd <- safe_join(ct_body_site, ct_disease)

            # Also try to join metastasis info (cBioPortal) to reduce false positives
            met_col <- character(0)
            if (!is.null(ct_metastasis)) {
                merged_bd <- safe_join(merged_bd, ct_metastasis)
                met_col <- grep("curated.*metast", names(merged_bd),
                                value = TRUE, ignore.case = TRUE)
            }

            if (!is.null(merged_bd)) {
                v4_list <- list()
                for (i in seq_len(nrow(disease_bodysite_map))) {
                    pattern <- disease_bodysite_map$disease_pattern[i]
                    expected <- disease_bodysite_map$expected_sites[[i]]

                    matches <- merged_bd %>%
                        filter(
                            grepl(pattern, .data[[d_col2]], ignore.case = TRUE) &
                            !is.na(.data[[bs_col2]]) &
                            !(tolower(.data[[bs_col2]]) %in% tolower(expected))
                        )

                    # Exclude cases with known metastasis annotation
                    if (length(met_col) > 0 && nrow(matches) > 0) {
                        matches <- matches %>%
                            filter(
                                is.na(.data[[met_col[1]]]) |
                                tolower(.data[[met_col[1]]]) == "no" |
                                .data[[met_col[1]]] == ""
                            )
                    }

                    if (nrow(matches) > 0) {
                        matches <- matches %>%
                            mutate(violation_reason = paste0(
                                "Disease '", .data[[d_col2]],
                                "' expected at [", paste(expected, collapse = ", "),
                                "], found at '", .data[[bs_col2]], "'"))
                        v4_list[[i]] <- matches
                    }
                }

                v4 <- bind_rows(v4_list)
                key_cols_4 <- c(bs_col2, d_col2, "violation_reason")
                if (length(met_col) > 0) key_cols_4 <- c(key_cols_4, met_col[1])
                violations$rule_04_bodysite_disease <- report_violations(
                    "BodySite_vs_Disease", v4, key_cols_4)
            }
        }
    }

    # =========================================================================
    # RULE 5: OncoTree Code ↔ Body Site (cBioPortal only)
    # =========================================================================
    if (verbose) message("\nRule 5: OncoTree vs Body Site")

    # OncoTree tissue-of-origin mapping
    oncotree_tissue_map <- tribble(
        ~oncotree_code, ~expected_tissue,
        "BRCA",         c("breast"),
        "LUAD",         c("lung"),
        "LUSC",         c("lung"),
        "NSCLC",        c("lung"),
        "SCLC",         c("lung"),
        "COAD",         c("colon", "large intestine", "colorectum"),
        "READ",         c("rectum", "colorectum"),
        "CRC",          c("colon", "rectum", "colorectum", "large intestine"),
        "PRAD",         c("prostate", "prostate gland"),
        "BLCA",         c("bladder", "urinary bladder"),
        "LIHC",         c("liver"),
        "HCC",          c("liver"),
        "PAAD",         c("pancreas"),
        "GBM",          c("brain", "central nervous system"),
        "KIRC",         c("kidney"),
        "KIRP",         c("kidney"),
        "THCA",         c("thyroid", "thyroid gland"),
        "OV",           c("ovary", "ovaries"),
        "UCEC",         c("uterus", "endometrium"),
        "UCS",          c("uterus"),
        "CESC",         c("cervix", "cervix uteri"),
        "MEL",          c("skin"),
        "SKCM",         c("skin"),
        "HNSC",         c("head and neck", "oral cavity", "oropharynx",
                          "larynx", "hypopharynx", "nasopharynx"),
        "STAD",         c("stomach"),
        "ESCA",         c("esophagus"),
        "TGCT",         c("testis", "testes")
    )

    if (database == "cBioPortal" && !is.null(ct_oncotree) && !is.null(ct_body_site)) {
        onco_col <- grep("curated.*oncotree|oncotree.*code",
                         names(ct_oncotree), value = TRUE, ignore.case = TRUE)
        bs_col3 <- grep("^curated_body_site$|^curated_bodysite$",
                         names(ct_body_site), value = TRUE, ignore.case = TRUE)
        if (length(bs_col3) == 0) {
            bs_col3 <- grep("curated.*body.*site", names(ct_body_site),
                            value = TRUE, ignore.case = TRUE)
        }

        if (length(onco_col) > 0 && length(bs_col3) > 0) {
            onco_col <- onco_col[1]
            bs_col3 <- bs_col3[1]
            merged_ob <- safe_join(ct_oncotree, ct_body_site)

            if (!is.null(merged_ob)) {
                v5_list <- list()
                for (i in seq_len(nrow(oncotree_tissue_map))) {
                    code <- oncotree_tissue_map$oncotree_code[i]
                    expected <- oncotree_tissue_map$expected_tissue[[i]]

                    matches <- merged_ob %>%
                        filter(
                            toupper(.data[[onco_col]]) == code &
                            !is.na(.data[[bs_col3]]) &
                            !(tolower(.data[[bs_col3]]) %in% tolower(expected))
                        ) %>%
                        mutate(violation_reason = paste0(
                            "OncoTree '", code,
                            "' expects tissue [", paste(expected, collapse = ", "),
                            "], found body site '", .data[[bs_col3]], "'"))

                    if (nrow(matches) > 0) v5_list[[i]] <- matches
                }

                v5 <- bind_rows(v5_list)
                violations$rule_05_oncotree_bodysite <- report_violations(
                    "OncoTree_vs_BodySite", v5,
                    c(onco_col, bs_col3, "violation_reason"))
            }
        }
    } else {
        if (verbose) message("  [SKIP] OncoTree data not applicable for ", database)
    }

    # =========================================================================
    # RULE 6: OncoTree Code ↔ Sex (cBioPortal only)
    # =========================================================================
    if (verbose) message("\nRule 6: OncoTree vs Sex")

    male_only_oncotree <- c("PRAD", "TGCT", "PENIS")
    female_only_oncotree <- c("OV", "UCEC", "UCS", "CESC", "UCA",
                               "OVARY", "VULVA", "VMM")

    if (database == "cBioPortal" && !is.null(ct_oncotree) && !is.null(ct_sex)) {
        onco_col2 <- grep("curated.*oncotree|oncotree.*code",
                          names(ct_oncotree), value = TRUE, ignore.case = TRUE)
        sex_col2 <- grep("^curated_sex$", names(ct_sex),
                          value = TRUE, ignore.case = TRUE)

        if (length(onco_col2) > 0 && length(sex_col2) > 0) {
            onco_col2 <- onco_col2[1]
            sex_col2 <- sex_col2[1]
            merged_os <- safe_join(ct_oncotree, ct_sex)

            if (!is.null(merged_os)) {
                v6 <- merged_os %>%
                    filter(
                        (tolower(.data[[sex_col2]]) == "female" &
                             toupper(.data[[onco_col2]]) %in% male_only_oncotree) |
                        (tolower(.data[[sex_col2]]) == "male" &
                             toupper(.data[[onco_col2]]) %in% female_only_oncotree)
                    ) %>%
                    mutate(
                        violation_reason = case_when(
                            tolower(.data[[sex_col2]]) == "female" ~
                                paste0("Female with male-specific OncoTree code: ",
                                       .data[[onco_col2]]),
                            tolower(.data[[sex_col2]]) == "male" ~
                                paste0("Male with female-specific OncoTree code: ",
                                       .data[[onco_col2]])
                        )
                    )
                violations$rule_06_oncotree_sex <- report_violations(
                    "OncoTree_vs_Sex", v6,
                    c(onco_col2, sex_col2, "violation_reason"))
            }
        }
    } else {
        if (verbose) message("  [SKIP] OncoTree data not applicable for ", database)
    }

    # =========================================================================
    # RULE 7: Disease ↔ Treatment
    # =========================================================================
    if (verbose) message("\nRule 7: Disease vs Treatment")

    # Healthy controls should not have cancer-specific treatments
    cancer_treatments <- c(
        "chemotherapy", "radiation therapy", "radiotherapy",
        "immunotherapy", "targeted therapy", "hormone therapy",
        "anti-PD-1", "anti-PD-L1", "anti-CTLA-4",
        "checkpoint inhibitor", "CAR-T", "car-t cell therapy",
        "brachytherapy", "proton therapy",
        "tyrosine kinase inhibitor", "TKI",
        "EGFR inhibitor", "BRAF inhibitor", "MEK inhibitor",
        "VEGF inhibitor", "mTOR inhibitor",
        "tamoxifen", "letrozole", "anastrozole",
        "cisplatin", "carboplatin", "oxaliplatin",
        "paclitaxel", "docetaxel", "doxorubicin",
        "5-fluorouracil", "gemcitabine", "irinotecan",
        "bevacizumab", "trastuzumab", "rituximab",
        "pembrolizumab", "nivolumab", "ipilimumab",
        "lenalidomide", "thalidomide", "bortezomib"
    )

    if (!is.null(ct_treatment) && !is.null(ct_disease)) {
        treat_col <- grep("^curated_treatment$", names(ct_treatment),
                          value = TRUE, ignore.case = TRUE)
        if (length(treat_col) == 0) {
            treat_col <- grep("curated.*treatment", names(ct_treatment),
                              value = TRUE, ignore.case = TRUE)
        }
        d_col3 <- grep("^curated_disease$|^curated_disease_type$",
                        names(ct_disease), value = TRUE, ignore.case = TRUE)
        if (length(d_col3) == 0) {
            d_col3 <- grep("curated.*disease", names(ct_disease),
                           value = TRUE, ignore.case = TRUE)
        }

        if (length(treat_col) > 0 && length(d_col3) > 0) {
            treat_col <- treat_col[1]
            d_col3 <- d_col3[1]
            merged_dt <- safe_join(ct_disease, ct_treatment)

            if (!is.null(merged_dt)) {
                # Healthy control with cancer treatment
                v7 <- merged_dt %>%
                    filter(
                        tolower(.data[[d_col3]]) %in% tolower(healthy_terms) &
                        !is.na(.data[[treat_col]])
                    ) %>%
                    mutate(
                        has_cancer_treatment = map_lgl(
                            tolower(.data[[treat_col]]),
                            ~ any(str_detect(.x, regex(paste(cancer_treatments,
                                                              collapse = "|"),
                                                        ignore_case = TRUE)))
                        )
                    ) %>%
                    filter(has_cancer_treatment) %>%
                    mutate(violation_reason = paste0(
                        "Healthy control receiving cancer treatment: ",
                        .data[[treat_col]])) %>%
                    select(-has_cancer_treatment)

                violations$rule_07_disease_treatment <- report_violations(
                    "Disease_vs_Treatment", v7,
                    c(d_col3, treat_col, "violation_reason"))
            }
        }
    }

    # =========================================================================
    # RULE 8: BMI ↔ BMI Category
    # =========================================================================
    if (verbose) message("\nRule 8: BMI vs BMI Category")

    # WHO BMI classification:
    #   Underweight: < 18.5
    #   Normal:      18.5 - 24.9
    #   Overweight:  25.0 - 29.9
    #   Obese:       >= 30.0

    if (!is.null(ct_bmi)) {
        bmi_col <- grep("^curated_bmi$|^curated_BMI$", names(ct_bmi),
                         value = TRUE, ignore.case = TRUE)
        bmi_cat_col <- grep("bmi.*cat|bmi.*group|bmi.*class",
                            names(ct_bmi), value = TRUE, ignore.case = TRUE)

        if (length(bmi_col) == 0) {
            bmi_col <- grep("curated.*bmi", names(ct_bmi),
                            value = TRUE, ignore.case = TRUE)
            # Separate numeric BMI from category
            if (length(bmi_col) > 1) {
                for (bc in bmi_col) {
                    vals <- suppressWarnings(as.numeric(ct_bmi[[bc]]))
                    if (sum(!is.na(vals)) > sum(is.na(vals))) {
                        bmi_col <- bc
                        break
                    }
                }
            }
        }

        if (length(bmi_col) > 0 && length(bmi_cat_col) > 0) {
            bmi_col <- bmi_col[1]
            bmi_cat_col <- bmi_cat_col[1]

            v9 <- ct_bmi %>%
                mutate(.bmi_num = suppressWarnings(as.numeric(.data[[bmi_col]]))) %>%
                filter(!is.na(.bmi_num) & !is.na(.data[[bmi_cat_col]])) %>%
                mutate(
                    .expected_category = case_when(
                        .bmi_num < 18.5 ~ "underweight",
                        .bmi_num < 25.0 ~ "normal",
                        .bmi_num < 30.0 ~ "overweight",
                        .bmi_num >= 30.0 ~ "obese",
                        TRUE ~ NA_character_
                    ),
                    .category_match = case_when(
                        .expected_category == "underweight" ~
                            grepl("underweight", .data[[bmi_cat_col]], ignore.case = TRUE),
                        .expected_category == "normal" ~
                            grepl("normal|lean|healthy", .data[[bmi_cat_col]], ignore.case = TRUE),
                        .expected_category == "overweight" ~
                            grepl("overweight", .data[[bmi_cat_col]], ignore.case = TRUE),
                        .expected_category == "obese" ~
                            grepl("obese|obesity", .data[[bmi_cat_col]], ignore.case = TRUE),
                        TRUE ~ NA
                    )
                ) %>%
                filter(!is.na(.category_match) & !.category_match) %>%
                mutate(
                    violation_reason = paste0(
                        "BMI = ", .bmi_num,
                        " (expected '", .expected_category,
                        "') but category is '", .data[[bmi_cat_col]], "'")
                ) %>%
                select(-.bmi_num, -.expected_category, -.category_match)

            violations$rule_08_bmi_category <- report_violations(
                "BMI_vs_Category", v9,
                c(bmi_col, bmi_cat_col, "violation_reason"))
        } else {
            if (verbose) message("  [SKIP] BMI numeric and/or category columns not both found")
        }
    } else {
        if (verbose) message("  [SKIP] BMI data not available for ", database)
    }

    # =========================================================================
    # RULE 9: Disease ↔ Disease Stage
    # =========================================================================
    if (verbose) message("\nRule 9: Disease vs Disease Stage")

    # Staging systems are disease-specific:
    #   - TNM staging: solid tumors (not leukemia/lymphoma)
    #   - Ann Arbor: Hodgkin/Non-Hodgkin lymphoma
    #   - Gleason: prostate cancer only
    #   - FIGO: gynecologic cancers (ovarian, cervical, uterine)
    #   - Clark/Breslow: melanoma only
    #   - Child-Pugh: liver disease (cirrhosis, hepatocellular carcinoma)
    #   - Dukes: colorectal cancer (historical)
    #   - BCLC: hepatocellular carcinoma

    staging_disease_rules <- tribble(
        ~stage_pattern,                   ~valid_disease_pattern,                          ~stage_system,
        "gleason|GS\\s*[0-9]",           "prostate",                                      "Gleason",
        "ann arbor|stage [I-IV]+[AB]?S?", "lymphoma|hodgkin",                              "Ann Arbor",
        "figo|FIGO",                      "ovarian|cervical|uterine|endometrial|vulvar",   "FIGO",
        "clark|breslow",                  "melanoma|skin",                                  "Clark/Breslow",
        "child.?pugh|child.?turcotte",    "liver|hepato|cirrhosis|HCC",                    "Child-Pugh",
        "dukes|duke's",                   "colorectal|colon|rectal",                        "Dukes",
        "bclc|BCLC",                      "hepatocellular|liver|HCC",                       "BCLC"
    )

    if (!is.null(ct_stage) && !is.null(ct_disease)) {
        stage_col <- grep("curated.*stage|curated.*staging|curated.*grade",
                          names(ct_stage), value = TRUE, ignore.case = TRUE)
        # Exclude source/ontology columns
        stage_col <- stage_col[!grepl("source|ontology", stage_col, ignore.case = TRUE)]
        d_col4 <- grep("^curated_disease$|^curated_disease_type$",
                        names(ct_disease), value = TRUE, ignore.case = TRUE)
        if (length(d_col4) == 0) {
            d_col4 <- grep("curated.*disease", names(ct_disease),
                           value = TRUE, ignore.case = TRUE)
        }

        if (length(stage_col) > 0 && length(d_col4) > 0) {
            stage_col <- stage_col[1]
            d_col4 <- d_col4[1]
            merged_sd2 <- safe_join(ct_stage, ct_disease)

            if (!is.null(merged_sd2)) {
                v10_list <- list()
                for (i in seq_len(nrow(staging_disease_rules))) {
                    sp <- staging_disease_rules$stage_pattern[i]
                    dp <- staging_disease_rules$valid_disease_pattern[i]
                    sn <- staging_disease_rules$stage_system[i]

                    matches <- merged_sd2 %>%
                        filter(
                            grepl(sp, .data[[stage_col]], ignore.case = TRUE) &
                            !is.na(.data[[d_col4]]) &
                            !grepl(dp, .data[[d_col4]], ignore.case = TRUE)
                        ) %>%
                        mutate(violation_reason = paste0(
                            sn, " staging ('", .data[[stage_col]],
                            "') used for non-", sn, " disease: '",
                            .data[[d_col4]], "'"))

                    if (nrow(matches) > 0) v10_list[[i]] <- matches
                }

                v10 <- bind_rows(v10_list)

                # Also check: healthy controls should not have disease staging
                v10b <- merged_sd2 %>%
                    filter(
                        tolower(.data[[d_col4]]) %in% tolower(healthy_terms) &
                        !is.na(.data[[stage_col]]) &
                        .data[[stage_col]] != ""
                    ) %>%
                    mutate(violation_reason = paste0(
                        "Healthy control with disease staging: '",
                        .data[[stage_col]], "'"))

                v9_all <- bind_rows(v10, v10b)
                violations$rule_09_disease_stage <- report_violations(
                    "Disease_vs_Stage", v9_all,
                    c(d_col4, stage_col, "violation_reason"))
            }
        }
    }

    # =========================================================================
    # RULE 10: FMT ↔ Disease (cMD only)
    # =========================================================================
    if (verbose) message("\nRule 10: FMT vs Disease")

    # FMT (Fecal Microbiota Transplant) is indicated for specific conditions:
    #   - Primary: recurrent Clostridioides difficile infection (CDI)
    #   - Research: IBD, IBS, metabolic syndrome, etc.
    # A healthy DONOR should be labeled differently from a healthy CONTROL.
    # FMT recipient who is "healthy" is suspicious.

    if (!is.null(ct_fmt) && !is.null(ct_disease)) {
        fmt_col <- grep("curated_fmt_role|curated.*fmt", names(ct_fmt),
                         value = TRUE, ignore.case = TRUE)
        # Exclude source/id columns
        fmt_col <- fmt_col[!grepl("source|_id$", fmt_col, ignore.case = TRUE)]
        d_col5 <- grep("^curated_disease$", names(ct_disease),
                        value = TRUE, ignore.case = TRUE)
        if (length(d_col5) == 0) {
            d_col5 <- grep("curated.*disease", names(ct_disease),
                           value = TRUE, ignore.case = TRUE)
        }

        if (length(fmt_col) > 0 && length(d_col5) > 0) {
            fmt_col <- fmt_col[1]
            d_col5 <- d_col5[1]
            merged_fd <- safe_join(ct_fmt, ct_disease)

            if (!is.null(merged_fd)) {
                # FMT recipient labeled as healthy (not donor)
                v11 <- merged_fd %>%
                    filter(
                        !is.na(.data[[fmt_col]]) &
                        grepl("recipient|yes|TRUE", .data[[fmt_col]],
                              ignore.case = TRUE) &
                        tolower(.data[[d_col5]]) %in%
                            c("healthy", "control", "healthy control", "no disease")
                    ) %>%
                    mutate(violation_reason = paste0(
                        "FMT recipient (", .data[[fmt_col]],
                        ") but disease = '", .data[[d_col5]],
                        "' - should have an indication for FMT"))

                violations$rule_10_fmt_disease <- report_violations(
                    "FMT_vs_Disease", v11,
                    c(fmt_col, d_col5, "violation_reason"))
            }
        }
    } else {
        if (verbose && database == "cBioPortal")
            message("  [SKIP] FMT data not applicable for cBioPortal")
    }

    # =========================================================================
    # RULE 11: Specimen Type ↔ Body Site (cBioPortal only)
    # =========================================================================
    if (verbose) message("\nRule 11: Specimen Type vs Body Site")

    # Certain specimen types imply specific body sites:
    #   - "stool" / "feces" -> gastrointestinal tract
    #   - "blood" / "plasma" / "serum" -> not a solid tissue site
    #   - "urine" -> urinary tract
    #   - "CSF" / "cerebrospinal fluid" -> central nervous system
    #   - "sputum" / "BAL" -> respiratory tract
    #   - "saliva" -> oral cavity

    specimen_site_rules <- tribble(
        ~specimen_pattern,                ~incompatible_sites,                           ~explanation,
        "^stool$|^feces$|^fecal",         c("brain", "lung", "breast", "skin",
                                            "prostate", "kidney", "bladder",
                                            "thyroid", "bone"),                          "Stool specimen from non-GI site",
        "^saliva$|^oral",                  c("lung", "liver", "kidney", "breast",
                                            "prostate", "brain", "colon",
                                            "bladder", "bone"),                          "Saliva specimen from non-oral site",
        "^csf$|cerebrospinal",             c("colon", "breast", "liver", "prostate",
                                            "kidney", "lung", "skin", "bladder"),        "CSF specimen from non-CNS site",
        "^urine$|^urinary",               c("brain", "breast", "lung", "colon",
                                            "liver", "skin", "bone"),                    "Urine specimen from non-urinary site",
        "^sputum$|^bronchoalveolar|^bal$", c("colon", "breast", "liver", "prostate",
                                            "kidney", "brain", "skin", "bladder"),       "Respiratory specimen from non-respiratory site"
    )

    if (!is.null(ct_specimen) && !is.null(ct_body_site)) {
        spec_col <- grep("curated.*specimen|curated.*sample.*type",
                         names(ct_specimen), value = TRUE, ignore.case = TRUE)
        bs_col4 <- grep("^curated_body_site$|^curated_bodysite$",
                         names(ct_body_site), value = TRUE, ignore.case = TRUE)
        if (length(bs_col4) == 0) {
            bs_col4 <- grep("curated.*body.*site", names(ct_body_site),
                            value = TRUE, ignore.case = TRUE)
        }

        if (length(spec_col) > 0 && length(bs_col4) > 0) {
            spec_col <- spec_col[1]
            bs_col4 <- bs_col4[1]
            merged_sb2 <- safe_join(ct_specimen, ct_body_site)

            if (!is.null(merged_sb2)) {
                v12_list <- list()
                for (i in seq_len(nrow(specimen_site_rules))) {
                    sp <- specimen_site_rules$specimen_pattern[i]
                    incomp <- specimen_site_rules$incompatible_sites[[i]]
                    expl <- specimen_site_rules$explanation[i]

                    matches <- merged_sb2 %>%
                        filter(
                            grepl(sp, .data[[spec_col]], ignore.case = TRUE) &
                            !is.na(.data[[bs_col4]]) &
                            tolower(.data[[bs_col4]]) %in% tolower(incomp)
                        ) %>%
                        mutate(violation_reason = paste0(
                            expl, ": specimen='", .data[[spec_col]],
                            "', body_site='", .data[[bs_col4]], "'"))

                    if (nrow(matches) > 0) v12_list[[i]] <- matches
                }

                v12 <- bind_rows(v12_list)
                violations$rule_11_specimen_bodysite <- report_violations(
                    "Specimen_vs_BodySite", v12,
                    c(spec_col, bs_col4, "violation_reason"))
            }
        }
    } else {
        if (verbose && database == "cMD")
            message("  [SKIP] Specimen type data not available for ", database)
    }

    # =========================================================================
    # SUMMARY REPORT
    # =========================================================================
    if (verbose) {
        message("\n", paste(rep("=", 60), collapse = ""))
        message("VALIDATION SUMMARY FOR ", database)
        message(paste(rep("=", 60), collapse = ""))

        total_violations <- 0
        for (rule_name in names(violations)) {
            df <- violations[[rule_name]]
            n <- if (is.null(df)) 0 else nrow(df)
            total_violations <- total_violations + n
            status <- if (n == 0) "PASS" else paste0("FLAG (", n, ")")
            rule_label <- gsub("^rule_\\d+[a-z]?_", "", rule_name)
            message(sprintf("  %-30s : %s", rule_label, status))
        }

        message(paste(rep("-", 60), collapse = ""))
        message(sprintf("  TOTAL VIOLATIONS: %d", total_violations))
        message(paste(rep("=", 60), collapse = ""))
    }

    # =========================================================================
    # EXPORT
    # =========================================================================
    if (!is.null(output_dir)) {
        if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

        # Combined report
        combined <- bind_rows(violations) %>%
            arrange(rule, curation_id)

        output_file <- file.path(output_dir,
                                 paste0(database, "_cross_validation_report.csv"))
        write_csv(combined, output_file)
        if (verbose) message("\nReport written to: ", output_file)

        # Per-rule files
        for (rule_name in names(violations)) {
            df <- violations[[rule_name]]
            if (!is.null(df) && nrow(df) > 0) {
                rule_file <- file.path(output_dir,
                                       paste0(database, "_", rule_name, ".csv"))
                write_csv(df, rule_file)
            }
        }
    }

    invisible(violations)
}


# =============================================================================
# CONVENIENCE WRAPPERS
# =============================================================================

#' Validate curatedMetagenomicData curated tables
#'
#' @param curated_dir Path to the directory containing cMD curated CSVs.
#' @param map_dir Optional path to curation maps.
#' @param output_dir Optional path to write violation report CSVs.
#' @param verbose Print progress messages. Default TRUE.
#' @return A named list of tibbles, one per rule, containing flagged violations.
validate_cMD <- function(curated_dir, map_dir = NULL, output_dir = NULL, verbose = TRUE) {
    run_cross_validation(
        database = "cMD",
        curated_dir = curated_dir,
        map_dir = map_dir,
        output_dir = output_dir,
        verbose = verbose
    )
}

#' Validate cBioPortalData curated tables
#'
#' @param curated_dir Path to the directory containing cBioPortal curated CSVs.
#' @param map_dir Optional path to curation maps.
#' @param output_dir Optional path to write violation report CSVs.
#' @param verbose Print progress messages. Default TRUE.
#' @return A named list of tibbles, one per rule, containing flagged violations.
validate_cBioPortal <- function(curated_dir, map_dir = NULL, output_dir = NULL, verbose = TRUE) {
    run_cross_validation(
        database = "cBioPortal",
        curated_dir = curated_dir,
        map_dir = map_dir,
        output_dir = output_dir,
        verbose = verbose
    )
}


# =============================================================================
# EXAMPLE USAGE
# =============================================================================
if (FALSE) {
    # --- curatedMetagenomicData ---
    cMD_violations <- validate_cMD(
        curated_dir = "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/data",
        output_dir  = "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/validation_reports"
    )

    # --- cBioPortalData ---
    cbio_violations <- validate_cBioPortal(
        curated_dir = "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/data",
        output_dir  = "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/validation_reports"
    )

    # --- Inspect specific violations ---
    cMD_violations$rule_01_sex_disease
    cbio_violations$rule_06_oncotree_sex
}
