"""Crop Issue #91 Blender inventory renders with shared anchors and state manifests."""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blueprints
import iso2x

STATES = ("FULL", "HALF", "EMPTY")
LAYERS = ("body", "products", "glass_front", "shadow")
PADDING = 8


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rect_union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True, help="Renderer output directory containing render_info.json and raw/")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    source = Path(args.raw).resolve()
    output = Path(args.out).resolve()
    output.mkdir(parents=True, exist_ok=True)
    info = json.loads((source / "render_info.json").read_text(encoding="utf-8"))
    raw = source / "raw"
    canvas_w, canvas_h = info["canvas_px"]
    origin_x, origin_y = info["origin_px"]
    fixture = info["fixture_type_id"]
    catalog_path = HERE.parents[1] / "data" / "fixtures" / "mvp_v1.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    definition = next(item for item in catalog if item["type_id"] == fixture)
    blueprint = blueprints.build(definition)
    calibration = raw / info["calibration"]["file"]
    Image.open(calibration).save(output / "calibration.png")

    manifest = {
        "manifest_version": 1,
        "visual_id": info["visual_id"],
        "fixture_type_id": fixture,
        "projection_id": iso2x.PROJECTION_ID,
        "world_units_per_tile": 1.0,
        "source_px_per_tile_diamond": list(iso2x.SOURCE_PX_PER_TILE_DIAMOND),
        "dimensions_m": definition["dimensions_m"],
        "footprint": definition["footprint"],
        "front": definition["access_edges"][0],
        "runtime_approved": False,
        "states": {},
        "composition_order": info["layer_order"],
        "note": "Per-state composite PNG is rendered as one Blender scene for correct depth. Separate layers are review/reference passes; their simple 2D stack is not a substitute for per-pixel depth occlusion.",
    }
    crops = {}
    for rotation in range(4):
        boxes = []
        for state in STATES:
            for layer in LAYERS + ("composite",):
                path = raw / ("%s_%s_r%d_%s.png" % (fixture, state.lower(), rotation, layer))
                with Image.open(path) as image:
                    bbox = image.getchannel("A").getbbox()
                    if bbox:
                        boxes.append(bbox)
        x0, y0, x1, y1 = rect_union(boxes)
        crop = (max(0, x0 - PADDING), max(0, y0 - PADDING), min(canvas_w, x1 + PADDING), min(canvas_h, y1 + PADDING))
        if crop[0] == 0 or crop[1] == 0 or crop[2] == canvas_w or crop[3] == canvas_h:
            raise SystemExit("rotation %d requires more render canvas/padding" % rotation)
        crops[rotation] = crop

    for state in STATES:
        state_record = {"rotations": {}}
        manifest["states"][state] = state_record
        for rotation in range(4):
            left, top, right, bottom = crops[rotation]
            anchor = [round(origin_x - left, 2), round(origin_y - top, 2)]
            layer_files = {}
            for layer in LAYERS + ("composite",):
                source_path = raw / ("%s_%s_r%d_%s.png" % (fixture, state.lower(), rotation, layer))
                filename = "%s_%s_r%d_%s.png" % (fixture, state.lower(), rotation, layer)
                with Image.open(source_path) as image:
                    if image.mode != "RGBA":
                        image = image.convert("RGBA")
                    image.crop((left, top, right, bottom)).save(output / filename, optimize=True)
                layer_files[layer] = filename
            rotated = blueprints.rotated(blueprint, definition, rotation)
            slots = {}
            for slot_id, items in rotated["slots"].items():
                if not items:
                    continue
                # One stable row-center anchor is metadata only; runtime does not scatter SKU sprites.
                _, (px, py, pz) = items[len(items) // 2]
                u, v = iso2x.project(px, py, pz)
                slots[slot_id] = [round(anchor[0] + u, 2), round(anchor[1] + v, 2)]
            fx0, fy0, fx1, fy1 = iso2x.rotated_footprint_rect(definition["footprint"]["w"], definition["footprint"]["h"], rotation)
            polygon = []
            for x, y in ((fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1)):
                u, v = iso2x.project(x, y, 0.0)
                polygon.append([round(anchor[0] + u, 2), round(anchor[1] + v, 2)])
            record = {
                "canvas_px": [right - left, bottom - top],
                "anchor_px": anchor,
                "layers": layer_files,
                "slot_anchors_px": slots,
                "selection_polygon_px": polygon,
                "sorting_anchor_px": anchor,
                "mesh_bbox": info["rotations"][state][str(rotation)]["mesh_bbox"],
                "products_bbox": info["rotations"][state][str(rotation)]["products_bbox"],
                "product_count": info["rotations"][state][str(rotation)]["product_count"],
            }
            state_record["rotations"][str(rotation)] = record

    manifest_path = output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # State rows, true 3D rotations in columns, all aligned around the same world origin.
    cell_w, cell_h, margin = 440, 470, 16
    sheet = Image.new("RGB", (margin + 4 * (cell_w + margin), margin + 3 * (cell_h + margin)), (221, 225, 228))
    draw = ImageDraw.Draw(sheet)
    for state_index, state in enumerate(STATES):
        for rotation in range(4):
            record = manifest["states"][state]["rotations"][str(rotation)]
            composite_path = output / record["layers"]["composite"]
            with Image.open(composite_path).convert("RGBA") as image:
                scale = min((cell_w - 32) / image.width, (cell_h - 60) / image.height, 1.0)
                thumb = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
            ax, ay = record["anchor_px"]
            x0 = margin + rotation * (cell_w + margin) + cell_w // 2 - round(ax * scale)
            y0 = margin + state_index * (cell_h + margin) + cell_h // 2 - round(ay * scale)
            sheet.paste(thumb, (x0, y0), thumb)
            draw.text((margin + rotation * (cell_w + margin) + 8, margin + state_index * (cell_h + margin) + 8), "%s / r%d" % (state, rotation), fill=(22, 30, 38))
            draw.line((x0 + round(ax * scale) - 8, y0 + round(ay * scale), x0 + round(ax * scale) + 8, y0 + round(ay * scale)), fill=(205, 30, 35), width=2)
            draw.line((x0 + round(ax * scale), y0 + round(ay * scale) - 8, x0 + round(ax * scale), y0 + round(ay * scale) + 8), fill=(205, 30, 35), width=2)
    sheet.save(output / "contact_sheet.png")

    # Side-by-side review against the existing Pillow-generated r0 FULL sprite.
    comparison = Image.new("RGB", (1120, 590), (231, 234, 237))
    compare_draw = ImageDraw.Draw(comparison)
    before_path = HERE.parents[1] / "assets" / "source" / "textures" / "fixtures" / "inventory_states" / fixture / (fixture + "_full_r0.png")
    for column, (label, path) in enumerate((("BEFORE / existing Pillow candidate", before_path), ("AFTER / calibrated Blender candidate", output / (fixture + "_full_r0_composite.png")))):
        with Image.open(path).convert("RGBA") as image:
            image.thumbnail((520, 510), Image.Resampling.LANCZOS)
            x = column * 560 + (560 - image.width) // 2
            y = 58 + (510 - image.height) // 2
            comparison.paste(image, (x, y), image)
        compare_draw.text((column * 560 + 18, 20), label, fill=(20, 30, 40))
    comparison.save(output / "before_after_full_r0.png")

    pngs = sorted(output.glob("*.png"))
    provenance = {
        "issue": "#91",
        "fixture_type_id": fixture,
        "generator": "Blender %s / BLENDER_EEVEE via tools/assets/render_inventory_fixture_states.py" % info["blender_version"],
        "crop_builder": "tools/assets/build_inventory_fixture_states.py",
        "projection_id": iso2x.PROJECTION_ID,
        "azimuth_deg": iso2x.AZIMUTH_DEG,
        "elevation_deg": iso2x.ELEVATION_DEG,
        "render_canvas_px": info["canvas_px"],
        "origin_px": info["origin_px"],
        "crop_padding_px": PADDING,
        "dimensions_m": definition["dimensions_m"],
        "footprint": definition["footprint"],
        "product_shape": "bottle_500; 0.068 x 0.068 x 0.225m; three fictional material palettes",
        "state_setup": {"FULL": "8 bottles per each of 3 shelves", "HALF": "4 bottles per each of 3 shelves", "EMPTY": "0 bottles"},
        "rotation_mesh_bbox": {state: {r: info["rotations"][state][r]["mesh_bbox"] for r in sorted(info["rotations"][state])} for state in STATES},
        "calibration": {"chart": "calibration.png", "measured_by": "tools/assets/validate_inventory_fixture_states.py", "status": "see validation_report.json"},
        "runtime_approved": False,
        "third_party_assets": False,
        "visual_review_required": True,
        "source_label_art": {name: {"path": "assets/source/textures/packages/candidates/issue91_beverage_label_art_v01/%s/label_art_v01.png" % name, "sha256": sha256(HERE.parents[1] / "assets" / "source" / "textures" / "packages" / "candidates" / "issue91_beverage_label_art_v01" / name / "label_art_v01.png")} for name in ("green_tea", "citrus_soda", "unsweetened_coffee")},
        "notes": "Composite is a single scene render with Blender depth occlusion; separated passes are not independently depth-aware. The ImageGen label art is UV-wrapped around the modeled 500ml bottle label band. Candidate label textures and generated packshot references are not runtime-approved.",
        "sha256": {path.name: sha256(path) for path in pngs},
    }
    (output / "provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("BUILT", len(pngs), "PNGs, manifest, provenance and contact sheet")


if __name__ == "__main__":
    main()
