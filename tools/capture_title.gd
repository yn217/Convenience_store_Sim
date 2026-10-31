extends SceneTree
## Saves a screenshot of the title screen (with 小春六花 greeting at the right).
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_title.gd -- build/title.png


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_png := "user://title.png"
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out_png = a
	root.add_child(load("res://scenes/title/Title.tscn").instantiate())
	for i in 20:
		await process_frame
	get_root().get_texture().get_image().save_png(out_png)
	quit(0)
