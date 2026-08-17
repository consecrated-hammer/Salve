# Salve sound data

`modules.json` is the authoritative expansion/season/instance manifest and
links each module to the Blizzard season announcement used to select instances.
`debuffs.csv` is the reviewed dispel catalogue and `movement.csv` is the
reviewed root/snare catalogue. `tools/generate_data_modules.py` validates both
and generates the load-on-demand `Salve_Data_*` addon folders.

`verified=true` means the row and its dispel school were checked against the
named source. It does **not** claim complete instance coverage. The current DB2
source is an Encounter Journal baseline and does not enumerate ordinary dungeon
trash. An instance with zero rows is kept in the manifest so Salve can report
that its module loaded but no verified candidates are available.

For Midnight Season 2 Mythic+, the catalogue also uses the dispel-school spell
metadata in Mythic Dungeon Tools commit `4b8b0b7`. This covers trash and other
enemy spells omitted by the Encounter Journal. Those IDs were checked against
the 12.1.0 DB2 spell categories where available; live `/salve learn` captures
remain the preferred confirmation for the exact aura IDs that reach players.

To regenerate after editing either source file:

```sh
python3 tools/generate_data_modules.py
python3 tools/generate_data_modules.py --check
```

New DB2 candidates should enter the CSV as `verified=false`, then be reviewed
before activation. In-game `/salve learn on` discoveries include instance and
dispel-school provenance and can be promoted here after verification.
Automatically captured roots and snares belong in `movement.csv`; they are
registered independently of the alert-sound setting.

For a new client build, download `JournalInstance`, `JournalEncounter`,
`JournalEncounterSection`, `SpellCategories` and `SpellName` CSVs from
wago.tools into one directory, update `modules.json`, then run:

```sh
python3 tools/import_db2_candidates.py \
  --db2-dir /path/to/csvs --build 12.1.0.69299 \
  --module Salve_Data_Midnight_S2
```

The importer deliberately marks every generated row unverified. Review the
diff and promote approved rows before running the module generator.
