class_name FloorStyle
extends RefCounted
## Issue #61 (floor): procedural look of the store floor, as pure static helpers.
## Warm cream tiles with a deterministic +-3% variation per tile, a slightly darker walkway band that
## runs from the entrance, an entrance mat, grout lines, a soft sheen across the floor, ambient occlusion
## along the walls and contact shadows under every fixture footprint. StoreWorld draws these inside its
## own floor pass, which only repeats when the layout, the camera or the viewport changes (floor key).
## Shadows are computed in world space and cached by layout signature; nothing here draws per frame.

const TILE_BASE := Color(0.925, 0.900, 0.840)
const TILE_AISLE := Color(0.835, 0.800, 0.715)
const TILE_MAT := Color(0.330, 0.300, 0.275)
const MAT_INSET := Color(0.500, 0.460, 0.420, 0.9)
const GROUT := Color(0.700, 0.665, 0.610, 0.85)
const SHEEN_ALPHA := 0.16
const VARIATION := 0.03
const AO_COLOR := Color(0.250, 0.180, 0.120)
const AO_ALPHA := 0.22
const AO_DEPTH := 0.45
const MAT_INSET_M := 0.12
const SHADOW_OFFSET := Vector2(0.16, 0.12)   ## world tiles, away from the overhead light (toward the viewer)
const SHADOW_COLOR := Color(0.330, 0.270, 0.210)
## [scale about the footprint centre, alpha]; stacked layers make a soft-edged contact shadow.
const SHADOW_LAYERS := [[1.04, 0.06], [0.88, 0.09], [0.70, 0.11]]


## Deterministic hash of a tile index in [0, 1). Same inputs always give the same value.
static func hash01(x: int, y: int, salt: int = 0) -> float:
	var h: int = ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65536.0


## Rows of the walkway band: the entrance rows (widened to two rows for a single entrance tile).
static func aisle_rows(entrances: Array) -> Array:
	var rows: Array = []
	if entrances.is_empty():
		return rows
	var lo := 1 << 30
	var hi := -1
	for e in entrances:
		lo = mini(lo, int(e.y))
		hi = maxi(hi, int(e.y))
	if lo == hi:
		hi += 1
	for y in range(lo, hi + 1):
		rows.append(y)
	return rows


## "mat" for entrance tiles, "aisle" for the walkway band (east of the entrance), otherwise "tile".
static func tile_kind(c: Vector2i, entrances: Array) -> StringName:
	for e in entrances:
		if e == c:
			return &"mat"
	if c.x >= 1 and aisle_rows(entrances).has(c.y):
		return &"aisle"
	return &"tile"


## Fill colour of one floor tile: the kind's base colour with a +-VARIATION shift from the tile hash.
static func tile_color(c: Vector2i, entrances: Array) -> Color:
	var base: Color = TILE_BASE
	match tile_kind(c, entrances):
		&"mat":
			base = TILE_MAT
		&"aisle":
			base = TILE_AISLE
	var k := (hash01(c.x, c.y) - 0.5) * 2.0 * VARIATION
	return Color(base.r * (1.0 + k), base.g * (1.0 + k), base.b * (1.0 + k), 1.0)


## Grout: the four edges of every floor tile, as one flat list of segment end points (draw_multiline).
static func grout_segments(proj: IsoProjection, width: int, height: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for y in height:
		for x in width:
			var corners := [
				proj.world_to_screen(x - 0.5, y - 0.5), proj.world_to_screen(x + 0.5, y - 0.5),
				proj.world_to_screen(x + 0.5, y + 0.5), proj.world_to_screen(x - 0.5, y + 0.5),
			]
			for i in 4:
				out.append(corners[i])
				out.append(corners[(i + 1) % 4])
	return out


## Soft light across the whole floor: strongest in the far corner, fading toward the viewer.
## -> {"points": PackedVector2Array, "colors": PackedColorArray} for draw_polygon.
static func sheen(proj: IsoProjection, width: int, height: int) -> Dictionary:
	var pts := PackedVector2Array([
		proj.world_to_screen(-0.5, -0.5), proj.world_to_screen(width - 0.5, -0.5),
		proj.world_to_screen(width - 0.5, height - 0.5), proj.world_to_screen(-0.5, height - 0.5),
	])
	var a := SHEEN_ALPHA
	var cols := PackedColorArray([
		Color(1, 1, 1, a), Color(1, 1, 1, a * 0.3), Color(1, 1, 1, 0.0), Color(1, 1, 1, a * 0.3),
	])
	return {"points": pts, "colors": cols}


## Ambient occlusion where the floor meets the two far walls: a dark gradient strip fading inward.
## -> Array of {"points", "colors"} (see sheen).
static func wall_ao(proj: IsoProjection, width: int, height: int) -> Array:
	var out: Array = []
	var dark := Color(AO_COLOR, AO_ALPHA)
	var clear := Color(AO_COLOR, 0.0)
	out.append({
		"points": PackedVector2Array([
			proj.world_to_screen(-0.5, -0.5), proj.world_to_screen(width - 0.5, -0.5),
			proj.world_to_screen(width - 0.5, -0.5 + AO_DEPTH), proj.world_to_screen(-0.5, -0.5 + AO_DEPTH),
		]),
		"colors": PackedColorArray([dark, dark, clear, clear]),
	})
	out.append({
		"points": PackedVector2Array([
			proj.world_to_screen(-0.5, -0.5), proj.world_to_screen(-0.5 + AO_DEPTH, -0.5),
			proj.world_to_screen(-0.5 + AO_DEPTH, height - 0.5), proj.world_to_screen(-0.5, height - 0.5),
		]),
		"colors": PackedColorArray([dark, clear, clear, dark]),
	})
	return out


## Inset outline of a tile (closed polygon) used for the entrance mat border.
static func tile_inset(proj: IsoProjection, c: Vector2i) -> PackedVector2Array:
	var e := 0.5 - MAT_INSET_M
	return PackedVector2Array([
		proj.world_to_screen(c.x - e, c.y - e), proj.world_to_screen(c.x + e, c.y - e),
		proj.world_to_screen(c.x + e, c.y + e), proj.world_to_screen(c.x - e, c.y + e),
	])


## Cheap identity of the fixtures that matter for the floor (positions, types, rotation).
## Equal signatures mean the floor and the shadows can be reused.
static func layout_signature(fixtures: Array) -> Array:
	var sig: Array = []
	for inst in fixtures:
		sig.append([inst["instance_id"], inst["type_id"], inst["x"], inst["y"], inst["rotation"]])
	return sig


## Contact shadows in WORLD space, one entry per layer: {"points": PackedVector2Array, "alpha": float}.
## The offset grows a little with fixture height (taller cases throw longer shadows).
static func fixture_shadows(fixtures: Array, catalog: FixtureCatalog) -> Array:
	var out: Array = []
	if catalog == null:
		return out
	for inst in fixtures:
		var def: Dictionary = catalog.get_type(inst["type_id"])
		if def.is_empty():
			continue
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		if cells.is_empty():
			continue
		var pts := PackedVector2Array()
		var centre := Vector2.ZERO
		for c in cells:
			centre += Vector2(c)
			for dx in [-0.5, 0.5]:
				for dy in [-0.5, 0.5]:
					pts.append(Vector2(c) + Vector2(dx, dy))
		centre /= cells.size()
		var hull := Geometry2D.convex_hull(pts)
		var height := float(def["dimensions_m"]["height"])
		var offset := SHADOW_OFFSET * clampf(height, 0.6, 1.6)
		for layer in SHADOW_LAYERS:
			var poly := PackedVector2Array()
			for p in hull:
				poly.append(centre + (p - centre) * float(layer[0]) + offset)
			out.append({"points": poly, "alpha": float(layer[1])})
	return out


## Projects world-space points to screen space.
static func project(proj: IsoProjection, world_pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in world_pts:
		out.append(proj.world_to_screen(p.x, p.y))
	return out


## Draws shadow layers (from fixture_shadows) on a CanvasItem with the given projection.
static func draw_shadows(canvas: CanvasItem, proj: IsoProjection, shadows: Array) -> void:
	for s in shadows:
		canvas.draw_colored_polygon(project(proj, s["points"]), Color(SHADOW_COLOR, float(s["alpha"])))
