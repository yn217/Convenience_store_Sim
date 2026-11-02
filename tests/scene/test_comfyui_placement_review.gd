extends RefCounted
## Read-only 334-image placement review loader; it must not be part of Main/runtime.


func test_placement_review_loader_is_complete(t, _tree) -> void:
	var script := load("res://scripts/review/comfyui_placement_review.gd")
	t.ok(script.new().has_method("set_review_query"), "placement review exposes a capture-only query helper")
	t.ok(script.new().has_method("set_alpha_preview"), "placement review exposes a capture-only alpha preview helper")
	var prompt_review: Dictionary = script.load_prompt_review_assets()
	t.eq(prompt_review.size(), 334, "prompt review metadata loads for all 334 candidates")
	var assets: Array = script.load_placement_assets()
	t.eq(assets.size(), 334, "placement review loads all 334 candidates")
	var ids := {}
	for entry in assets:
		var id := String(entry.get("asset_id", ""))
		t.ok(not id.is_empty() and not ids.has(id), "%s is a unique candidate id" % id)
		ids[id] = true
		var relative_path := String(entry.get("candidate_relpath", ""))
		t.ok(not relative_path.is_empty(), "%s has a source path" % id)
		t.ok(FileAccess.file_exists("res://assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/" + relative_path), "%s source image exists" % id)
		t.ok(not String(entry.get("approval_state", "")).is_empty(), "%s keeps an explicit approval state" % id)
		t.eq(String(entry.get("visual_match", "")), "not_yet_verified", "%s remains unverified until review" % id)
