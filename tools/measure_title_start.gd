extends SceneTree
## 新規ゲーム from the title: the time from pressing it to the first drawn frame of the game, after --wait=S seconds on
## the title (default 3; --wait=-1: until the background load is done). Run with a real renderer:
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tools/measure_title_start.gd -- --wait=3


func _initialize() -> void:
	_run()


func _run() -> void:
	var wait := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wait="):
			wait = float(a.trim_prefix("--wait="))
	change_scene_to_file("res://scenes/title/Title.tscn")
	await process_frame
	await process_frame
	var t := Time.get_ticks_msec()
	var loaded_at := -1
	while Time.get_ticks_msec() - t < wait * 1000.0 or (wait < 0 and loaded_at < 0):
		if loaded_at < 0 and ResourceLoader.load_threaded_get_status("res://scenes/main/Main.tscn") == ResourceLoader.THREAD_LOAD_LOADED:
			loaded_at = Time.get_ticks_msec() - t
		await process_frame
	print("background load finished %d ms after the title appeared (-1: not yet)" % loaded_at)
	var title := current_scene
	var t0 := Time.get_ticks_usec()
	title.call("new_game")
	while current_scene == title or current_scene == null or current_scene.get_node_or_null("AppRoot") == null:
		await process_frame
	var t1 := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var t2 := Time.get_ticks_usec()
	print("after %.1f s on the title: scene changed %d ms after 新規, first game frame drawn %d ms after 新規" % [wait, (t1 - t0) / 1000, (t2 - t0) / 1000])
	quit()
