#!/usr/bin/env python3
"""Validate Salve's catalogue and generate its built-in data library."""

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
    toc_version = version_match.group(1) if version_match else None
    # Local `-devN` builds identify the copied test addon in-game without
    # regenerating or version-bumping the bundled release catalogue.
    data_version = re.sub(r"-dev\d+$", "", toc_version or "")
    if not toc_version or data_version != config.get("version"):
        raise ValueError("data version does not match Salve.toc")
    if not interface_match or int(interface_match.group(1)) != int(config.get("interface", 0)):
        raise ValueError("data interface does not match Salve.toc")

    modules: dict[str, dict] = {}
    scope_owner: dict[tuple[str, int, int], str] = {}

    for module in config.get("modules", []):
        folder = module.get("folder", "")
        if not FOLDER_RE.fullmatch(folder) or folder in modules:
            raise ValueError(f"invalid or duplicate module folder: {folder!r}")
        if not str(module.get("manifest_source", "")).startswith("https://"):
            raise ValueError(f"authoritative manifest source is required for {folder}")
        module["priority"] = int(module["priority"])
        all_ids: set[int] = set()
        for scope_type, field in (("instance", "instances"), ("map", "maps")):
            for scope in module.get(field, []):
                scope["id"] = int(scope["id"])
                if scope["id"] <= 0 or scope["id"] in all_ids:
                    raise ValueError(f"invalid or duplicate scope in {folder}: {scope['id']}")
                all_ids.add(scope["id"])
                priority_key = (scope_type, scope["id"], module["priority"])
                if priority_key in scope_owner:
                    raise ValueError(
                        f"{scope_type} {scope['id']} has equal-priority owners: "
                        f"{scope_owner[priority_key]} and {folder}"
                    )
                scope_owner[priority_key] = folder
        modules[folder] = module

    records: dict[str, list[dict]] = defaultdict(list)
    movement: dict[str, list[dict]] = defaultdict(list)
    seen: set[tuple[str, int, int]] = set()
    with DEBUFFS_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {
            "module", "instance_id", "spell_id", "spell_name", "dispel_type",
            "source", "source_build", "verified", "self_alert",
        }
        if set(reader.fieldnames or []) != required:
            raise ValueError("debuffs.csv headers do not match the required schema")
        for line_number, row in enumerate(reader, start=2):
            folder = row["module"]
            if folder not in modules:
                raise ValueError(f"line {line_number}: unknown module {folder}")
            row["instance_id"] = int(row["instance_id"])
            row["spell_id"] = int(row["spell_id"])
            valid_scopes = {item["id"] for item in modules[folder].get("instances", [])}
            valid_scopes.update(item["id"] for item in modules[folder].get("maps", []))
            if row["instance_id"] not in valid_scopes:
                raise ValueError(
                    f"line {line_number}: instance {row['instance_id']} is not in {folder}"
                )
            if row["spell_id"] <= 0 or row["dispel_type"] not in VALID_DISPELS:
                raise ValueError(f"line {line_number}: invalid spell ID or dispel type")
            if row["verified"] not in {"true", "false"}:
                raise ValueError(f"line {line_number}: verified must be true or false")
            if row["self_alert"] not in {None, "", "true", "false"}:
                raise ValueError(f"line {line_number}: self_alert must be true or false")
            row["self_alert"] = row["self_alert"] == "true"
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
            valid_scopes = {item["id"] for item in modules[folder].get("instances", [])}
            valid_scopes.update(item["id"] for item in modules[folder].get("maps", []))
            if row["instance_id"] not in valid_scopes:
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


def render_data(modules: dict[str, dict], records: dict[str, list[dict]],
                movement: dict[str, list[dict]]) -> str:
    """Render one table, retaining only the highest-priority source per scope."""
    selected: dict[str, tuple[dict, dict, list[dict]]] = {}
    for folder, module in modules.items():
        by_scope: dict[int, list[dict]] = defaultdict(list)
        for record in records[folder]:
            by_scope[record["instance_id"]].append(record)
        for scope_type, field in (("instance", "instances"), ("map", "maps")):
            for scope in module.get(field, []):
                key = f"{scope_type}:{scope['id']}"
                current = selected.get(key)
                if not current or module["priority"] > current[0]["priority"]:
                    selected[key] = (module, scope, by_scope[scope["id"]])

    movement_ids = sorted({
        record["spell_id"]
        for source in movement.values()
        for record in source
        if record["verified"] == "true"
    })

    lines = [
        "-- Generated by tools/generate_data_modules.py. Edit data/, not this file.",
        "if not Salve then return end",
        "",
    ]
    if movement_ids:
        lines.extend([
            "if Salve.Escape and Salve.Escape.RegisterMovement then",
            f"    Salve.Escape:RegisterMovement(\"Salve\", {{ {', '.join(map(str, movement_ids))} }})",
            "end",
            "",
        ])
    lines.extend([
        "if not Salve.Sound or not Salve.Sound.RegisterData then return end",
        "",
        "Salve.Sound:RegisterData(\"Salve\", {",
    ])
    for scope_key in sorted(selected, key=lambda key: (
        key.split(":", 1)[0], int(key.split(":", 1)[1])
    )):
        module, scope, scope_records = selected[scope_key]
        lines.extend(
            [
                f"    [{lua_string(scope_key)}] = {{",
                f"        name = {lua_string(scope['name'])},",
                f"        season = {lua_string(module['title'])},",
                f"        seasonSource = {lua_string(module['manifest_source'])},",
                '        coverage = "Encounter Journal baseline; trash may be absent",',
                "        debuffs = {",
            ]
        )
        for record in sorted(scope_records, key=lambda item: item["spell_id"]):
            lines.extend(
                [
                    "            {",
                    f"                spellID = {record['spell_id']},",
                    f"                dispelType = {lua_string(record['dispel_type'])},",
                    f"                name = {lua_string(record['spell_name'])},",
                    f"                verified = {record['verified']},",
                    *(["                selfAlert = true,"] if record["self_alert"] else []),
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
    path = ROOT / "Catalog" / "Curated.lua"
    expected = render_data(modules, records, movement)
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
        print(f"generated one built-in catalogue from {len(modules)} seasons, {sum(map(len, records.values()))} dispel and {sum(map(len, movement.values()))} movement records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
