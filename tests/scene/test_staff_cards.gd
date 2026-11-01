extends RefCounted
## Issue #144 (mockup): today's candidates are cards side by side, each with its skills as bars and numbers, and 採用.


func test_candidates_are_cards(t, tree) -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var app: Node = main.get_node("AppRoot")
	app.state.staff_candidates = [
		{"candidate_id": "c1", "name": "高橋", "archetype": "cashier", "skills": {"register": 5, "restock": 1, "stamina": 2, "service": 3}},
		{"candidate_id": "c2", "name": "佐藤", "archetype": "balanced", "skills": {"register": 3, "restock": 3, "stamina": 3, "service": 3}},
	]
	app._publish_snapshot()
	await tree.process_frame
	var cards := main.find_child("CandidateCards", true, false) as GridContainer
	t.ok(cards != null, "the candidates sit in a card grid")
	var live := cards.get_children().filter(func(n): return not n.is_queued_for_deletion())
	t.eq(live.size(), 2, "one card per candidate")
	t.eq(cards.columns, 2, "side by side")
	var first := main.find_child("Candidate_c1", true, false) as PanelContainer
	t.eq((first.find_child("Skill_register", true, false) as ProgressBar).value, 5.0)
	t.eq((first.find_child("Skill_restock", true, false) as ProgressBar).value, 1.0)
	t.ok(first.tooltip_text.begins_with("高橋"), "the whole line is the tooltip")
	t.ok(first.find_child("Hire_c1", true, false) is Button, "採用 is on the card")
	main.queue_free()
	await tree.process_frame
