extends RefCounted
## Issue #61 (GUI side): the bottom command bar forwards to the inspector buttons.


func test_bar_mirrors_and_forwards_inspector_buttons(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var bar: CommandBar = main.get_node("Layout/CommandBar")
	t.eq(bar._pairs.size(), 3, "move / rotate / remove")
	for p in bar._pairs:
		t.ok((p[0] as Button).disabled, "nothing selected: disabled like the inspector")
	var rotate: Button = main.get_node("Layout/MainArea/FixtureInspector/Scroll/Body/RotateButton")
	var hits := {"n": 0}
	rotate.pressed.connect(func(): hits["n"] += 1)
	rotate.disabled = false
	bar.sync_state()
	t.ok(not (bar._pairs[1][0] as Button).disabled, "enabled follows the inspector")
	(bar._pairs[1][0] as Button).pressed.emit()
	t.eq(hits["n"], 1, "press forwarded exactly once")
	var world: Node2D = main.get_node("Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	var before: int = world.overlay_mode
	bar._mode_button.pressed.emit()
	t.ok(world.overlay_mode != before, "display mode cycled")
	main.queue_free()
	await tree.process_frame
