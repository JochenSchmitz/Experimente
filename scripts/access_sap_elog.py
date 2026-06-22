#!/usr/bin/env python3
"""Access and list the SAP-ELOG directory."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Sequence


DEFAULT_SAP_ELOG_DIRECTORY = (
    r"C:\Users\schmitz03\OneDrive - FES Frankfurter Entsorgungs- u. Service GmbH"
    r"\Dokumente - IMM\General\01_Projekte\02_Experimentieren"
    r"\05_Schlackeoptimierung\07_Daten\SAP-ELOG"
)


@dataclass(frozen=True)
class DirectoryEntry:
    """Serializable metadata for one directory entry."""

    name: str
    relative_path: str
    kind: str
    size_bytes: int | None
    modified_at: str


def require_existing_directory(directory: str | Path) -> Path:
    """Return directory as Path or fail with a precise filesystem error."""

    path = Path(directory).expanduser()

    if not path.exists():
        raise FileNotFoundError(f"Verzeichnis nicht gefunden: {path}")

    if not path.is_dir():
        raise NotADirectoryError(f"Pfad ist kein Verzeichnis: {path}")

    return path


def collect_directory_entries(directory: str | Path, *, recursive: bool = False) -> list[DirectoryEntry]:
    """Read directory contents and return stable, sorted metadata."""

    root = require_existing_directory(directory)
    entries = root.rglob("*") if recursive else root.iterdir()

    return [
        _build_entry(root, entry)
        for entry in sorted(entries, key=lambda candidate: str(candidate).casefold())
    ]


def _build_entry(root: Path, entry: Path) -> DirectoryEntry:
    stat = entry.stat()
    is_directory = entry.is_dir()

    if is_directory:
        kind = "directory"
        size_bytes = None
    elif entry.is_file():
        kind = "file"
        size_bytes = stat.st_size
    else:
        kind = "other"
        size_bytes = stat.st_size

    return DirectoryEntry(
        name=entry.name,
        relative_path=entry.relative_to(root).as_posix(),
        kind=kind,
        size_bytes=size_bytes,
        modified_at=datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Prueft den Zugriff auf das SAP-ELOG-Verzeichnis und listet dessen Inhalte."
    )
    parser.add_argument(
        "--path",
        default=DEFAULT_SAP_ELOG_DIRECTORY,
        help="Zu lesendes Verzeichnis. Standard ist der SAP-ELOG-OneDrive-Pfad.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Inhalte rekursiv auflisten.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Ausgabe als JSON statt als Tabelle.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        entries = collect_directory_entries(args.path, recursive=args.recursive)
    except (FileNotFoundError, NotADirectoryError, PermissionError, OSError) as exc:
        print(f"Fehler: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps([asdict(entry) for entry in entries], ensure_ascii=False, indent=2))
    else:
        _print_table(entries)

    return 0


def _print_table(entries: Sequence[DirectoryEntry]) -> None:
    if not entries:
        print("Das Verzeichnis ist leer.")
        return

    print(f"{'Typ':<10} {'Groesse':>12}  Pfad")
    print(f"{'-' * 10} {'-' * 12}  {'-' * 40}")

    for entry in entries:
        size = "-" if entry.size_bytes is None else str(entry.size_bytes)
        print(f"{entry.kind:<10} {size:>12}  {entry.relative_path}")


if __name__ == "__main__":
    raise SystemExit(main())
