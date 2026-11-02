extends SceneTree
## Measures deferred loading of the selected character-pilot textures.
## Run with a real renderer; this never changes the registry or approval state.
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tools/measure_character_pilot_load.gd -- build/character_pilot_load.json
## Add --all-pilot to measure all 50 registered runtime entries instead of the 11-image core set.

const REGISTRY_PATH := "res://data/presentation/character_visuals_v1.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var output_path := "user://character_pilot_load.json"
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with(".json"):
			output_path = arg
			break
	var registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if typeof(registry) != TYPE_DICTIONARY or typeof(registry.get("assets", null)) != TYPE_ARRAY:
		push_error("invalid character visual registry")
		quit(1)
		return
	var by_id := {}
	for raw_entry in registry["assets"]:
		if typeof(raw_entry) == TYPE_DICTIONARY:
			by_id[String(raw_entry.get("id", ""))] = raw_entry
	var ids: Array = registry.get("core_pilot_ids", [])
	if OS.get_cmdline_user_args().has("--all-pilot"):
		ids = by_id.keys()
		ids.sort()
	var before_mem := _video_mem_mb()
	var measurements: Array = []
	var loaded_count := 0
	var max_mem := before_mem
	for asset_id in ids:
		var entry: Dictionary = by_id.get(String(asset_id), {})
		var path := String(entry.get("runtime_path", ""))
		var started := Time.get_ticks_usec()
		var texture: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		var size := Vector2i.ZERO if texture == null else Vector2i(texture.get_width(), texture.get_height())
		if texture != null:
			loaded_count += 1
		await process_frame
		max_mem = maxf(max_mem, _video_mem_mb())
		measurements.append({
			"id": String(asset_id),
			"kind": String(entry.get("kind", "")),
			"runtime_path": path,
			"runtime_approved": bool(entry.get("runtime_approved", false)),
			"load_ms": elapsed_ms,
			"width": size.x,
			"height": size.y,
			"loaded": texture != null,
		})
		# Do not retain a local reference between entries; the route owns only the
		# currently displayed texture in the actual game.
		texture = null
	var total_ms := 0.0
	var max_load_ms := 0.0
	for item in measurements:
		total_ms += float(item["load_ms"])
		max_load_ms = maxf(max_load_ms, float(item["load_ms"]))
	var report := {
		"mode": "all_pilot" if OS.get_cmdline_user_args().has("--all-pilot") else "core_pilot",
		"entry_count": measurements.size(),
		"loaded_count": loaded_count,
		"all_runtime_approved": measurements.all(func(item): return bool(item["runtime_approved"])) if not measurements.is_empty() else false,
		"video_mem_before_mb": before_mem,
		"video_mem_peak_mb": max_mem,
		"total_load_ms": total_ms,
		"max_load_ms": max_load_ms,
		"measurements": measurements,
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	quit(0)


func _video_mem_mb() -> float:
	return float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0
