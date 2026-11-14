extends RefCounted
## Visual variant resolution (VisualVariants): fallback order, the runtime_approved gate, the dev override,
## missing and broken manifests. Uses fake manifests under user:// only; the real assets are never read here.

const DIR := "user://visual_variant_test"


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _manifest(approved: bool) -> String:
	return JSON.stringify({"runtime_approved": approved, "rotations": {}})


## Fake fixture manifests for three ids:
##   t_drink:  painted_v1 (not approved), painted_v2 (approved), a (base)
##   t_ok:     painted_v1 (approved)
##   t_broken: painted_v1 is not JSON
func _fixture() -> Dictionary:
	_write("%s/t_drink/t_drink_painted_v1.visual.json" % DIR, _manifest(false))
	_write("%s/t_drink/t_drink_painted_v2.visual.json" % DIR, _manifest(true))
	_write("%s/t_drink/t_drink_a.visual.json" % DIR, _manifest(false))
	_write("%s/t_ok/t_ok_painted_v1.visual.json" % DIR, _manifest(true))
	_write("%s/t_broken/t_broken_painted_v1.visual.json" % DIR, "{not json")
	_write("%s/t_broken/t_broken_a.visual.json" % DIR, _manifest(false))
	return {
		"paths": {"fixtures": {
			"painted_v1": DIR + "/{id}/{id}_painted_v1.visual.json",
			"painted_v2": DIR + "/{id}/{id}_painted_v2.visual.json",
			"a": DIR + "/{id}/{id}_a.visual.json",
		}},
		"fixtures": {
			"t_drink": ["painted_v1", "painted_v2", "a"],
			"t_ok": ["painted_v1", "a"],
			"t_broken": ["painted_v1", "a"],
			"t_missing": ["painted_v1", "a"],
		},
	}


func test_unapproved_variant_is_skipped_for_the_next_one(t, _tree) -> void:
	var prefs := _fixture()
	# painted_v1 exists but is not approved; painted_v2 is approved and comes next in the list.
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_drink")["variant"], "painted_v2", "first approved variant wins")


func test_approved_first_choice_is_used(t, _tree) -> void:
	var prefs := _fixture()
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok")["variant"], "painted_v1", "approved painted_v1 wins over a")
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok")["path"], DIR + "/t_ok/t_ok_painted_v1.visual.json", "path from the template")


func test_no_approved_variant_falls_back_to_base(t, _tree) -> void:
	var prefs := _fixture()
	prefs["fixtures"]["t_drink"] = ["painted_v1"]   # only the unapproved one is listed
	var r := VisualVariants.resolve(prefs, "fixtures", "t_drink")
	t.eq(r["variant"], "a", "unapproved painted variant is not used")
	t.eq(r["path"], DIR + "/t_drink/t_drink_a.visual.json", "base manifest path")


func test_override_waives_the_approval_gate(t, _tree) -> void:
	var prefs := _fixture()
	prefs["fixtures"]["t_drink"] = ["painted_v2", "a"]
	var r := VisualVariants.resolve(prefs, "fixtures", "t_drink", "painted_v1")
	t.eq(r["variant"], "painted_v1", "override names an unapproved variant and it is used")
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_drink", "")["variant"], "painted_v2", "no override: the gate applies again")


func test_override_to_base_forces_the_current_art(t, _tree) -> void:
	var prefs := _fixture()
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok", "a")["variant"], "a", "override a wins over the approved list")


func test_override_without_a_template_is_ignored(t, _tree) -> void:
	var prefs := _fixture()
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok", "no_such_variant")["variant"], "painted_v1", "unknown override falls through to the list")


func test_override_with_missing_file_falls_through(t, _tree) -> void:
	var prefs := _fixture()
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_drink", "painted_v1")["variant"], "painted_v1", "override with a file present is used")
	prefs["paths"]["fixtures"]["painted_v1"] = DIR + "/{id}/{id}_gone.visual.json"
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok", "painted_v1")["variant"], "a", "override whose file is missing falls back to base")


func test_missing_files_never_crash(t, _tree) -> void:
	var prefs := _fixture()
	var r := VisualVariants.resolve(prefs, "fixtures", "t_missing")
	t.eq(r["variant"], "a", "no painted file: base variant")
	t.ok(not FileAccess.file_exists(r["path"]), "the base path is returned but does not exist (caller checks)")
	t.eq(VisualVariants.resolve({}, "fixtures", "t_drink")["variant"], "a", "no preferences file: base variant")
	t.eq(VisualVariants.resolve(prefs, "props", "t_drink")["variant"], "a", "unknown kind: base variant")
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_ok", "")["variant"], "painted_v1", "empty override means no override")


func test_broken_manifest_is_skipped(t, _tree) -> void:
	var prefs := _fixture()
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_broken")["variant"], "a", "unparsable painted manifest is not usable")
	t.eq(VisualVariants.resolve(prefs, "fixtures", "t_broken", "painted_v1")["variant"], "a", "override waives approval but not the parse check")


func test_base_template_is_built_in(t, _tree) -> void:
	t.eq(VisualVariants.manifest_path({}, "fixtures", "fridge_drink", "a"), "res://assets/generated/fixtures/fridge_drink/fridge_drink_a.visual.json", "built-in base path")
	t.eq(VisualVariants.manifest_path({}, "fixtures", "fridge_drink", "painted_v1"), "", "no painted template without preferences")


func test_arg_override_reads_the_visual_variant_argument(t, _tree) -> void:
	t.eq(VisualVariants.arg_override(["--calm", "--visual-variant=painted_v1"]), "painted_v1", "argument read")
	t.eq(VisualVariants.arg_override(["out.png", "--visual-variant=a"]), "a", "base override read")
	t.eq(VisualVariants.arg_override(["--calm"]), "", "no argument: no override")


func test_products_baked_flag(t, _tree) -> void:
	t.ok(not VisualVariants.products_baked({}), "base manifest: products drawn")
	t.ok(not VisualVariants.products_baked({"state": "PARTIAL"}), "partial state does not bake")
	t.ok(VisualVariants.products_baked({"state": "FULL"}), "FULL state bakes the products")
	t.ok(VisualVariants.products_baked({"products_baked": true}), "explicit flag bakes the products")


func test_real_preferences_file_lists_the_pilot(t, _tree) -> void:
	var prefs := VisualVariants.load_preferences()
	t.eq(prefs.get("fixtures", {}).get("fridge_drink", []), ["depth_v1", "painted_v1", "a"], "fridge_drink order")
	t.eq(prefs.get("fixtures", {}).get("shelf_general", []), ["depth_v1", "painted_v1", "a"], "shelf_general order")
	t.eq(VisualVariants.load_preferences("user://no_such_visual_variants.json"), {}, "missing file gives no preferences")
