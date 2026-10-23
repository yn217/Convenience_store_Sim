extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_all.gd
## Discovers tests/{unit,contract,scenario,scene}/test_*.gd and runs every test_* method.
## Exit code 0 = all passed, 1 = failures, 2 = no tests found.

const SUITES := ["unit", "contract", "scenario", "scene"]
const Ctx := preload("res://tests/support/test_context.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var ctx := Ctx.new()
	var test_count := 0
	for suite in SUITES:
		var dir := DirAccess.open("res://tests/%s" % suite)
		if dir == null:
			continue
		var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
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
				await inst.call(name, ctx, self)
				print("ran ", ctx.current)
	for f in ctx.failures:
		printerr("FAIL ", f)
	print("tests=%d assertions=%d failures=%d" % [test_count, ctx.assertions, ctx.failures.size()])
	quit(2 if test_count == 0 else (1 if ctx.failures.size() > 0 else 0))
