extends RefCounted
## Title return flow: modal freezes simulation but Cancel restores the same clock/speed.

func test_return_button_and_cancel(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var controller: TitleReturnController = main.get_node("TitleReturnController")
	var button := main.find_child("ReturnToTitle", true, false) as Button
	t.ok(button != null, "settings includes a visible title-return button")
	t.ok(controller._dialog != null, "confirmation dialog exists")
	var app: AppRoot = main.get_node("AppRoot")
	var speed_before: int = app.state.speed_setting
	var revision_before: int = app.state.revision
	controller.ask_return_to_title()
	t.ok(tree.paused, "simulation is paused while the return dialog is visible")
	t.ok(controller._dialog.visible, "return dialog shown")
	t.eq(app.state.speed_setting, speed_before, "dialog does not change the stored speed")
	controller._dialog.hide()
	controller._cancel_return()
	t.ok(not tree.paused, "cancel resumes the scene")
	t.eq(app.state.speed_setting, speed_before, "cancel keeps speed")
	t.eq(app.state.revision, revision_before, "cancel does not mutate the domain")
	main.queue_free()
	await tree.process_frame


func test_bottom_right_quit_opens_return_confirmation(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var chrome := main.get_node("MockupChrome") as MockupChrome
	var quit_button := chrome.get_node("Base/bottom_bar/corner_quit") as Button
	var controller: TitleReturnController = main.get_node("TitleReturnController")
	t.ok(quit_button != null, "bottom-right game-exit button exists")
	quit_button.pressed.emit()
	await tree.process_frame
	t.ok(controller._dialog.visible, "bottom-right game-exit opens the title confirmation")
	t.ok(tree.paused, "bottom-right game-exit pauses before confirmation")
	controller._dialog.hide()
	controller._cancel_return()
	main.queue_free()
	await tree.process_frame


func test_title_art_and_continue_controls(t, tree) -> void:
	var title: TitleScreen = load("res://scenes/title/Title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	t.ok(title.find_child("TitleBackground", true, false) != null, "background art is a separate element")
	t.ok(title.find_child("TitleLogo", true, false) != null, "title logo is a separate element")
	var name_label := title.find_child("TitleName", true, false) as Label
	t.ok(name_label != null and name_label.text == "コンビニ経営\nシミュレーション", "the logo's words are a label (SVG text is not drawn by Godot)")
	t.ok(title.find_child("TitleMenuFrame", true, false) != null, "title actions sit on a warm framed menu plate")
	t.ok(title.find_child("TitleNotice", true, false) != null, "title screen exposes the notification affordance")
	t.ok(title.find_child("NewGame", true, false) != null, "new-game button remains interactive")
	t.ok(title.find_child("Continue", true, false) != null, "continue button remains interactive")
	t.ok(title.find_child("Quit", true, false) != null, "quit button remains interactive")
	title.queue_free()
	await tree.process_frame


## 保存せず戻る: the title scene replaces the game and no save is written; the tree is not left paused.
func test_leaving_without_saving_opens_the_title(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var controller: TitleReturnController = main.get_node("TitleReturnController")
	var app: AppRoot = main.get_node("AppRoot")
	app.save_dir = "user://test_title_return_saves"
	controller.ask_return_to_title()
	var changed := [false]
	var on_change := func(): changed[0] = true
	tree.scene_changed.connect(on_change)
	controller._dialog.confirmed.emit()
	await tree.process_frame
	await tree.process_frame
	t.ok(not tree.paused, "the tree runs again")
	t.eq(SaveStore.latest_slot(app.save_dir) if is_instance_valid(app) else SaveStore.latest_slot("user://test_title_return_saves"), "", "nothing was saved")
	t.ok(changed[0] or (tree.current_scene != null and tree.current_scene.scene_file_path == TitleReturnController.TITLE_SCENE), "the title scene is opened")
	tree.scene_changed.disconnect(on_change)
	if is_instance_valid(main):
		main.queue_free()
	if tree.current_scene != null and tree.current_scene.scene_file_path == TitleReturnController.TITLE_SCENE:
		tree.current_scene.queue_free()
	await tree.process_frame
