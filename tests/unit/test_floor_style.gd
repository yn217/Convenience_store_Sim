extends RefCounted
## Issue #61 (floor): procedural floor look - deterministic tile variation, aisle band, entrance mat,
## grout, wall occlusion and fixture contact shadows (cached in world space by layout signature).


func _proj(zoom: float = 1.0) -> IsoProjection:
	var p := IsoProjection.new()
	p.origin = Vector2(1000, 200)
	p.set_zoom(zoom)
	return p


func _catalog() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))


func _luma(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


func test_hash_is_deterministic_and_in_range(t, _tree) -> void:
	var seen := {}
	var ok := true
	for x in 16:
		for y in 12:
			var v := FloorStyle.hash01(x, y)
			if v < 0.0 or v >= 1.0:
				ok = false
			if v != FloorStyle.hash01(x, y):
				ok = false
			seen[snappedf(v, 0.0001)] = true
	t.ok(ok, "hash01 stays in [0, 1) and repeats for the same tile")
	t.ok(seen.size() > 150, "hash01 spreads 192 tiles over many values (no visible repeat pattern)")


func test_tile_variation_is_subtle(t, _tree) -> void:
	var lo := 1.0
	var hi := 0.0
	for x in 16:
		for y in 12:
			var c := FloorStyle.tile_color(Vector2i(x, y), [])
			lo = minf(lo, _luma(c))
			hi = maxf(hi, _luma(c))
	var base := _luma(FloorStyle.TILE_BASE)
	t.ok(absf(lo / base - 1.0) <= FloorStyle.VARIATION + 0.001, "darkest tile is within 3% of the base")
	t.ok(absf(hi / base - 1.0) <= FloorStyle.VARIATION + 0.001, "lightest tile is within 3% of the base")
	t.ok(hi - lo > 0.0, "tiles are not all identical")


func test_warm_daylight_colours(t, _tree) -> void:
	for c in [FloorStyle.TILE_BASE, FloorStyle.TILE_AISLE]:
		t.ok(c.r >= c.g and c.g >= c.b, "floor tones are warm (r >= g >= b)")
		t.ok(_luma(c) > 0.7, "floor tones are light enough for daylight")


func test_aisle_band_runs_from_entrance(t, _tree) -> void:
	var ent := [Vector2i(0, 5), Vector2i(0, 6)]
	t.eq(FloorStyle.aisle_rows(ent), [5, 6], "aisle rows are the entrance rows")
	t.eq(FloorStyle.aisle_rows([Vector2i(0, 4)]), [4, 5], "a single entrance widens to two aisle rows")
	t.eq(FloorStyle.aisle_rows([]), [], "no entrance, no aisle")
	t.eq(FloorStyle.tile_kind(Vector2i(3, 5), ent), &"aisle", "walkway tile east of the entrance")
	t.eq(FloorStyle.tile_kind(Vector2i(3, 9), ent), &"tile", "tiles off the walkway are plain tiles")


func test_entrance_mat_is_dark(t, _tree) -> void:
	var ent := [Vector2i(0, 5)]
	t.eq(FloorStyle.tile_kind(Vector2i(0, 5), ent), &"mat", "entrance tile is the mat")
	t.ok(_luma(FloorStyle.tile_color(Vector2i(0, 5), ent)) < _luma(FloorStyle.TILE_BASE) * 0.6, "mat is clearly darker than the floor")


func test_grout_has_four_edges_per_tile(t, _tree) -> void:
	var segs := FloorStyle.grout_segments(_proj(), 3, 2)
	t.eq(segs.size(), 3 * 2 * 4 * 2, "each tile contributes four segments (two points each)")


func test_sheen_and_wall_occlusion_have_matching_colours(t, _tree) -> void:
	var s := FloorStyle.sheen(_proj(), 16, 12)
	t.eq(s["points"].size(), s["colors"].size(), "sheen has one colour per vertex")
	var ao := FloorStyle.wall_ao(_proj(), 16, 12)
	t.eq(ao.size(), 2, "one occlusion strip per far wall")
	for strip in ao:
		t.eq(strip["points"].size(), strip["colors"].size(), "occlusion strip has one colour per vertex")
		t.ok(strip["colors"][0].a > strip["colors"][2].a, "occlusion is strongest at the wall and fades inward")


func test_layout_signature_changes_only_with_fixtures(t, _tree) -> void:
	var a := [{"instance_id": "f1", "type_id": "shelf_general", "x": 3, "y": 2, "rotation": 0}]
	var same := [{"instance_id": "f1", "type_id": "shelf_general", "x": 3, "y": 2, "rotation": 0}]
	var moved := [{"instance_id": "f1", "type_id": "shelf_general", "x": 4, "y": 2, "rotation": 0}]
	t.ok(FloorStyle.layout_signature(a) == FloorStyle.layout_signature(same), "identical layouts share a signature")
	t.ok(FloorStyle.layout_signature(a) != FloorStyle.layout_signature(moved), "moving a fixture changes the signature")
	t.ok(FloorStyle.layout_signature([]) != FloorStyle.layout_signature(a), "removing a fixture changes the signature")


func test_shadows_are_offset_away_from_the_light(t, _tree) -> void:
	var cat := _catalog()
	var fixtures := [{"instance_id": "f1", "type_id": "shelf_general", "x": 3, "y": 2, "rotation": 0}]
	var shadows := FloorStyle.fixture_shadows(fixtures, cat)
	if shadows.is_empty():
		t.ok(false, "a known fixture type produces shadows")
		return
	var centre := Vector2(3, 2)
	var pts: PackedVector2Array = shadows[0]["points"]
	var mean := Vector2.ZERO
	for p in pts:
		mean += p
	mean /= pts.size()
	t.ok(mean.x > centre.x and mean.y > centre.y, "shadow centre sits toward +x/+y (away from the north-west light)")
	t.eq(shadows.size(), FloorStyle.SHADOW_LAYERS.size(), "one entry per soft shadow layer")


func test_shadow_cache_is_world_space(t, _tree) -> void:
	# World-space shadows do not depend on the camera: the same list projects at any zoom.
	var cat := _catalog()
	var fixtures := [{"instance_id": "f1", "type_id": "shelf_general", "x": 3, "y": 2, "rotation": 0}]
	var shadows := FloorStyle.fixture_shadows(fixtures, cat)
	var a :=FloorStyle.project(_proj(1.0), shadows[0]["points"])
	var b := FloorStyle.project(_proj(2.0), shadows[0]["points"])
	t.ok(a[0] != b[0], "projection follows the zoom while the cached world points stay put")


func test_no_shadows_without_catalog(t, _tree) -> void:
	t.eq(FloorStyle.fixture_shadows([{"instance_id": "f1", "type_id": "x", "x": 0, "y": 0, "rotation": 0}], null).size(), 0, "no catalog, no shadows")
