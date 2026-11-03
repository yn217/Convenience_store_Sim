"""Renders every fixture of tools/assets/idol/fixtures.json into assets/generated/fixtures/<type>/ (body, shadow,
glass_front layers + <type>_a.visual.json + RENDER_INFO.json). Run with the Idol venv python, from the repo root:

    F:/AI_Tools/idol-sdk/.venv/Scripts/python.exe -I tools/assets/idol/build_fixtures.py [type ...] [--src DIR] [--backend gsplat_classic]

--src: the Idol source folder (default: the primary checkout's assets/source/idol, where the PLYs and their
reference images are kept with their manifests). --backend: passed to render_fixture_splat.py (gsplat_classic needs
the gsplat venv, F:/AI_Tools/gsplat-venv/Scripts/python.exe).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "F:/Cordex_OpenAI/ゲーム製作_コンビニ経営/assets/source/idol"


def provenance(t, c, src, out):
    folder = os.path.dirname(c["ply"])
    m = json.load(open(os.path.join(src, folder, "manifest.json"), encoding="utf-8"))
    p = {
        "asset_id": t + "_a",
        "source_type": "AI (image) -> image-to-3D (Gaussian splats) -> splat render",
        "input_image": m.get("source_image_origin") or "assets/source/idol/%s/reference.png (OpenAI ImageGen reference, Codex)" % folder,
        "image_to_3d": "speridlabs/idol (Apache-2.0), synthetic, seed 42, 50 steps, 262144 Gaussians, no_optimize, SDPA; conditioning "
                       "facebook/dinov3-vith16plus-pretrain-lvd1689m (DINOv3 License) + black-forest-labs/FLUX.2-dev VAE (FLUX "
                       "Non-Commercial License v2.1); background removal: Idol's BiRefNet",
        "splat_ply": "assets/source/idol/%s/reference.ply (sha256 %s)" % (folder, m["sha256"]["reference.ply"]),
        "render": "tools/assets/idol/render_fixture_splat.py (orthographic iso2x_v1 splat rasterizer, 2x supersampled), "
                  "settings in tools/assets/idol/fixtures.json and RENDER_INFO.json",
        "license_or_usage_terms": "outputs of the user's own pipeline; no real brand or logo. FLUX.2-dev VAE is under a "
                                  "non-commercial model licence: check before a commercial release",
        "generation_date": "2026-11-01",
        "runtime_approved": False,
    }
    with open(os.path.join(out, "PROVENANCE.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(p, f, indent=1, ensure_ascii=False)
        f.write("\n")


def main():
    args = sys.argv[1:]
    src = SRC
    if "--src" in args:
        i = args.index("--src")
        src = args[i + 1]
        del args[i:i + 2]
    backend = []
    if "--backend" in args:
        i = args.index("--backend")
        backend = ["--backend", args[i + 1]]
        del args[i:i + 2]
    cfg = json.load(open(os.path.join(HERE, "fixtures.json"), encoding="utf-8"))
    for t in (args or [k for k in cfg if not k.startswith("_")]):
        c = cfg[t]
        out = os.path.join("assets/generated/fixtures", t)
        cmd = [sys.executable, "-I", os.path.join(HERE, "render_fixture_splat.py"), "--ply", os.path.join(src, c["ply"]),
               "--type", t, "--front_yaw", str(c["front_yaw"]), "--out", out] + c.get("args", []) + backend
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        os.replace(os.path.join(out, "render_info.json"), os.path.join(out, "RENDER_INFO.json"))
        provenance(t, c, src, out)
        print(t)


if __name__ == "__main__":
    main()
