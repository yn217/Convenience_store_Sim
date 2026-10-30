extends RefCounted
## Title return flow: modal freezes simulation but Cancel restores the same clock/speed.

func test_return_button_and_cancel(t, tree) -> void:
	var main := load("res://scenes/main/Main.tscn").instantiate()
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


func test_title_art_and_continue_controls(t, tree) -> void:
	var title: TitleScreen = load("res://scenes/title/Title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	t.ok(title.find_child("TitleBackground", true, false) != null, "background art is a separate element")
	t.ok(title.find_child("TitleLogo", true, false) != null, "title logo is a separate element")
	t.ok(title.find_child("NewGame", true, false) != null, "new-game button remains interactive")
	t.ok(title.find_child("Continue", true, false) != null, "continue button remains interactive")
	t.ok(title.find_child("Quit", true, false) != null, "quit button remains interactive")
	title.queue_free()
	await tree.process_frame
