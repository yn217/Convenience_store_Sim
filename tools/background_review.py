"""Archive real Godot captures and make a labeled comparison with the supplied mockup."""
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / "build/exterior-review"
DEST = ROOT / "docs/qa/exterior-2026-10-27"


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    source_files = {
        "before_1600x900.png": CAPTURES / "pre_combined_whole.png",
        "angle_before_1600x900.png": CAPTURES / "combined_backdrop_ordered.png",
        "after_1600x900.png": CAPTURES / "combined_v_occluded.png",
        "after_1280x720.png": CAPTURES / "combined_v_1280x720.png",
        "after_1920x1080.png": CAPTURES / "combined_v_1920x1080.png",
        "large_store_1600x900.png": CAPTURES / "combined_v_large_store.png",
        "night_1600x900.png": CAPTURES / "combined_v_night.png",
        "build_preview_1600x900.png": CAPTURES / "combined_v_build.png",
        "default_camera_1600x900.png": CAPTURES / "combined_v_default.png",
        "zoom_pan_1600x900.png": CAPTURES / "combined_v_zoom_pan.png",
    }
    for name, source in source_files.items():
        expected = (1280, 720) if "1280x720" in name else (1920, 1080) if "1920x1080" in name else (1600, 900)
        with Image.open(source) as im:
            if im.size != expected:
                raise ValueError(f"Unexpected capture size: {source}: {im.size} != {expected}")
        if source.stat().st_size < 10000:
            raise ValueError(f"Empty capture: {source}")
        shutil.copy2(source, DEST / name)

    target = ROOT / "docs/qa/exterior-2026-10-26/02_target/target_full.png"
    images = [Image.open(source_files["before_1600x900.png"]).convert("RGB"),
              Image.open(target).convert("RGB"),
              Image.open(source_files["after_1600x900.png"]).convert("RGB")]
    board = Image.new("RGB", (1920, 388), "#e8e8e1")
    draw = ImageDraw.Draw(board)
    for i, (im, label) in enumerate(zip(images, ("BEFORE / actual game", "TARGET / supplied mockup", "AFTER / actual game"))):
        fitted = ImageOps.contain(im, (640, 360), Image.Resampling.LANCZOS)
        x = i * 640
        draw.text((x + 10, 7), label, fill="#243747")
        board.paste(fitted, (x + (640 - fitted.width) // 2, 27 + (360 - fitted.height) // 2))
    board.save(DEST / "before_target_after.png")
    angle_board = Image.new("RGB", (1600, 478), "#e8e8e1")
    angle_draw = ImageDraw.Draw(angle_board)
    for i, (name, label) in enumerate((("angle_before_1600x900.png", "BEFORE / horizontal U-shaped planting"), ("after_1600x900.png", "AFTER / planting follows both far walls"))):
        with Image.open(source_files[name]) as im:
            fitted = ImageOps.contain(im.convert("RGB"), (800, 450), Image.Resampling.LANCZOS)
        x = i * 800
        angle_draw.text((x + 10, 7), label, fill="#243747")
        angle_board.paste(fitted, (x + (800 - fitted.width) // 2, 27 + (450 - fitted.height) // 2))
    angle_board.save(DEST / "angle_before_after.png")
    print(f"Archived {len(source_files)} real captures and comparison in {DEST}")


if __name__ == "__main__":
    main()
