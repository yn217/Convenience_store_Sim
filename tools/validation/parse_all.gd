extends SceneTree
## GDScript parse check in one Godot process (replaces one `--check-only` launch per file, about 1.7 s each):
## loads every .gd under res://scripts, res://tests and res://tools without the cache and fails on any script that
## does not load or cannot be instantiated. Exit code 0 = all parse, 1 = errors.


func _initialize() -> void:
	var failed: Array[String] = []
	var n := 0
	for root in ["res://scripts", "res://tests", "res://tools"]:
		for path in _scripts(root):
			if path == get_script().resource_path:
				continue   # this script is running: reloading it would break it
			n += 1
			var s = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
				failed.append(path)
	for path in failed:
		printerr("parse error: ", path)
	print("parse check: %d scripts, %d error(s)" % [n, failed.size()])
	quit(1 if not failed.is_empty() else 0)


func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with("."):
			out.append_array(_scripts(dir_path.path_join(d)))
	return out
