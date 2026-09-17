#!/usr/bin/env python3
"""Create a runtime-only WoW addon folder for deliberate Syncthing staging."""

from __future__ import annotations

import argparse
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
    return parser.parse_args()


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

    shutil.copy2(toc, destination / f"{args.addon_name}.toc")
    print(f"Staged {args.addon_name} from {args.toc} at {destination}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
