class_name ProductOverlayPlan
extends RefCounted
## Pure presentation plan for product overlays.
## It consumes fixture slot anchors and stock quantities but never mutates game state.


## Returns {"lod": "bar"/"few"/"full", "fill_ratio": float, "items": [{"position": Vector2, "texture": Texture2D}]}.
## `fixture_entry` is FixtureSprites.rotation_entry() output; `visual_id` is the SKU visual ID.
## `rotation` must be the fixture's world rotation so product facing follows the 3D slot rotation.
static func build(fixture_entry: Dictionary, visual_id: String, quantity: int, capacity: int, zoom: float, products: ProductSprites, rotation: int = 0) -> Dictionary:
	var result := {"lod": ShelfDisplay.lod(zoom), "fill_ratio": ShelfDisplay.fill_ratio(quantity, capacity), "items": []}
	if fixture_entry.is_empty() or products == null:
		return result
	var visible := ShelfDisplay.visible_items(quantity, capacity, zoom)
	if visible <= 0:
		return result
	var keys: Array = fixture_entry.get("slots", {}).keys()
	keys.sort()
	# Match FixturePresenter's back-to-front contract: item0 is nearest the
	# viewer's right, so the returned list is ordered far-to-near for drawing.
	keys.reverse()
	var tex_entry := products.entry(visual_id, rotation)
	if tex_entry.is_empty():
		return result
	var texture: Texture2D = tex_entry["texture"]
	var items: Array = []
	for i in mini(visible, keys.size()):
		items.append({"position": fixture_entry["slots"][keys[i]], "texture": texture, "slot_id": keys[i]})
	result["items"] = items
	return result
