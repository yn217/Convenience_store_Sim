"""Extract embedded ComfyUI metadata for the 334-image review set.

This is deliberately a read-only review aid.  It checks the PNG workflow
metadata against the placement table (seed, image size, and filename prefix),
but it never changes ``visual_match`` or any runtime approval state.  A prompt
can describe the intended pose without proving that the rendered pixels match
it, so the visual review gate remains separate.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.csv"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"
DEFAULT_OUTPUT = ROOT / "docs" / "art" / "COMFYUI_334_PROMPT_REVIEW_20261103.json"


def _read_rows() -> list[dict[str, str]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _expected_size(candidate_relpath: str) -> tuple[int, int] | None:
    if candidate_relpath.startswith("character_reactions_1024x1024/"):
        return (1024, 1024)
    if candidate_relpath.startswith("character_sprites_1024x1536/"):
        return (1024, 1536)
    if candidate_relpath.startswith("title_screen_1344x768/"):
        return (1344, 768)
    return None


def _workflow_metadata(image: Image.Image) -> dict[str, Any]:
    raw = image.info.get("prompt")
    if not raw:
        return {"error": "missing_prompt_metadata"}
    try:
        workflow = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as exc:
        return {"error": "invalid_prompt_metadata", "detail": str(exc)}

    texts: list[str] = []
    seeds: list[int] = []
    filename_prefixes: list[str] = []
    for node in workflow.values() if isinstance(workflow, dict) else []:
        if not isinstance(node, dict):
            continue
        inputs = node.get("inputs", {})
        if not isinstance(inputs, dict):
            continue
        text = inputs.get("text")
        if isinstance(text, str) and text.strip():
            texts.append(text)
        seed = inputs.get("seed")
        if isinstance(seed, (int, float, str)):
            try:
                seeds.append(int(seed))
            except (TypeError, ValueError):
                pass
        filename_prefix = inputs.get("filename_prefix")
        if isinstance(filename_prefix, str) and filename_prefix:
            filename_prefixes.append(filename_prefix)

    positive: list[str] = []
    negative: list[str] = []
    for text in texts:
        lowered = text.lower().lstrip()
        # Positive prompts also commonly contain phrases such as "no watermark".
        # Classify by the opening of the negative prompt instead of searching
        # the whole text for a word that can appear in either prompt.
        negative_start = lowered.lstrip("([{")
        if negative_start.startswith(("worst quality", "low quality", "bad anatomy", "negative prompt")):
            negative.append(text)
        else:
            positive.append(text)

    return {
        "positive": positive[0] if positive else "",
        "negative": negative[0] if negative else "",
        "text_node_count": len(texts),
        "seeds": seeds,
        "filename_prefixes": filename_prefixes,
    }


def _alignment(row: dict[str, str], image_size: tuple[int, int], metadata: dict[str, Any]) -> dict[str, Any]:
    candidate_name = Path(row["candidate_relpath"]).stem
    expected_size = _expected_size(row["candidate_relpath"])
    prefixes = metadata.get("filename_prefixes", [])
    seeds = metadata.get("seeds", [])
    prefix_match = any(candidate_name.startswith(prefix) for prefix in prefixes)
    seed_match = int(row["seed"]) in seeds
    size_match = expected_size is None or image_size == expected_size
    return {
        "seed_matches_csv": seed_match,
        "filename_prefix_matches_png": prefix_match,
        "image_size_matches_group": size_match,
        "expected_size": list(expected_size) if expected_size else None,
        "metadata_complete": not metadata.get("error") and bool(metadata.get("positive")) and bool(metadata.get("negative")) and bool(seeds) and bool(prefixes),
    }


def build_report(rows: list[dict[str, str]]) -> dict[str, Any]:
    assets: list[dict[str, Any]] = []
    for row in rows:
        source = CANDIDATE_ROOT / row["candidate_relpath"]
        entry: dict[str, Any] = dict(row)
        entry["candidate_path"] = source.relative_to(ROOT).as_posix()
        entry["visual_match"] = "not_yet_verified"
        entry["runtime_approved"] = False
        if not source.is_file():
            entry["image_error"] = "missing_candidate_file"
            entry["metadata"] = {"error": "image_not_found"}
            entry["alignment"] = {"metadata_complete": False}
            assets.append(entry)
            continue
        try:
            with Image.open(source) as image:
                image_size = tuple(image.size)
                metadata = _workflow_metadata(image)
        except Exception as exc:  # pragma: no cover - defensive for corrupt review files
            entry["image_error"] = f"image_read_error: {exc}"
            entry["metadata"] = {"error": "image_read_error", "detail": str(exc)}
            entry["alignment"] = {"metadata_complete": False}
            assets.append(entry)
            continue
        entry["image_size"] = list(image_size)
        entry["metadata"] = metadata
        entry["alignment"] = _alignment(row, image_size, metadata)
        assets.append(entry)

    alignment_keys = ("seed_matches_csv", "filename_prefix_matches_png", "image_size_matches_group")
    summary = {
        "candidate_count": len(assets),
        "metadata_readable": sum("error" not in asset["metadata"] for asset in assets),
        "metadata_complete": sum(asset["alignment"].get("metadata_complete", False) for asset in assets),
        "seed_matches_csv": sum(asset["alignment"].get("seed_matches_csv", False) for asset in assets),
        "filename_prefix_matches_png": sum(asset["alignment"].get("filename_prefix_matches_png", False) for asset in assets),
        "image_size_matches_group": sum(asset["alignment"].get("image_size_matches_group", False) for asset in assets),
        "alignment_ok": sum(all(asset["alignment"].get(key, False) for key in alignment_keys) for asset in assets),
        "visual_match_verified": 0,
        "runtime_approved": 0,
    }
    return {
        "schema_version": 1,
        "status": "prompt_metadata_review_only",
        "source_csv": CSV_PATH.relative_to(ROOT).as_posix(),
        "candidate_root": CANDIDATE_ROOT.relative_to(ROOT).as_posix(),
        "notes": [
            "Embedded prompts are extracted from PNG metadata without changing source images.",
            "Alignment checks do not prove that rendered pixels match the described pose.",
            "visual_match remains not_yet_verified until individual image and prompt review is complete.",
            "runtime_approved remains false until rights, display QA, and explicit approval are complete.",
        ],
        "summary": summary,
        "assets": assets,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    rows = _read_rows()
    if len(rows) != 334:
        raise ValueError(f"expected 334 placement rows, got {len(rows)}")
    report = build_report(rows)
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False, sort_keys=True))
    print(f"wrote {output}")


if __name__ == "__main__":
    main()
