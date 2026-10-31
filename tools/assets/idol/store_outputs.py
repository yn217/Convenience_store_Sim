"""Files a batch of Idol outputs (F:/AI_Tools/idol-sdk/outputs/<batch>/<type>.ply, _input.png, _camera.json) into the
Idol source folder the way the earlier candidates are kept: <type>_<seed>_v1/ with reference.png (the ComfyUI
reference from assets/source/idol_refs), reference_input.png, reference.ply, reference_camera.json and manifest.json.

    python tools/assets/idol/store_outputs.py <batch_dir> <type>=<ref seed> ... [--dst DIR]
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

DST = Path("F:/Cordex_OpenAI/ゲーム製作_コンビニ経営/assets/source/idol")
FIELDS = ["x", "y", "z", "nx", "ny", "nz", "f_dc_0", "f_dc_1", "f_dc_2", "opacity", "scale_0", "scale_1", "scale_2",
          "rot_0", "rot_1", "rot_2", "rot_3"]


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest().upper()


def main():
    args = sys.argv[1:]
    dst = DST
    if "--dst" in args:
        i = args.index("--dst")
        dst = Path(args[i + 1])
        del args[i:i + 2]
    batch = Path(args[0])
    for pair in args[1:]:
        t, seed = pair.split("=")
        out = dst / ("%s_%s_v1" % (t, seed))
        out.mkdir(parents=True, exist_ok=True)
        ref = Path("assets/source/idol_refs/%s_%s.png" % (t, seed))
        files = {"reference.png": ref, "reference_input.png": batch / (t + "_input.png"),
                 "reference.ply": batch / (t + ".ply"), "reference_camera.json": batch / (t + "_camera.json")}
        for name, src in files.items():
            shutil.copyfile(src, out / name)
        rel = "assets/source/idol/" + out.name + "/"
        manifest = {
            "asset_id": "%s_idol_v1" % t, "fixture_type_id": t, "status": "candidate",
            "source_image": rel + "reference.png",
            "source_image_origin": "local ComfyUI, Anima-Base-v1.0, no LoRA (tools/assets/comfy_fixture_refs.py, seed %s; prompt in "
                                   "cs_cv2 assets/source/idol_refs/%s_%s.json)" % (seed, t, seed),
            "preprocessed_image": rel + "reference_input.png", "output_ply": rel + "reference.ply",
            "camera_json": rel + "reference_camera.json", "generator": "speridlabs/idol",
            "generator_entrypoint": "F:/AI_Tools/idol-sdk (python -m idol.sample, as Generate.ps1)", "mode": "synthetic", "seed": 42,
            "steps": 50, "num_gaussians": 262144, "optimize": False, "attention_backend": "sdpa", "ply_fields": FIELDS,
            "sha256": {n: sha(out / n) for n in files},
            "license_note": "Idol Apache-2.0; conditioning uses DINOv3 (Meta DINOv3 License) and the FLUX.2-dev VAE "
                            "(FLUX Non-Commercial License v2.1): commercial use not cleared",
            "runtime_approved": False,
        }
        (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(out)


if __name__ == "__main__":
    main()
