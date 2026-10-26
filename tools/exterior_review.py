"""Build reproducible crops from actual Godot captures and the supplied target.

No generated picture is used as an in-game screenshot. Coordinates are normalized
editorial crop windows, never runtime placement data. Pillow only crops/composes QA.
"""
from pathlib import Path
import argparse
import json
import shutil
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
REGIONS = {
    "storefront": ((.14,.29,.67,.71), (.18,.16,.86,.65)),
    "entrance": ((.36,.47,.57,.76), (.38,.35,.65,.72)),
    "parking": ((.05,.40,.40,.83), (.12,.47,.66,.90)),
    "road": ((.03,.65,.58,.90), (.02,.65,.65,.91)),
    "sidewalk": ((.22,.50,.67,.83), (.23,.41,.84,.82)),
    "vegetation": ((.69,.36,.98,.85), (.02,.08,.25,.70)),
    "signage": ((.06,.19,.28,.47), (.07,.11,.20,.48)),
    "exterior_details": ((.25,.46,.72,.85), (.54,.49,.91,.88)),
    "side_wall": ((.65,.24,.97,.56), (.70,.37,.97,.66)),
    "lighting": ((.12,.12,.96,.80), (.07,.07,.98,.84)),
}


def crop(im, box):
    return im.crop(tuple(round(v * (im.width if i % 2 == 0 else im.height)) for i, v in enumerate(box)))


def build(args):
    dest = ROOT / "docs/qa/exterior-2026-10-26"
    folders = [dest / p for p in ["01_before", "02_target", "03_after", "04_comparison"]]
    for p in folders:
        p.mkdir(parents=True, exist_ok=True)
    paths = [Path(args.before), Path(args.target), Path(args.after)]
    images = [Image.open(p).convert("RGB") for p in paths]
    for folder, im, name in zip(folders, images, ["current_full.png", "target_full.png", "updated_full.png"]):
        im.save(folder / name)
    for name, (box, target_box) in REGIONS.items():
        pieces = [crop(images[0], box), crop(images[1], target_box), crop(images[2], box)]
        for folder, im in zip(folders, pieces):
            im.save(folder / f"{name}.png")
        board = Image.new("RGB", (1200, 390), "#e7e6df")
        draw = ImageDraw.Draw(board)
        for i, (im, label) in enumerate(zip(pieces, ["BEFORE / live Godot", "TARGET / supplied concept", "AFTER / live Godot"])):
            fitted = ImageOps.contain(im, (390, 355))
            board.paste(fitted, (i*400 + (400-fitted.width)//2, 30 + (355-fitted.height)//2))
            draw.text((i*400+10, 9), label, fill="#263a43")
        board.save(folders[3] / f"{name}_before_after.png")
    (folders[3] / "crop_windows.json").write_text(json.dumps(REGIONS, indent=2) + "\n")
    matrix = []
    board = Image.new("RGB", (1280, 1152), "#e7e6df")
    draw = ImageDraw.Draw(board)
    variants = ["exterior_1600x900", "low_1280x720", "high_1920x1080", "night_1600x900", "build_1600x900", "large_1280x720"]
    for n, name in enumerate(variants):
        shot = Path(args.after).parent / f"{name}.png"
        if not shot.exists():
            continue
        im = Image.open(shot).convert("RGB")
        expected = (1920,1080) if "1920" in name else (1280,720) if "1280" in name else (1600,900)
        assert im.size == expected, (name, im.size, expected)
        assert shot.stat().st_size > 10000, "empty capture"
        shutil.copy2(shot, folders[2] / shot.name)
        matrix.append(dict(file=shot.name, width=im.width, height=im.height, bytes=shot.stat().st_size, actual_game_capture=True))
        x, y = (n % 2)*640, (n // 2)*384
        draw.text((x+8,y+8), name, fill="#263a43")
        board.paste(im.resize((640,360), Image.Resampling.LANCZOS), (x,y+24))
    board.save(folders[3] / "capture_matrix.png")
    (folders[3] / "capture_matrix.json").write_text(json.dumps(matrix, indent=2) + "\n")
    # Every prop records the same anchor/scale contract, including legacy props.
    catalog = []
    for path in sorted((ROOT / "assets/generated/props").glob("*/*.visual.json")):
        m = json.loads(path.read_text(encoding="utf-8"))
        rot = m.get("rotations", {}).get("0", {})
        if not rot:
            continue
        dims = m.get("dimensions_m", {})
        canvas = rot.get("canvas_px", [320,320])
        pivot = rot.get("anchor_px", [160,210])
        catalog.append(dict(asset_id=m.get("visual_id", path.parent.name), category="exterior_prop",
            view_direction="iso2x_v1_rotation_0", world_width=dims.get("width"), world_depth=dims.get("depth"),
            world_height=dims.get("height"), render_width_px=canvas[0], render_height_px=canvas[1],
            pivot_x=pivot[0], pivot_y=pivot[1], anchor_type="ground", placement_offset=[0,0,0],
            occlusion_group="exterior_or_front_by_world_side", sort_key="rank_then_world_x_plus_world_y",
            asset_variant="painted" if "painted" in path.parent.name or "green_street_tree" in path.parent.name else "legacy",
            manifest=path.relative_to(ROOT).as_posix()))
    (ROOT / "docs/design/exterior/runtime_asset_catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(REGIONS)} three-way region comparisons in {dest}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--before", required=True)
    p.add_argument("--target", required=True)
    p.add_argument("--after", required=True)
    build(p.parse_args())
