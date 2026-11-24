# Data dictionaries: frozen

As of 2026-11-24 the two data dictionaries in this folder are **frozen**. They
are kept for the record and for code that still reads them, but they are no
longer updated here.

| File | Successor in [MetaHarmonizerSchemaRegistry](https://github.com/shbrief/MetaHarmonizerSchemaRegistry) |
|---|---|
| `cBioPortal_data_dictionary.csv` | `schema/omicsmlrepo_cbio/omicsmlprepo_cbio_schema.csv` |
| `cMD_data_dictionary.csv` | `schema/curatedmetagenomicdata/cmd_schema.csv` |

## Three versions of each dictionary

1. **Paper version.** The dictionaries used for the OmicsMLRepo paper are at
   release `v1.0.0` of this repository (commit `e5ee74d`), next to the curated
   data deposited on Zenodo
   ([10.5281/zenodo.14110745](https://doi.org/10.5281/zenodo.14110745)). They
   follow an older layout (for example, the cBioPortal file has 98 fields and
   `ontology` / `dynamic_enum` columns). They are not carried into the registry.
2. **Frozen version (this folder).** The last state synced from the Google
   Sheets before the move. It differs from the paper version.
3. **Maintained version (the registry).**
   - `omicsmlprepo_cbio_schema.csv` starts from the frozen cBioPortal file:
     the same 44 fields and values, with lists separated by `|` instead of `;`.
   - `cmd_schema.csv` comes from the newer dictionary in
     `waldronlab/curatedMetagenomicDataCuration`: 71 fields, 55 of them shared
     with the 60 fields here. The registry added the `scope`, `unit.of` and
     `propagate.study.value` columns and the `Healthy` label for `disease`.

   Both follow the registry's schema convention (comma CSV, `|`-separated
   lists, a required `corpus.type`) and are versioned with per-schema tags such
   as `cmd-v0.1.0`. Changes since the freeze are listed in each schema's
   `CHANGELOG.md`.

## What this means

- **To change a dictionary**, open a pull request in the registry. Do not edit
  the files here or the Google Sheets; the sheet sync code in this repository
  (`cBioPortalData/ETL/4_sync_data_dictionary.R`,
  `curatedMetagenomicData/cMD_ETL.qmd`, `curatedMetagenomicData/ETL/99_sync_data_dictionary.R`)
  is commented out.
- **To use a dictionary in new work** (MetaHarmonizer, validation, OmicsMLRepoR),
  read it from a registry tag, for example
  `https://raw.githubusercontent.com/shbrief/MetaHarmonizerSchemaRegistry/cmd-v0.1.0/schema/curatedmetagenomicdata/cmd_schema.csv`.
- **To reproduce the paper**, use release `v1.0.0` of this repository.

How to prepare and check a schema table is described in the registry's
[`docs/target_schema.md`](https://github.com/shbrief/MetaHarmonizerSchemaRegistry/blob/main/docs/target_schema.md).
