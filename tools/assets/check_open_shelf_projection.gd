extends SceneTree
## Limited Issue #171 projection check. Does not run the game test suite.
func _initialize() -> void:
	var p = load("res://scripts/presentation/iso_projection.gd").new()
	var path := "res://assets/review/guided_assets/shelf_general_open_r0_v1/guide.json"
	var guide = JSON.parse_string(FileAccess.get_file_as_string(path))
	var anchor := Vector2(guide.anchor_px[0], guide.anchor_px[1])
	var count := 0
	var max_error := 0.0
	for part in guide.parts:
		for i in part.vertices_world.size():
			var v = part.vertices_world[i]
			var expected = p.world_to_screen(v[0], v[1], v[2]) * p.SOURCE_SCALE + anchor
			var actual = Vector2(part.vertices_px[i][0], part.vertices_px[i][1])
			max_error = maxf(max_error, expected.distance_to(actual))
			count += 1
	var report := {"vertices_checked": count, "max_source_pixel_error": max_error,
		"pass": max_error <= 0.001, "scope": "runtime projection numeric comparison only; no visual approval"}
	var output := FileAccess.open("res://assets/review/guided_assets/shelf_general_open_r0_v1/projection_check.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if report.pass else 1)
