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


## `-- --shard=k/n` runs the k-th of n parts of the tests (0-based), so tools/run_tests.ps1 can run the parts in
## parallel processes. Tests are dealt by their times from the last run (TIMES_PATH, written by run_tests.ps1): the
## longest first, each to the part with the least time so far; a test with no recorded time counts as 1 s. Without the
## file they are dealt out in turn. Every test builds its own state, so a test does not rely on the ones before it.
const TIMES_PATH := "res://.godot/test_times.json"


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


## Every test as [suite/file::name, script, name], in file order.
func _collect() -> Array:
	var out := []
	var only := _only_filter()
	for suite in SUITES:
		var dir := DirAccess.open("res://tests/%s" % suite)
		if dir == null:
			continue
		var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and (only == "" or f.contains(only)))
		files.sort()
		for file in files:
			var script := load("res://tests/%s/%s" % [suite, file]) as GDScript
			for method in script.get_script_method_list():
				var name: String = method["name"]
				if name.begins_with("test_"):
					out.append(["%s/%s::%s" % [suite, file, name], script, name])
	return out


## The tests of this shard, in file order.
func _mine(all: Array, shard: Vector2i) -> Array:
	if shard.y == 1:
		return all
	var times = JSON.parse_string(FileAccess.get_file_as_string(TIMES_PATH)) if FileAccess.file_exists(TIMES_PATH) else null
	if not times is Dictionary:
		return range(all.size()).filter(func(i): return i % shard.y == shard.x).map(func(i): return all[i])
	var order := range(all.size())
	var ms := order.map(func(i): return float(times.get(all[i][0], 1000.0)))
	order.sort_custom(func(a, b): return ms[a] > ms[b] or (ms[a] == ms[b] and a < b))
	var sums := []
	sums.resize(shard.y)
	sums.fill(0.0)
	var keep := {}
	for i in order:
		var k := 0
		for j in range(1, shard.y):
			if sums[j] < sums[k]:
				k = j
		sums[k] += ms[i]
		if k == shard.x:
			keep[i] = true
	var out := []
	for i in range(all.size()):
		if keep.has(i):
			out.append(all[i])
	return out


func _run() -> void:
	var ctx := Ctx.new()
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	var test_count := 0
	var instances := {}
	for e in _mine(_collect(), _shard()):
		var script: GDScript = e[1]
		if not instances.has(script):
			instances[script] = script.new()
		ctx.current = e[0]
		test_count += 1
		var t0 := Time.get_ticks_msec()
		await instances[script].call(e[2], ctx, self)
		for err in errors.take():
			ctx.failures.append("%s: script error: %s" % [ctx.current, err])
		print("ran %s (%d ms)" % [ctx.current, Time.get_ticks_msec() - t0])
	for f in ctx.failures:
		printerr("FAIL ", f)
	print("tests=%d assertions=%d failures=%d" % [test_count, ctx.assertions, ctx.failures.size()])
	quit(2 if test_count == 0 else (1 if ctx.failures.size() > 0 else 0))
