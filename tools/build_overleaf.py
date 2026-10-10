#!/usr/bin/env python3
"""Package the single-source report; --check verifies the committed archive."""

import argparse
from pathlib import Path
import re
import sys
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "overleaf.zip"
ALLOWED_ASSETS = {".png", ".jpg", ".jpeg", ".mdj", ".mpp", ".csv"}


def inputs():
    paths = [ROOT / "main.tex", ROOT / ".latexmkrc"]
    paths.extend(sorted((ROOT / "report-assets").rglob("*")))
    files = {}
    for path in paths:
        if path.is_dir():
            continue
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing or non-regular input: {path}")
        if path.parent != ROOT and path.suffix.lower() not in ALLOWED_ASSETS:
            raise ValueError(f"Unexpected asset type: {path}")
        files[path.relative_to(ROOT).as_posix()] = path.read_bytes()
    source = files["main.tex"].decode("utf-8")
    if re.search(r"\\(?:input|include|includeonly|lstinputlisting|VerbatimInput)\b", source):
        raise ValueError("Report text must remain self-contained in main.tex")
    references = re.findall(r"\\reportfigure\{([^}]+)\}", source)
    for reference in references:
        if reference not in files:
            raise ValueError(f"Missing figure: {reference}")
    images = {name for name in files if Path(name).suffix.lower() in {".png", ".jpg", ".jpeg"}}
    unused = images - set(references)
    if unused:
        raise ValueError(f"Images not incorporated into the report: {sorted(unused)}")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="check without rewriting")
    args = parser.parse_args()
    files = inputs()
    if args.check:
        with ZipFile(ARCHIVE) as archive:
            if archive.testzip() is not None:
                raise ValueError("Archive CRC check failed")
            names = archive.namelist()
            if len(names) != len(set(names)) or set(names) != set(files):
                raise ValueError("Archive file list differs from report inputs")
            for name, content in files.items():
                if archive.read(name) != content:
                    raise ValueError(f"Stale archive entry: {name}")
        print(f"OK: {ARCHIVE.name} matches all {len(files)} inputs")
        return
    with NamedTemporaryFile(dir=ROOT, suffix=".zip", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with ZipFile(temporary_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
            for name, content in sorted(files.items()):
                entry = ZipInfo(name, date_time=(2026, 10, 10, 0, 0, 0))
                entry.compress_type = ZIP_DEFLATED
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, content, compresslevel=9)
        temporary_path.replace(ARCHIVE)
    finally:
        temporary_path.unlink(missing_ok=True)
    print(f"Built {ARCHIVE.name}: {len(files)} files, {ARCHIVE.stat().st_size:,} bytes")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
