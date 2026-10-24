#!/usr/bin/env python3
"""Run the official Hunyuan3D-2.1 paint stage in a separate process."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_SOURCE = Path("/mnt/f/WSL/Hunyuan3D-2.1-upstream")
DEFAULT_BUILD_SRC = Path("/home/inayut/hunyuan-paint-build-src")
DEFAULT_MESH = Path(
    "/mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/"
    "hunyuan/shelf_general_FULL/raw_generated.glb"
)
DEFAULT_OUTPUT_DIR = Path(
    "/mnt/f/WSL/Pixal3D-project/build/issue123-image-to-3d/paint-setup"
)
DEFAULT_REAL_ESRGAN = DEFAULT_OUTPUT_DIR / "weights/RealESRGAN_x4plus.pth"
EXPECTED_SOURCE_REVISION = "82920d643c0dc2f7bfd7255f45f62d386edfe60c"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(args: argparse.Namespace) -> int:
    source = args.source.resolve()
    paint_dir = source / "hy3dpaint"
    build_paint_dir = args.build_src / "hy3dpaint"
    build_rasterizer_dir = args.build_src / "custom_rasterizer"
    mesh = args.mesh.resolve()
    image = args.image.resolve()
    output_dir = args.output_dir.resolve()
    output_obj = output_dir / "shelf_general_FULL_textured.obj"
    output_glb = output_dir / "shelf_general_FULL_textured.glb"
    log_path = output_dir / "paint-run.json"
    output_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("HF_HOME", "/home/inayut/pixal3d-cache/huggingface")
    os.environ.setdefault("HUGGINGFACE_HUB_CACHE", str(Path(os.environ["HF_HOME"]) / "hub"))

    record: dict[str, object] = {
        "status": "running",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "source_expected_revision": EXPECTED_SOURCE_REVISION,
        "model_id": "tencent/Hunyuan3D-2.1",
        "model_revision": args.model_revision,
        "mesh": str(mesh),
        "image": str(image),
        "output_glb": str(output_glb),
        "views": 6,
        "resolution": 512,
        "use_remesh": False,
        "device": "cuda",
        "pid": os.getpid(),
        "elapsed_seconds": None,
        "gpu": {},
    }
    started = time.monotonic()

    def gpu_stats(torch_module) -> dict[str, object]:
        if not torch_module.cuda.is_available():
            return {"available": False}
        try:
            return {
                "available": True,
                "device_name": torch_module.cuda.get_device_name(0),
                "total_bytes": torch_module.cuda.get_device_properties(0).total_memory,
                "peak_allocated_bytes": torch_module.cuda.max_memory_allocated(0),
                "peak_reserved_bytes": torch_module.cuda.max_memory_reserved(0),
            }
        except Exception as exc:  # preserve the inference result even if telemetry fails
            return {"available": True, "telemetry_error": repr(exc)}

    torch = None
    try:
        if not paint_dir.is_dir():
            raise FileNotFoundError(f"Official hy3dpaint source not found: {paint_dir}")
        # The exact extension suffix varies by Python build.
        if not list((build_paint_dir / "DifferentiableRenderer").glob("mesh_inpaint_processor*.so")):
            raise FileNotFoundError(f"Compiled paint extension not found under {build_paint_dir}")
        if not list(build_rasterizer_dir.glob("custom_rasterizer_kernel*.so")):
            raise FileNotFoundError(f"Compiled rasterizer extension not found under {build_rasterizer_dir}")
        revision = subprocess.check_output(
            ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
        ).strip()
        record["source_revision"] = revision
        if revision != EXPECTED_SOURCE_REVISION:
            raise RuntimeError(
                f"Unexpected official source revision {revision}; expected "
                f"{EXPECTED_SOURCE_REVISION}"
            )
        for label, path in (("mesh", mesh), ("image", image)):
            if not path.is_file() or path.stat().st_size == 0:
                raise FileNotFoundError(f"{label} input is missing or empty: {path}")
            record[f"{label}_sha256"] = sha256(path)
        if not args.realesrgan.is_file() or args.realesrgan.stat().st_size == 0:
            raise FileNotFoundError(f"Official RealESRGAN checkpoint is missing: {args.realesrgan}")

        sys.path.insert(0, str(paint_dir))
        sys.path.insert(0, str(build_paint_dir))
        sys.path.insert(0, str(build_rasterizer_dir))
        os.chdir(paint_dir)
        import torch as torch_module
        import huggingface_hub

        torch = torch_module
        if not torch.cuda.is_available():
            raise RuntimeError("CUDA is unavailable in the dedicated paint environment")
        torch.cuda.reset_peak_memory_stats(0)
        record["torch"] = torch.__version__
        record["cuda_runtime"] = torch.version.cuda
        record["gpu"] = gpu_stats(torch)

        from textureGenPipeline import Hunyuan3DPaintConfig, Hunyuan3DPaintPipeline
        from utils.torchvision_fix import apply_fix

        apply_fix()

        original_snapshot_download = huggingface_hub.snapshot_download

        def pinned_snapshot_download(*call_args, **call_kwargs):
            if call_kwargs.get("repo_id") == "tencent/Hunyuan3D-2.1":
                if args.model_revision:
                    call_kwargs["revision"] = args.model_revision
                snapshot = Path(original_snapshot_download(*call_args, **call_kwargs))
                record["model_revision"] = snapshot.name
                record["model_snapshot"] = str(snapshot)
                return str(snapshot)
            return original_snapshot_download(*call_args, **call_kwargs)

        huggingface_hub.snapshot_download = pinned_snapshot_download

        config = Hunyuan3DPaintConfig(max_num_view=6, resolution=512)
        config.realesrgan_ckpt_path = str(args.realesrgan.resolve())
        pipeline = Hunyuan3DPaintPipeline(config)
        record["gpu"] = gpu_stats(torch)
        result_obj = Path(
            pipeline(
                mesh_path=str(mesh),
                image_path=str(image),
                output_mesh_path=str(output_obj),
                use_remesh=False,
                save_glb=True,
            )
        )
        produced_glb = Path(str(result_obj).replace(".obj", ".glb"))
        if not produced_glb.is_file() or produced_glb.stat().st_size == 0:
            raise RuntimeError(f"Paint pipeline did not produce a non-empty GLB: {produced_glb}")
        if produced_glb != output_glb:
            produced_glb.replace(output_glb)
        record["output_glb_bytes"] = output_glb.stat().st_size
        record["output_glb_sha256"] = sha256(output_glb)
        record["status"] = "success"
        record["license_note"] = "LOCAL EVALUATION ONLY; do not publish generated output."
        return_code = 0
    except Exception as exc:
        record["status"] = "error"
        record["error"] = repr(exc)
        record["traceback"] = traceback.format_exc()
        record["license_note"] = "LOCAL EVALUATION ONLY; do not publish generated output."
        return_code = 1
    finally:
        record["elapsed_seconds"] = round(time.monotonic() - started, 3)
        if torch is not None:
            record["gpu"] = gpu_stats(torch)
        record["finished_utc"] = datetime.now(timezone.utc).isoformat()
        log_path.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2, ensure_ascii=False))
    return return_code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--build-src", type=Path, default=DEFAULT_BUILD_SRC)
    parser.add_argument("--mesh", type=Path, default=DEFAULT_MESH)
    parser.add_argument("--image", type=Path, required=True, help="Approved/corrected shelf crop")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--realesrgan", type=Path, default=DEFAULT_REAL_ESRGAN)
    parser.add_argument(
        "--model-revision",
        default=None,
        help="Optional immutable Hugging Face commit hash for tencent/Hunyuan3D-2.1",
    )
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(run(parse_args()))
