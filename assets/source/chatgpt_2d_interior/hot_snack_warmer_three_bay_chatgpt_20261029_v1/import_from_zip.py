#!/usr/bin/env python3
"""Import ChatGPT-exported hot-snack image binary files without altering originals.

Usage:
    python assets/source/chatgpt_2d_interior/hot_snack_warmer_three_bay_chatgpt_20261029_v1/import_from_zip.py /path/to/hot_snack_warmer_full_small_manifest_20261029.zip
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path
from zipfile import ZipFile

ASSET = Path(__file__).resolve().parent
BUNDLE = ASSET.parent / "_bundles" / "hot_snack_warmer_three_bay_full_20261029.zip"
EXPECTED_ZIP_SHA256 = "696e558a5d615ebb6028e59c9e0675e11138992547cd62d237c58b7b5057db81"
EXPECTED_SOURCE_SHA256 = "27f3750df93212453962d30bd97e5137df0c717a7e845cf54842047dea9c04ef"
IMAGES = ["source_original.png", "sprite_fullres.png", "sprite_fullres.webp", "game_512.png", "game_256.png"]

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("zip_path", type=Path)
    args = p.parse_args()
    bundle_bytes = args.zip_path.read_bytes()
    if sha256(bundle_bytes) != EXPECTED_ZIP_SHA256:
        raise SystemExit("ZIP SHA-256 mismatch: STOP, do not import a different archive")

    planned: list[tuple[Path, bytes]] = []
    with ZipFile(args.zip_path) as z:
        if not set(IMAGES).issubset(z.namelist()):
            raise SystemExit("Missing expected image files in ZIP")
        for name in IMAGES:
            content = z.read(name)
            if name == "source_original.png" and sha256(content) != EXPECTED_SOURCE_SHA256:
                raise SystemExit("Original source PNG hash mismatch")
            planned.append((ASSET / name, content))
    planned.append((BUNDLE, bundle_bytes))

    for path, content in planned:
        if path.exists() and sha256(path.read_bytes()) != sha256(content):
            raise SystemExit(f"Refusing to overwrite changed file: {path}")
    for path, content in planned:
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.write_bytes(content)
        print(f"OK {path} {len(content)} bytes {sha256(content)}")

    print("Ready for Codex: git add the listed files; commit to Draft PR branch; verify GitHub sha/readback.")
    print("Do not set runtime_approved=true before Godot projection and visual QA.")

if __name__ == "__main__":
    main()
