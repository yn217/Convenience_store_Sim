class_name ShelfDisplay
extends RefCounted
## How full a display row looks (#9): quantity -> number of product placeholders, by zoom LOD.
## Pure functions, no scene access. Fill steps are 0 / 2 / 5 / 8 items per row.

const MAX_ITEMS := 8
const FAR_ZOOM := 0.75
const NEAR_ZOOM := 1.5


## Items drawn for a row holding `qty` of `capacity` units, before the LOD cap.
static func item_count(qty: int, capacity: int) -> int:
	if qty <= 0 or capacity <= 0:
		return 0
	var ratio := float(mini(qty, capacity)) / float(capacity)
	if ratio <= 1.0 / 3.0:
		return 2
	if ratio <= 2.0 / 3.0:
		return 5
	return MAX_ITEMS


## "bar" (far: one colour bar per row), "few" (mid: at most 4 items) or "full" (near: at most 8).
static func lod(zoom: float) -> String:
	if zoom < FAR_ZOOM:
		return "bar"
	if zoom < NEAR_ZOOM:
		return "few"
	return "full"


static func visible_items(qty: int, capacity: int, zoom: float) -> int:
	var n := item_count(qty, capacity)
	match lod(zoom):
		"bar":
			return 0
		"few":
			return mini(n, 4)
	return n


static func fill_ratio(qty: int, capacity: int) -> float:
	if capacity <= 0:
		return 0.0
	return clampf(float(qty) / float(capacity), 0.0, 1.0)


## Physical quantity per fixture slot: {fixture_id: {slot_id: qty}} from FIXTURE-located segments.
static func stock_by_slot(segments: Array) -> Dictionary:
	var out := {}
	for seg in segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] != "FIXTURE":
			continue
		var fid: String = loc["fixture_id"]
		if not out.has(fid):
			out[fid] = {}
		out[fid][loc["slot_id"]] = int(out[fid].get(loc["slot_id"], 0)) + int(seg["physical_qty"])
	return out
