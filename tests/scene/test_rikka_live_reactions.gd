extends RefCounted
## Rikka reacts to gameplay cues in the real game screen: her bust-up face and one line, gone after a few seconds,
## quiet while something more important is on screen.


func _boot(tree) -> Array:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	return [main, main.get_node("AppRoot"), main.get_node("ProgressionController")]


func test_a_gameplay_cue_shows_her_reaction_and_line(t, tree) -> void:
	var r: Array = await _boot(tree)
	var pc: ProgressionController = r[2]
	var stage: Control = r[0].get_node("AssistantStage")
	var cash: int = r[1].state.cash_yen
	var face := stage.find_child("AssistantPilotReaction", true, false) as TextureRect
	t.ok(pc.react("rival_opened", 1000.0), "she reacts to a rival opening")
	t.ok(stage.visible, "the stage is up")
	t.ok(pc._assistant.text.contains("ライバル店"), "her line: %s" % pc._assistant.text)
	t.ok(face != null and face.visible and face.texture != null, "her reaction face is drawn")
	t.eq(face.texture.resource_path, "res://assets/runtime/rikka_reactions/reaction_03.png", "the rival reaction face")
	var symbol := stage.find_child("AssistantPilotReactionSymbol", true, false) as Label
	t.ok(symbol.visible and symbol.text == "!?", "the symbol the cutout dropped is drawn over her")
	t.ok(not pc.react("rival_sale", 1001.0), "a second cue right after waits")
	pc._clear_live_reaction()
	t.ok(pc.live_reaction().is_empty(), "after a few seconds the reaction is gone")
	t.ok(not pc._assistant.text.contains("ライバル店"), "and her line goes back to the story: %s" % pc._assistant.text)
	t.ok(face.texture == null or face.texture.resource_path != "res://assets/runtime/rikka_reactions/reaction_03.png", "the reaction face is gone")
	t.eq(r[1].state.cash_yen, cash, "presentation only: nothing in the game changes")
	r[0].queue_free()
	await tree.process_frame


func test_she_stays_quiet_during_a_celebration(t, tree) -> void:
	var r: Array = await _boot(tree)
	var pc: ProgressionController = r[2]
	var first: Dictionary = r[1].state.milestones[0]
	pc.show_events([{"kind": "MILESTONE", "id": first["milestone_id"]}])
	t.ok(pc.is_celebrating(), "a title is being celebrated")
	t.ok(not pc.react("long_queue", 2000.0), "no reaction over a celebration")
	pc.close_celebration()
	t.ok(pc.react("long_queue", 2001.0), "the skipped cue did not start its cooldown")
	t.ok(pc._assistant.text.contains("レジ") or pc._assistant.text.contains("行列"), "her queue line: %s" % pc._assistant.text)
	var story: String = pc._snap["story_cue"]
	(r[0].get_node("AssistantStage").find_child("AssistantDismiss", true, false) as Button).pressed.emit()
	t.ok(pc.live_reaction().is_empty(), "閉じる closes the reaction")
	t.eq(pc._snap["story_cue"], story, "and keeps the story line under it")
	t.ok(not (r[1].state.progression_state["dismissed_story_cue_ids"] as Array).has(story), "the story line is not dismissed")
	r[0].queue_free()
	await tree.process_frame
