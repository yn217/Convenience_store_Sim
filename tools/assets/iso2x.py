"""iso2x_v1 projection + rotation math shared by the Blender renderer, the sprite builder and
the validator (docs/implementation/02_GRID_AND_ASSET_CONTRACT.md §A, §D). Pure Python, no deps.

Game coordinates: x east, y south, z up, 1 unit = 1 m, local cell (0,0) centre at the origin.
Source pixels: +X 1 m -> (+128, +64), +Y 1 m -> (-128, +64), +Z 1 m -> (0, -156.76734354).
"""
import math

PROJECTION_ID = "iso2x_v1"
SOURCE_PX_PER_TILE_DIAMOND = (256, 128)
Z_PX_PER_M = 156.76734354
ELEVATION_DEG = 30.0
AZIMUTH_DEG = 45.0
# Source px per metre along the camera's horizontal axis: a 1 m step in X is 128 px across.
PX_PER_M_ORTHO = 128.0 * math.sqrt(2.0)
EDGES = ("N", "E", "S", "W")


def project(x, y, z=0.0):
    """Game-space point -> source-pixel offset from the world origin (y grows downward)."""
    return (128.0 * (x - y), 64.0 * (x + y) - Z_PX_PER_M * z)


def rotate_point(x, y, rotation):
    """Clockwise quarter turns on screen (E -> S -> W -> N), about the local origin."""
    r = rotation % 4
    if r == 0:
        return (x, y)
    if r == 1:
        return (-y, x)
    if r == 2:
        return (-x, -y)
    return (y, -x)


def footprint_rect(w, h):
    return (-0.5, -0.5, w - 0.5, h - 0.5)


def rotated_footprint_rect(w, h, rotation):
    """Footprint rect after rotation, translated so its min cell is the new local cell (0,0)."""
    x0, y0, x1, y1 = footprint_rect(w, h)
    pts = [rotate_point(px, py, rotation) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    min_x = min(p[0] for p in pts)
    min_y = min(p[1] for p in pts)
    dx, dy = -0.5 - min_x, -0.5 - min_y
    xs = [p[0] + dx for p in pts]
    ys = [p[1] + dy for p in pts]
    return (min(xs), min(ys), max(xs), max(ys))


def rotation_offset(w, h, rotation):
    """Translation applied after rotating, so the min cell of the rotated footprint is (0,0)."""
    x0, y0, x1, y1 = footprint_rect(w, h)
    pts = [rotate_point(px, py, rotation) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    return (-0.5 - min(p[0] for p in pts), -0.5 - min(p[1] for p in pts))


def transform_point(x, y, w, h, rotation):
    rx, ry = rotate_point(x, y, rotation)
    dx, dy = rotation_offset(w, h, rotation)
    return (rx + dx, ry + dy)


def rotate_edge(edge, rotation):
    return EDGES[(EDGES.index(edge) + rotation) % 4]
