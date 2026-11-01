extends RefCounted
## Issue #8 from the Godot side: the generated manifests can be read by the game and point at
## real RGBA images of the stated size, and the Godot sprite-placement formula puts the anchor
## on the ground point (02 §E).

const DIR := "res://assets/generated/fixtures"
const TYPES := ["shelf_general", "warmer_oden", "freezer_ice", "register_basic", "fridge_drink", "shelf_onigiri", "shelf_noodle", "shelf_bread", "shelf_snack", "fridge_dessert", "atm", "copier"]


func _manifest(type_id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s_a.visual.json" % [DIR, type_id, type_id]))


func test_manifests_match_the_catalog_and_files_exist(t, _tree) -> void:
	var fixtures := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	for type_id in TYPES:
		var m := _manifest(type_id)
		var def := fixtures.get_type(type_id)
		t.eq(m["visual_id"], def["visual_id"], "%s visual_id" % type_id)
		t.eq(m["projection_id"], "iso2x_v1")
		t.eq(int(m["footprint"]["w"]), def["footprint"]["w"])
		t.eq(int(m["footprint"]["h"]), def["footprint"]["h"])
		t.eq(m["rotations"].keys().size(), 4, "%s has 4 rotations" % type_id)
		for r in ["0", "1", "2", "3"]:
			var rot: Dictionary = m["rotations"][r]
			for layer in rot["layers"]:
				var tex := load("%s/%s/%s" % [DIR, type_id, rot["layers"][layer]]) as Texture2D
				t.ok(tex != null, "%s r%s %s imports as a texture" % [type_id, r, layer])
				if tex == null:
					continue
				var img := tex.get_image()
				t.eq(img.get_width(), int(rot["canvas_px"][0]), "%s r%s %s width" % [type_id, r, layer])
				t.eq(img.get_height(), int(rot["canvas_px"][1]), "%s r%s %s height" % [type_id, r, layer])
				t.ok(img.detect_alpha() != Image.ALPHA_NONE, "%s r%s %s has alpha" % [type_id, r, layer])


func test_anchor_lands_on_the_ground_point_at_every_zoom(t, _tree) -> void:
	var proj := IsoProjection.new()
	proj.origin = Vector2(1000, 200)
	for type_id in TYPES:
		var rot: Dictionary = _manifest(type_id)["rotations"]["0"]
		var anchor := Vector2(rot["anchor_px"][0], rot["anchor_px"][1])
		for zoom in [0.5, 1.0, 2.0]:
			proj.set_zoom(zoom)
			var ground := proj.world_to_screen(4, 5)
			var top_left := proj.sprite_top_left(ground, anchor)
			t.ok((top_left + anchor * (zoom / 2.0)).distance_to(ground) < 0.01, "%s zoom %s" % [type_id, str(zoom)])


func test_selection_polygon_is_the_projected_footprint(t, _tree) -> void:
	var proj := IsoProjection.new()
	for type_id in TYPES:
		var m := _manifest(type_id)
		var w := int(m["footprint"]["w"])
		var h := int(m["footprint"]["h"])
		for r in 4:
			var rot: Dictionary = m["rotations"][str(r)]
			var rw := w if r % 2 == 0 else h
			var rh := h if r % 2 == 0 else w
			var anchor := Vector2(rot["anchor_px"][0], rot["anchor_px"][1])
			var corners := [Vector2(-0.5, -0.5), Vector2(rw - 0.5, -0.5), Vector2(rw - 0.5, rh - 0.5), Vector2(-0.5, rh - 0.5)]
			for i in 4:
				var want: Vector2 = anchor + Vector2(128.0 * (corners[i].x - corners[i].y), 64.0 * (corners[i].x + corners[i].y))
				var got := Vector2(rot["selection_polygon_px"][i][0], rot["selection_polygon_px"][i][1])
				t.ok(got.distance_to(want) < 0.02, "%s r%d corner %d" % [type_id, r, i])
	t.ok(proj != null)
