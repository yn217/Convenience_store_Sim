extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_all.gd
## Discovers tests/{unit,contract,scenario,scene}/test_*.gd and runs every test_* method.
## Exit code 0 = all passed, 1 = failures, 2 = no tests found.

const SUITES := ["unit", "contract", "scenario", "scene"]
const Ctx := preload("res://tests/support/test_context.gd")


func _initialize() -> void:
	_run()


## `-- --only=<text>` runs only the test files whose name contains <text> (for one-off checks).
func _only_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=")
	return ""


func _run() -> void:
	var ctx := Ctx.new()
	var test_count := 0
	for suite in SUITES:
		var dir := DirAccess.open("res://tests/%s" % suite)
		if dir == null:
			continue
		var only := _only_filter()
		var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and (only == "" or f.contains(only)))
		files.sort()
		for file in files:
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
				print("ran %s (%d ms)" % [ctx.current, Time.get_ticks_msec() - t0])
	for f in ctx.failures:
		printerr("FAIL ", f)
	print("tests=%d assertions=%d failures=%d" % [test_count, ctx.assertions, ctx.failures.size()])
	quit(2 if test_count == 0 else (1 if ctx.failures.size() > 0 else 0))
