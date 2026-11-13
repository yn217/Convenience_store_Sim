"""Cut out the bust-up reactions used by Rikka's live reactions (data/presentation/rikka_reactions_v1.json).

Each source is a reviewed ComfyUI candidate on a white background. ComfyUI's built-in BiRefNet removes the
background (same model as tools/assets/apply_birefnet_character_pilot.ps1), then the cutout is reduced to
512x512: the figure is drawn at about 260 px, so 1024 px would only grow the package.

Usage: python tools/assets/build_rikka_live_reactions.py [--comfy http://127.0.0.1:8188]
ComfyUI rule for this machine: submit only while running + pending jobs are 10 or fewer.
"""

from __future__ import annotations

import argparse
import json
import shutil
import time
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "presentation" / "rikka_reactions_v1.json"
SOURCE_DIR = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui" / "character_reactions_1024x1024"
COMFY_ROOT = Path("F:/Stable Diffusion/ComfyUI-Windows/ComfyUI_windows_portable/ComfyUI")
SIZE = 512


def source_for(number: str) -> Path:
    return SOURCE_DIR / f"rikka_bustup_reaction_{number}_1024x1024_00001_.png"


def _api(url: str, path: str, data: dict | None = None) -> dict:
    req = urllib.request.Request(url + path, data=json.dumps(data).encode() if data else None, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def _cut(url: str, source: Path, name: str) -> Path:
    while True:
        queue = _api(url, "/queue")
        if len(queue["queue_running"]) + len(queue["queue_pending"]) <= 10:
            break
        time.sleep(15)
    shutil.copy(source, COMFY_ROOT / "input" / f"{name}.png")
    graph = {
        "1": {"class_type": "LoadImage", "inputs": {"image": f"{name}.png"}},
        "2": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
        "3": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["2", 0], "image": ["1", 0]}},
        "4": {"class_type": "InvertMask", "inputs": {"mask": ["3", 0]}},
        "5": {"class_type": "JoinImageWithAlpha", "inputs": {"image": ["1", 0], "alpha": ["4", 0]}},
        "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0], "filename_prefix": name}},
    }
    prompt_id = _api(url, "/prompt", {"prompt": graph, "client_id": "claude-rikka-reactions"})["prompt_id"]
    for _ in range(300):
        time.sleep(2)
        history = _api(url, "/history/" + prompt_id)
        if prompt_id in history:
            status = history[prompt_id]["status"]
            if status["status_str"] != "success":
                raise RuntimeError(f"BiRefNet failed for {source.name}: {status.get('messages', [])}")
            image = history[prompt_id]["outputs"]["6"]["images"][0]
            return COMFY_ROOT / "output" / image.get("subfolder", "") / image["filename"]
    raise TimeoutError(source.name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--comfy", default="http://127.0.0.1:8188")
    args = parser.parse_args()
    data = json.loads(DATA.read_text(encoding="utf-8"))
    done: set[str] = set()
    for row in data["reactions"]:
        number = str(row["source_reaction"])
        target = ROOT / str(row["image"]).removeprefix("res://")
        if number in done:
            continue
        done.add(number)
        cut = _cut(args.comfy, source_for(number), f"claude_rikka_reaction_{number}")
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.open(cut).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS).save(target, optimize=True)
        print(f"{number} -> {target.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
