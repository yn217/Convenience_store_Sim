extends SceneTree
## How long 新規ゲーム takes: loading Main.tscn, instancing it, adding it (every _ready) and the first frames, plus the
## slowest direct children of Main by their own _ready (measured by adding them one at a time is not possible, so the
## per-node numbers come from the NOTIFICATION_READY order: the time between consecutive ready_finished signals).
## Run with a real renderer:  Godot_v4.7.2-stable_win64.exe --path . --script res://tools/measure_main_load.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var t0 := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	var t1 := Time.get_ticks_usec()
	var main: Node = packed.instantiate()
	var t2 := Time.get_ticks_usec()
	var marks: Array = []
	for c in main.get_children():
		c.ready.connect(func(): marks.append([c.name, Time.get_ticks_usec()]))
	var main_ready := [0]
	main.ready.connect(func(): main_ready[0] = Time.get_ticks_usec())
	var draw := [0, 0]
	RenderingServer.frame_pre_draw.connect(func(): if draw[0] == 0: draw[0] = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
	RenderingServer.frame_post_draw.connect(func(): if draw[1] == 0: draw[1] = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
	var phases := []
	physics_frame.connect(func(): phases.append(["physics", Time.get_ticks_usec()]))
	process_frame.connect(func(): phases.append(["process", Time.get_ticks_usec()]))
	root.add_child(main)
	var t3 := Time.get_ticks_usec()
	await process_frame
	var t4 := Time.get_ticks_usec()
	await process_frame
	for i in 4:
		await process_frame
	var t5 := Time.get_ticks_usec()
	print("load %d ms, instantiate %d ms, add_child (_ready) %d ms, first frame %d ms, next 4 frames %d ms, total %d ms" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, (t4 - t3) / 1000, (t5 - t4) / 1000, (t5 - t0) / 1000])
	print("first pre_draw +%d ms, post_draw +%d ms after instantiate" % [(draw[0] - t2) / 1000, (draw[1] - t2) / 1000])
	print("phases (+ms): ", phases.slice(0, 8).map(func(x): return [x[0], (int(x[1]) - t2) / 1000]))
	print("Main ready at +%d ms after instantiate (last child ready +%d ms)" % [(main_ready[0] - t2) / 1000, (int(marks[-1][1]) - t2) / 1000 if not marks.is_empty() else -1])
	var prev := t2
	var rows: Array = []
	for m in marks:
		rows.append([m[0], (int(m[1]) - prev) / 1000])
		prev = int(m[1])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	print("children by ready gap (ms): ", rows.slice(0, 12))
	quit()
