"""
Separate the curated 'ancestry' attribute in cBioPortalData into two
distinct columns — 'race' and 'ethnicity' — following NIH Common Data
Element (CDE) standards (see issue #77).

Input  : cBioPortalData/data/curated_ancestry.csv
Outputs: cBioPortalData/data/curated_race.csv
         cBioPortalData/data/curated_ethnicity.csv

Each output file follows the existing curated-file column convention:
  curation_id | original_<attr> | curated_<attr> |
  curated_<attr>_ontology_term_id | curated_<attr>_source

Source-to-attribute mapping
---------------------------
Race    : RACE, RACE_CATEGORY, RACE_CATEGORIZED, PRD_RACE, ANCESTRY_PRIMARY
Ethnicity: ETHNICITY, HISPANIC, INFERRED_ETHNICITY, PRD_HISPANIC,
           ETHNICITY_SELF_IDENTIFY, REPORTED_ETHNICITY
"""

import csv
from pathlib import Path

RACE_SOURCES = {
    "RACE", "RACE_CATEGORY", "RACE_CATEGORIZED", "PRD_RACE", "ANCESTRY_PRIMARY"
}
ETHNICITY_SOURCES = {
    "ETHNICITY", "HISPANIC", "INFERRED_ETHNICITY", "PRD_HISPANIC",
    "ETHNICITY_SELF_IDENTIFY", "REPORTED_ETHNICITY"
}

BASE = Path(__file__).resolve().parents[1]
INPUT = BASE / "data" / "curated_ancestry.csv"
OUT_RACE = BASE / "data" / "curated_race.csv"
OUT_ETHNICITY = BASE / "data" / "curated_ethnicity.csv"


def split_field(value: str) -> list[str]:
    """Split a semicolon-delimited field; return ['NA'] for missing values."""
    if not value or value == "NA":
        return ["NA"]
    return value.split(";")


def zip_parts(sources, originals, curated, term_ids):
    """
    Zip the four parallel semicolon-separated fields.
    If counts differ (data quality issue), pad with 'NA'.
    """
    n = max(len(sources), len(originals), len(curated), len(term_ids))
    def pad(lst):
        return lst + ["NA"] * (n - len(lst))
    return zip(pad(sources), pad(originals), pad(curated), pad(term_ids))


def process():
    race_rows = []
    ethnicity_rows = []

    with open(INPUT, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            cid = row["curation_id"]

            sources  = split_field(row["curated_ancestry_source"])
            originals = split_field(row["original_ancestry"])
            curated  = split_field(row["curated_ancestry"])
            term_ids = split_field(row["curated_ancestry_ontology_term_id"])

            race_orig, race_cur, race_tid, race_src = [], [], [], []
            eth_orig,  eth_cur,  eth_tid,  eth_src  = [], [], [], []

            for src, orig, cur, tid in zip_parts(sources, originals, curated, term_ids):
                src_clean = src.strip()
                if src_clean in RACE_SOURCES:
                    race_orig.append(orig)
                    race_cur.append(cur)
                    race_tid.append(tid)
                    race_src.append(src_clean)
                elif src_clean in ETHNICITY_SOURCES:
                    eth_orig.append(orig)
                    eth_cur.append(cur)
                    eth_tid.append(tid)
                    eth_src.append(src_clean)
                # NA / unknown sources → omitted from both files

            def join(lst):
                vals = [v for v in lst if v and v != "NA"]
                return ";".join(vals) if vals else "NA"

            race_rows.append({
                "curation_id": cid,
                "original_race": join(race_orig),
                "curated_race": join(race_cur),
                "curated_race_ontology_term_id": join(race_tid),
                "curated_race_source": join(race_src),
            })
            ethnicity_rows.append({
                "curation_id": cid,
                "original_ethnicity": join(eth_orig),
                "curated_ethnicity": join(eth_cur),
                "curated_ethnicity_ontology_term_id": join(eth_tid),
                "curated_ethnicity_source": join(eth_src),
            })

    race_cols = [
        "curation_id", "original_race", "curated_race",
        "curated_race_ontology_term_id", "curated_race_source",
    ]
    eth_cols = [
        "curation_id", "original_ethnicity", "curated_ethnicity",
        "curated_ethnicity_ontology_term_id", "curated_ethnicity_source",
    ]

    with open(OUT_RACE, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=race_cols, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(race_rows)

    with open(OUT_ETHNICITY, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=eth_cols, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(ethnicity_rows)

    print(f"Written {len(race_rows)} rows to {OUT_RACE}")
    print(f"Written {len(ethnicity_rows)} rows to {OUT_ETHNICITY}")

    # Quick sanity check
    race_non_na = sum(1 for r in race_rows if r["curated_race"] != "NA")
    eth_non_na  = sum(1 for r in ethnicity_rows if r["curated_ethnicity"] != "NA")
    print(f"  Race    non-NA: {race_non_na}")
    print(f"  Ethnicity non-NA: {eth_non_na}")


if __name__ == "__main__":
    process()
