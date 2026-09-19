#!/usr/bin/env python3
"""Create a runtime-only WoW addon folder for deliberate Syncthing staging."""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path


EXCLUDED_DIRECTORIES = {
    ".git", ".github", ".scratch", ".release", "Art", "data", "docs", "media",
    "tests", "tools", "__pycache__",
}
EXCLUDED_NAMES = {".gitignore", ".pkgmeta", "CHANGELOG.md", "README.md", "DEVELOPMENT.md"}
EXCLUDED_SUFFIXES = {".ps1", ".py", ".sh", ".zip", ".tmp", ".pyc"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--toc", required=True, help="TOC to install, relative to the repository root")
    parser.add_argument("--addon-name", required=True, help="destination folder and installed TOC basename")
    parser.add_argument("--output", required=True, type=Path, help="staging root; only <output>/<addon-name> is replaced")
    parser.add_argument("--dev", action="store_true", help="stamp the staged TOC with an incrementing -dev-N version")
    parser.add_argument("--leatrix-style", action="store_true", help="stage a minimal generic Forever TOC matching Leatrix Plus's proven shape")
    return parser.parse_args()


def staged_version(source_toc: Path, existing_toc: Path, enabled: bool) -> str | None:
    if not enabled:
        return None
    source = re.search(r"^## Version:\s*(.+?)\s*$", source_toc.read_text(encoding="utf-8"), re.MULTILINE)
    if not source:
        raise SystemExit(f"TOC has no Version metadata: {source_toc}")
    base = re.sub(r"-dev-\d+$", "", source.group(1))
    number = 1
    if existing_toc.is_file():
        previous = re.search(r"^## Version:\s*" + re.escape(base) + r"-dev-(\d+)\s*$", existing_toc.read_text(encoding="utf-8"), re.MULTILINE)
        if previous:
            number = int(previous.group(1)) + 1
    return f"{base}-dev-{number}"


def leatrix_style_toc(source_toc: Path, addon_name: str) -> str:
    source = source_toc.read_text(encoding="utf-8")
    def metadata(name: str) -> str | None:
        match = re.search(r"^## " + re.escape(name) + r":\s*(.+?)\s*$", source, re.MULTILINE)
        return match.group(1) if match else None
    saved = metadata("SavedVariables") or metadata("SavedVariablesPerCharacter")
    if not saved:
        raise SystemExit(f"TOC has no SavedVariables declaration: {source_toc}")
    files = [line for line in source.splitlines() if line.strip() and not line.startswith("#")]
    headers = ["## Interface: 16001", "", f"## Title: {addon_name}"]
    for key in ("Notes", "Version", "Author"):
        if value := metadata(key):
            headers.append(f"## {key}: {value}")
    headers.extend([f"## SavedVariables: {saved}" if metadata("SavedVariables") else f"## SavedVariablesPerCharacter: {saved}", "## LoadSavedVariablesFirst: 1"])
    if game_type := metadata("AllowLoadGameType"):
        headers.append(f"## AllowLoadGameType: {game_type}")
    if icon := metadata("IconTexture"):
        headers.append(f"## IconTexture: {icon}")
    headers.extend(line for line in source.splitlines() if line.startswith("## X-"))
    return "\n".join(headers + [""] + files) + "\n"


def should_copy(relative_path: Path) -> bool:
    if any(part in EXCLUDED_DIRECTORIES for part in relative_path.parts[:-1]):
        return False
    if relative_path.name in EXCLUDED_NAMES or relative_path.suffix.lower() in EXCLUDED_SUFFIXES:
        return False
    if relative_path.suffix.lower() == ".toc":
        return False
    return True


def main() -> int:
    args = parse_args()
    source = Path(__file__).resolve().parents[1]
    toc = source / args.toc
    if not toc.is_file() or toc.suffix.lower() != ".toc":
        raise SystemExit(f"TOC not found: {toc}")
    if Path(args.addon_name).name != args.addon_name or args.addon_name in {"", ".", ".."}:
        raise SystemExit("--addon-name must be one safe folder name")

    output = args.output.resolve()
    if output == source or source in output.parents:
        raise SystemExit("--output must be outside the repository")
    destination = output / args.addon_name
    if destination.resolve() == source:
        raise SystemExit("refusing to replace the source repository")
    if destination == output or destination.parent != output:
        raise SystemExit("refusing an unsafe destination")
    dev_version = staged_version(toc, destination / f"{args.addon_name}.toc", args.dev)

    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    for path in source.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(source)
        if should_copy(relative):
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)

    staged_toc = destination / f"{args.addon_name}.toc"
    if args.leatrix_style:
        staged_toc.write_text(leatrix_style_toc(toc, args.addon_name), encoding="utf-8")
    else:
        shutil.copy2(toc, staged_toc)
    if dev_version:
        staged_toc.write_text(re.sub(r"^## Version:\s*.+?$", f"## Version: {dev_version}", staged_toc.read_text(encoding="utf-8"), flags=re.MULTILINE), encoding="utf-8")
    print(f"Staged {args.addon_name} from {args.toc} at {destination}" + (f" ({dev_version})" if dev_version else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
