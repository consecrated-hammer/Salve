#!/usr/bin/env python3
"""Regression checks for the local staging and catalogue-maintenance tools."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_tool(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stage = load_tool("stage_addon")
importer = load_tool("import_db2_candidates")


class StageAddonTests(unittest.TestCase):
    def test_runtime_allowlist_rejects_secret_and_source_files(self):
        for name in (".env", ".env.production", "release.token", "tools/build.py", "README.md"):
            self.assertFalse(stage.should_copy(Path(name)), name)
        self.assertTrue(stage.should_copy(Path("Features/Sound.lua")))
        self.assertTrue(stage.should_copy(Path("Textures/Salve.tga")))

    def test_dev_versions_are_compact_and_increment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "Salve.toc"
            existing = root / "Installed.toc"
            source.write_text("## Version: 1.5.23\n", encoding="utf-8")
            existing.write_text("## Version: 1.5.23-dev2\n", encoding="utf-8")
            self.assertEqual(stage.staged_version(source, existing, True), "1.5.23-dev3")

    def test_selected_camelot_toc_keeps_its_client_specific_name(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / "source", Path(directory) / "destination"
            source.mkdir()
            destination.mkdir()
            (source / "Salve.toc").write_text("retail", encoding="utf-8")
            (source / "Salve_Camelot.toc").write_text("camelot", encoding="utf-8")
            stage.copy_client_tocs(source, destination)
            self.assertEqual((destination / "Salve.toc").read_text(encoding="utf-8"), "retail")
            self.assertEqual((destination / "Salve_Camelot.toc").read_text(encoding="utf-8"), "camelot")


class ImportTests(unittest.TestCase):
    def test_atomic_writer_preserves_self_alert_column(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "debuffs.csv"
            importer.write_csv_atomically(path, [{field: "" for field in importer.FIELDS}])
            header = path.read_text(encoding="utf-8").splitlines()[0]
            self.assertEqual(header.split(","), importer.FIELDS)
            self.assertFalse(list(Path(directory).glob("*.tmp")))


if __name__ == "__main__":
    unittest.main()
