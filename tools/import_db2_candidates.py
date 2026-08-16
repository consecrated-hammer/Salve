#!/usr/bin/env python3
"""Import unverified Encounter Journal candidates from downloaded wago.tools CSVs."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULES_PATH = ROOT / "data" / "modules.json"
DEBUFFS_PATH = ROOT / "data" / "debuffs.csv"
FIELDS = [
    "module", "instance_id", "spell_id", "spell_name", "dispel_type",
    "source", "source_build", "verified",
]
DISPEL_TYPES = {1: "Magic", 2: "Curse", 3: "Disease", 4: "Poison"}
SOURCE = "wago.tools DB2 JournalEncounterSection+SpellCategories"


def read_csv(path: Path):
    with path.open(newline="", encoding="utf-8") as handle:
        yield from csv.DictReader(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db2-dir", required=True, type=Path)
    parser.add_argument("--build", required=True)
    parser.add_argument(
        "--module", action="append", dest="modules",
        help="module folder to refresh; repeat as needed (default: all)",
    )
    args = parser.parse_args()

    config = json.loads(MODULES_PATH.read_text(encoding="utf-8"))
    all_modules = {module["folder"]: module for module in config["modules"]}
    selected = set(args.modules or all_modules)
    unknown = selected - set(all_modules)
    if unknown:
        parser.error("unknown module(s): " + ", ".join(sorted(unknown)))

    required_tables = {
        name: args.db2_dir / f"{name}.csv"
        for name in (
            "JournalInstance", "JournalEncounter", "JournalEncounterSection",
            "SpellCategories", "SpellName",
        )
    }
    missing = [str(path) for path in required_tables.values() if not path.is_file()]
    if missing:
        parser.error("missing DB2 CSV(s): " + ", ".join(missing))

    target_map_to_module = {}
    for folder in selected:
        for instance in all_modules[folder]["instances"]:
            target_map_to_module[int(instance["id"])] = folder

    journal_to_map = {}
    for row in read_csv(required_tables["JournalInstance"]):
        map_id = int(row["MapID"])
        if map_id in target_map_to_module:
            journal_to_map[row["ID"]] = map_id

    encounter_to_map = {}
    for row in read_csv(required_tables["JournalEncounter"]):
        map_id = journal_to_map.get(row["JournalInstanceID"])
        if map_id:
            encounter_to_map[row["ID"]] = map_id

    categories = {}
    for row in read_csv(required_tables["SpellCategories"]):
        dispel_type = DISPEL_TYPES.get(int(row["DispelType"]))
        if dispel_type:
            categories.setdefault(row["SpellID"], set()).add(dispel_type)

    names = {
        row["ID"]: row["Name_lang"]
        for row in read_csv(required_tables["SpellName"])
    }

    candidates = {}
    for row in read_csv(required_tables["JournalEncounterSection"]):
        map_id = encounter_to_map.get(row["JournalEncounterID"])
        dispel_types = categories.get(row["SpellID"], set())
        if not map_id or len(dispel_types) != 1:
            continue
        dispel_type = next(iter(dispel_types))
        folder = target_map_to_module[map_id]
        spell_id = int(row["SpellID"])
        candidates[(folder, map_id, spell_id)] = {
            "module": folder,
            "instance_id": str(map_id),
            "spell_id": str(spell_id),
            "spell_name": names.get(row["SpellID"], "?"),
            "dispel_type": dispel_type,
            "source": SOURCE,
            "source_build": args.build,
            # Import is candidate generation. A human review promotes the row.
            "verified": "false",
        }

    retained = []
    with DEBUFFS_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row["module"] in selected and row["source"] == SOURCE:
                continue
            retained.append(row)
    retained.extend(candidates.values())

    module_order = {module["folder"]: i for i, module in enumerate(config["modules"])}
    retained.sort(
        key=lambda row: (
            module_order[row["module"]], int(row["instance_id"]), int(row["spell_id"])
        )
    )
    with DEBUFFS_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(retained)

    print(f"imported {len(candidates)} unverified DB2 candidates for {len(selected)} module(s)")
    print("review the CSV, set approved rows verified=true, then regenerate modules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
