"""Static dependency-direction check (docs/design/PROJECT_DIRECTORY_STRUCTURE.md "依存方向").

domain       -> nothing outside scripts/domain, no SceneTree/Node API, no global RNG
application  -> domain only (no presentation, no Node-based scene access)
presentation -> application snapshots / domain read-only types
Usage: python check_layering.py <repo root>
"""
import re
import sys
from pathlib import Path

NODE_API = re.compile(r"\b(extends\s+(Node|Node2D|Control|CanvasItem|SceneTree)\b|get_tree\(|get_node\(|\$[A-Za-z_/]+|SceneTree)")
GLOBAL_RNG = re.compile(r"\b(randf|randi|randf_range|randi_range|randomize|seed|RandomNumberGenerator)\b\s*\(?")
RES_REF = re.compile(r"res://scripts/(domain|application|presentation)/")
ENGINE_COMMENT = re.compile(r"#.*$")

# Identifiers of each layer, used to catch typed cross-layer references without imports.
LAYER_CLASSES = {
    "presentation": re.compile(r"\b(StoreWorld|FixturePresenter|CustomerPresenter|IsoProjection)\b"),
    "application": re.compile(r"\b(GameState|GameCommands|CommandResult|SimulationRunner|SaveManager|ScenarioFactory)\b"),
}

FORBIDDEN = {
    "domain": ("application", "presentation"),
    "application": ("presentation",),
}


def strip(line: str) -> str:
    return ENGINE_COMMENT.sub("", line)


def main(root: Path) -> int:
    errors = []
    for layer, banned in FORBIDDEN.items():
        for path in sorted((root / "scripts" / layer).rglob("*.gd")):
            for no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                line = strip(raw)
                where = f"{path.relative_to(root)}:{no}"
                for m in RES_REF.finditer(line):
                    if m.group(1) in banned:
                        errors.append(f"{where}: {layer} must not depend on {m.group(1)}")
                for b in banned:
                    # app_root.gd is the boot/DI node (01 §5) and wires presenters by node path.
                    if path.name == "app_root.gd" and b == "presentation":
                        continue
                    if LAYER_CLASSES[b].search(line):
                        errors.append(f"{where}: {layer} references {b} type")
                if GLOBAL_RNG.search(line) and "Lcg32" not in line:
                    errors.append(f"{where}: global RNG forbidden in {layer}")
                if layer == "domain" and NODE_API.search(line):
                    errors.append(f"{where}: domain must not touch SceneTree/Node API")
    # AppRoot is the only application script allowed to touch scene nodes (boot/DI).
    for path in sorted((root / "scripts" / "application").rglob("*.gd")):
        if path.name == "app_root.gd":
            continue
        for no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if NODE_API.search(strip(raw)):
                errors.append(f"{path.relative_to(root)}:{no}: only app_root.gd may use Node API")
    for e in errors:
        print("LAYERING:", e)
    print(f"layering check: {len(errors)} violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()))
