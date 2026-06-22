from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "access_sap_elog.py"
SPEC = importlib.util.spec_from_file_location("access_sap_elog", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Kann Script nicht laden: {SCRIPT_PATH}")

access_sap_elog = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = access_sap_elog
SPEC.loader.exec_module(access_sap_elog)


class AccessSapElogTest(unittest.TestCase):
    def test_collect_directory_entries_lists_direct_children(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "b.txt").write_text("B", encoding="utf-8")
            (root / "a-folder").mkdir()

            entries = access_sap_elog.collect_directory_entries(root)

        self.assertEqual([entry.relative_path for entry in entries], ["a-folder", "b.txt"])
        self.assertEqual(entries[0].kind, "directory")
        self.assertIsNone(entries[0].size_bytes)
        self.assertEqual(entries[1].kind, "file")
        self.assertEqual(entries[1].size_bytes, 1)

    def test_collect_directory_entries_lists_recursively_when_requested(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            nested = root / "folder"
            nested.mkdir()
            (nested / "file.csv").write_text("value", encoding="utf-8")

            entries = access_sap_elog.collect_directory_entries(root, recursive=True)

        self.assertEqual([entry.relative_path for entry in entries], ["folder", "folder/file.csv"])

    def test_missing_directory_fails_fast(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            missing_path = Path(temp_dir) / "missing"

            with self.assertRaises(FileNotFoundError) as error:
                access_sap_elog.collect_directory_entries(missing_path)

        self.assertIn("Verzeichnis nicht gefunden", str(error.exception))

    def test_file_path_fails_fast(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = Path(temp_dir) / "file.txt"
            file_path.write_text("content", encoding="utf-8")

            with self.assertRaises(NotADirectoryError) as error:
                access_sap_elog.collect_directory_entries(file_path)

        self.assertIn("Pfad ist kein Verzeichnis", str(error.exception))

    def test_main_outputs_json(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "elog.txt").write_text("ok", encoding="utf-8")

            stdout = StringIO()
            with redirect_stdout(stdout):
                exit_code = access_sap_elog.main(["--path", str(root), "--json"])

        self.assertEqual(exit_code, 0)
        self.assertEqual(json.loads(stdout.getvalue())[0]["relative_path"], "elog.txt")


if __name__ == "__main__":
    unittest.main()
