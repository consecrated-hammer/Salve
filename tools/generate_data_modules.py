#!/usr/bin/env python3
"""Validate Salve's catalogue and generate its load-on-demand data addons."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULES_PATH = ROOT / "data" / "modules.json"
DEBUFFS_PATH = ROOT / "data" / "debuffs.csv"
MOVEMENT_PATH = ROOT / "data" / "movement.csv"
VALID_DISPELS = {"Magic", "Curse", "Disease", "Poison"}
FOLDER_RE = re.compile(r"^Salve_Data_[A-Za-z0-9_]+$")


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def load_sources() -> tuple[dict, dict[str, list[dict]], dict[str, list[dict]], dict[str, dict]]:
    config = json.loads(MODULES_PATH.read_text(encoding="utf-8"))
    main_toc = (ROOT / "Salve.toc").read_text(encoding="utf-8")
    version_match = re.search(r"^## Version:\s*(\S+)\s*$", main_toc, re.MULTILINE)
    interface_match = re.search(r"^## Interface:\s*(\d+)\s*$", main_toc, re.MULTILINE)
    if not version_match or version_match.group(1) != config.get("version"):
        raise ValueError("data version does not match Salve.toc")
    if not interface_match or int(interface_match.group(1)) != int(config.get("interface", 0)):
        raise ValueError("data interface does not match Salve.toc")

    pkgmeta = (ROOT / ".pkgmeta").read_text(encoding="utf-8")
    modules: dict[str, dict] = {}
    instance_owner: dict[tuple[int, int], str] = {}

    for module in config.get("modules", []):
        folder = module.get("folder", "")
        if not FOLDER_RE.fullmatch(folder) or folder in modules:
            raise ValueError(f"invalid or duplicate module folder: {folder!r}")
        if not str(module.get("manifest_source", "")).startswith("https://"):
            raise ValueError(f"authoritative manifest source is required for {folder}")
        mapping = f"Salve/{folder}: {folder}"
        if mapping not in pkgmeta:
            raise ValueError(f".pkgmeta does not package {folder}")
        module["priority"] = int(module["priority"])
        instance_ids: set[int] = set()
        for instance in module.get("instances", []):
            instance["id"] = int(instance["id"])
            if instance["id"] <= 0 or instance["id"] in instance_ids:
                raise ValueError(f"invalid or duplicate instance in {folder}: {instance['id']}")
            instance_ids.add(instance["id"])
            priority_key = (instance["id"], module["priority"])
            if priority_key in instance_owner:
                raise ValueError(
                    f"instance {instance['id']} has equal-priority owners: "
                    f"{instance_owner[priority_key]} and {folder}"
                )
            instance_owner[priority_key] = folder
        modules[folder] = module

    records: dict[str, list[dict]] = defaultdict(list)
    movement: dict[str, list[dict]] = defaultdict(list)
    seen: set[tuple[str, int, int]] = set()
    with DEBUFFS_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {
            "module", "instance_id", "spell_id", "spell_name", "dispel_type",
            "source", "source_build", "verified",
        }
        if set(reader.fieldnames or []) != required:
            raise ValueError("debuffs.csv headers do not match the required schema")
        for line_number, row in enumerate(reader, start=2):
            folder = row["module"]
            if folder not in modules:
                raise ValueError(f"line {line_number}: unknown module {folder}")
            row["instance_id"] = int(row["instance_id"])
            row["spell_id"] = int(row["spell_id"])
            valid_instances = {item["id"] for item in modules[folder]["instances"]}
            if row["instance_id"] not in valid_instances:
                raise ValueError(
                    f"line {line_number}: instance {row['instance_id']} is not in {folder}"
                )
            if row["spell_id"] <= 0 or row["dispel_type"] not in VALID_DISPELS:
                raise ValueError(f"line {line_number}: invalid spell ID or dispel type")
            if row["verified"] not in {"true", "false"}:
                raise ValueError(f"line {line_number}: verified must be true or false")
            if not row["source"] or not row["source_build"]:
                raise ValueError(f"line {line_number}: provenance is required")
            key = (folder, row["instance_id"], row["spell_id"])
            if key in seen:
                raise ValueError(f"line {line_number}: duplicate spell record {key}")
            seen.add(key)
            records[folder].append(row)

    movement_seen: set[tuple[str, int, int]] = set()
    with MOVEMENT_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {"module", "instance_id", "spell_id", "spell_name", "source", "source_build", "verified"}
        if set(reader.fieldnames or []) != required:
            raise ValueError("movement.csv headers do not match the required schema")
        for line_number, row in enumerate(reader, start=2):
            folder = row["module"]
            if folder not in modules:
                raise ValueError(f"line {line_number}: unknown module {folder}")
            row["instance_id"] = int(row["instance_id"])
            row["spell_id"] = int(row["spell_id"])
            valid_instances = {item["id"] for item in modules[folder]["instances"]}
            if row["instance_id"] not in valid_instances:
                raise ValueError(f"line {line_number}: instance {row['instance_id']} is not in {folder}")
            if row["spell_id"] <= 0 or row["verified"] not in {"true", "false"}:
                raise ValueError(f"line {line_number}: invalid spell ID or verified value")
            if not row["source"] or not row["source_build"]:
                raise ValueError(f"line {line_number}: provenance is required")
            key = (folder, row["instance_id"], row["spell_id"])
            if key in movement_seen:
                raise ValueError(f"line {line_number}: duplicate movement record {key}")
            movement_seen.add(key)
            movement[folder].append(row)

    return config, records, movement, modules


def render_toc(config: dict, module: dict) -> str:
    ids = ", ".join(str(item["id"]) for item in module["instances"])
    return f"""## Interface: {config['interface']}
## Title: Salve |cff66ddaaData: {module['title']}|r
## Notes: Load-on-demand dispellable-debuff data for Salve.
## Author: consecrated-hammer
## Version: {config['version']}
## LoadOnDemand: 1
## RequiredDeps: Salve
## X-License: GPL-3.0
## IconTexture: Interface\\AddOns\\Salve\\Textures\\Salve
## X-Salve-LoadOn-InstanceID: {ids}
## X-Salve-Data-Priority: {module['priority']}

# Generated by tools/generate_data_modules.py. Edit data/, not this folder.
Data.lua
"""


def render_data(module: dict, records: list[dict], movement: list[dict]) -> str:
    by_instance: dict[int, list[dict]] = defaultdict(list)
    for record in records:
        by_instance[record["instance_id"]].append(record)
    movement_ids = sorted({record["spell_id"] for record in movement if record["verified"] == "true"})

    lines = [
        "-- Generated by tools/generate_data_modules.py. Edit data/, not this file.",
        "if not Salve then return end",
        "",
    ]
    if movement_ids:
        lines.extend([
            "if Salve.Escape and Salve.Escape.RegisterMovement then",
            f"    Salve.Escape:RegisterMovement({lua_string(module['folder'])}, {{ {', '.join(map(str, movement_ids))} }})",
            "end",
            "",
        ])
    lines.extend([
        "if not Salve.Sound or not Salve.Sound.RegisterData then return end",
        "",
        f"Salve.Sound:RegisterData({lua_string(module['folder'])}, {{",
    ])
    for instance in sorted(module["instances"], key=lambda item: item["id"]):
        lines.extend(
            [
                f"    [{instance['id']}] = {{",
                f"        name = {lua_string(instance['name'])},",
                f"        season = {lua_string(module['title'])},",
                f"        seasonSource = {lua_string(module['manifest_source'])},",
                '        coverage = "Encounter Journal baseline; trash may be absent",',
                "        debuffs = {",
            ]
        )
        for record in sorted(by_instance[instance["id"]], key=lambda item: item["spell_id"]):
            lines.extend(
                [
                    "            {",
                    f"                spellID = {record['spell_id']},",
                    f"                dispelType = {lua_string(record['dispel_type'])},",
                    f"                name = {lua_string(record['spell_name'])},",
                    f"                verified = {record['verified']},",
                    "                provenance = {",
                    f"                    source = {lua_string(record['source'])},",
                    f"                    build = {lua_string(record['source_build'])},",
                    "                },",
                    "            },",
                ]
            )
        lines.extend(["        },", "    },"])
    lines.extend(["})", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated files differ")
    args = parser.parse_args()

    try:
        config, records, movement, modules = load_sources()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"data validation failed: {exc}", file=sys.stderr)
        return 1

    changed = []
    for folder, module in modules.items():
        outputs = {
            ROOT / folder / f"{folder}.toc": render_toc(config, module),
            ROOT / folder / "Data.lua": render_data(module, records[folder], movement[folder]),
        }
        for path, expected in outputs.items():
            current = path.read_text(encoding="utf-8") if path.exists() else None
            if current != expected:
                changed.append(path.relative_to(ROOT))
                if not args.check:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(expected, encoding="utf-8", newline="\n")

    if args.check and changed:
        for path in changed:
            print(f"generated file is stale: {path}", file=sys.stderr)
        return 1
    if not args.check:
        print(f"generated {len(modules)} data modules from {sum(map(len, records.values()))} dispel and {sum(map(len, movement.values()))} movement records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
