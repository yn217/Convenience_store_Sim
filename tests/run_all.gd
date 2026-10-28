extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_all.gd
## Discovers tests/{unit,contract,scenario,scene}/test_*.gd and runs every test_* method.
## Exit code 0 = all passed, 1 = failures, 2 = no tests found.

const SUITES := ["unit", "contract", "scenario", "scene"]
const Ctx := preload("res://tests/support/test_context.gd")


## Script errors inside a test (an index out of range, a null call) stop that test without failing an assertion;
## this logger collects them so the test is counted as failed.
class ScriptErrors extends Logger:
	var _lock := Mutex.new()
	var _seen: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		_seen.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_lock.unlock()

	func take() -> Array[String]:
		_lock.lock()
		var out := _seen.duplicate()
		_seen.clear()
		_lock.unlock()
		return out


func _initialize() -> void:
	_run()


## `-- --shard=k/n` runs the k-th of n parts of the test files (0-based, files dealt out in turn), so
## tools/run_tests.ps1 can run the parts in parallel processes.
func _shard() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shard="):
			var p := arg.trim_prefix("--shard=").split("/")
			return Vector2i(int(p[0]), maxi(int(p[1]), 1))
	return Vector2i(0, 1)


## `-- --only=<text>` runs only the test files whose name contains <text> (for one-off checks).
func _only_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=")
	return ""


func _run() -> void:
	var ctx := Ctx.new()
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	var test_count := 0
	var shard := _shard()
	var file_no := -1
	for suite in SUITES:
		var dir := DirAccess.open("res://tests/%s" % suite)
		if dir == null:
			continue
		var only := _only_filter()
		var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and (only == "" or f.contains(only)))
		files.sort()
		for file in files:
			file_no += 1
			if file_no % shard.y != shard.x:
				continue
			var script := load("res://tests/%s/%s" % [suite, file]) as GDScript
			var inst = script.new()
			for method in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				ctx.current = "%s/%s::%s" % [suite, file, name]
				test_count += 1
				var t0 := Time.get_ticks_msec()
				await inst.call(name, ctx, self)
				for e in errors.take():
					ctx.failures.append("%s: script error: %s" % [ctx.current, e])
				print("ran %s (%d ms)" % [ctx.current, Time.get_ticks_msec() - t0])
	for f in ctx.failures:
		printerr("FAIL ", f)
	print("tests=%d assertions=%d failures=%d" % [test_count, ctx.assertions, ctx.failures.size()])
	quit(2 if test_count == 0 else (1 if ctx.failures.size() > 0 else 0))
