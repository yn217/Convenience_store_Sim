class_name SaveStore
extends RefCounted
## Crash-safe save files (09 §6): the new data is written to `<slot>.tmp`, read back and parsed,
## then the previous save is kept as `<slot>.bak` before the temp file takes its place. A file
## that cannot be read or validated is reported, never overwritten, and never half-applied.
## Two generations (current + backup) are kept.

const DIR := "user://saves"
const SLOTS := ["slot_1", "slot_2", "slot_3"]


static func path_for(slot_id: String, dir: String = DIR) -> String:
	return "%s/%s.json" % [dir, slot_id]


## Returns {"ok": bool, "error": String}.
static func write(slot_id: String, data: Dictionary, dir: String = DIR) -> Dictionary:
	if not SLOTS.has(slot_id):
		return {"ok": false, "error": "unknown_slot"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := path_for(slot_id, dir)
	var tmp := path + ".tmp"
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "cannot_write_temp"}
	f.store_string(text)
	f.flush()
	f.close()
	var check := JSON.new()
	if check.parse(FileAccess.get_file_as_string(tmp)) != OK or typeof(check.data) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "error": "temp_verification_failed"}
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return {"ok": false, "error": "cannot_keep_backup"}
	if DirAccess.rename_absolute(tmp, path) != OK:
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, path)   # put the previous save back
		return {"ok": false, "error": "cannot_replace"}
	return {"ok": true, "error": ""}


## Parsed JSON of the slot (or its backup when `use_backup`). {"ok", "data", "error"}.
static func read(slot_id: String, use_backup: bool = false, dir: String = DIR) -> Dictionary:
	if not SLOTS.has(slot_id):
		return {"ok": false, "data": null, "error": "unknown_slot"}
	var path := path_for(slot_id, dir) + (".bak" if use_backup else "")
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "error": "no_save"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "data": null, "error": "corrupt_json"}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": null, "error": "not_object"}
	return {"ok": true, "data": json.data, "error": ""}


static func has_save(slot_id: String, dir: String = DIR) -> bool:
	return FileAccess.file_exists(path_for(slot_id, dir))


## The slot saved last (by file time), or "" when there is no save (#20: 直近の正常なセーブ).
static func latest_slot(dir: String = DIR) -> String:
	var best := ""
	var best_time := -1
	for id in SLOTS:
		if has_save(id, dir):
			var time := FileAccess.get_modified_time(path_for(id, dir))
			if time > best_time:
				best_time = time
				best = id
	return best


static func has_backup(slot_id: String, dir: String = DIR) -> bool:
	return FileAccess.file_exists(path_for(slot_id, dir) + ".bak")
