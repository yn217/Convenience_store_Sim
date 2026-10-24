extends RefCounted
## Issue #114: the storefront spill follows the entrance side, lies on the pavement outside the store and fades out.

const W := 10
const H := 8


## Distance from the store wall on `side` (0 on the wall line, grows outward; negative inside the store).
func _depth(side: int, p: Vector2) -> float:
	match side:
		BackdropLayer.SIDE_WEST:
			return -0.5 - p.x
		BackdropLayer.SIDE_NORTH:
			return -0.5 - p.y
		BackdropLayer.SIDE_EAST:
			return p.x - (W - 0.5)
	return p.y - (H - 0.5)


func _along(side: int, p: Vector2) -> float:
	return p.x if side == BackdropLayer.SIDE_NORTH or side == BackdropLayer.SIDE_SOUTH else p.y


func _entrance_for(side: int) -> Array:
	match side:
		BackdropLayer.SIDE_WEST:
			return [Vector2i(0, 3)]
		BackdropLayer.SIDE_NORTH:
			return [Vector2i(4, 0)]
		BackdropLayer.SIDE_EAST:
			return [Vector2i(W - 1, 3)]
	return [Vector2i(4, H - 1)]


func _along_extent(side: int) -> float:
	return float(W if side == BackdropLayer.SIDE_NORTH or side == BackdropLayer.SIDE_SOUTH else H)


func test_spill_sits_on_the_entrance_side_for_all_four_sides(t, _tree) -> void:
	for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
		var quads := LightSpill.spill_quads(W, H, _entrance_for(side))
		t.eq(quads.size(), (LightSpill.SPILL_DEPTHS.size() - 1) * (LightSpill.SPILL_ALONG_ALPHA.size() - 1), "side %d: quad grid size" % side)
		var detected := BackdropLayer.entrance_side(W, H, _entrance_for(side))
		t.eq(detected, side, "side %d: entrance side is detected" % side)
		var all_outside := true
		var min_along := INF
		var max_along := -INF
		for q in quads:
			for p in q["points"]:
				if _depth(side, p) < -0.001:
					all_outside = false
				min_along = minf(min_along, _along(side, p))
				max_along = maxf(max_along, _along(side, p))
		t.ok(all_outside, "side %d: the spill stays outside the store wall" % side)
		t.ok(absf(min_along - -0.5) < 0.001 and absf(max_along - (_along_extent(side) - 0.5)) < 0.001,
			"side %d: the spill covers the whole storefront edge" % side)


func test_spill_is_strongest_at_the_wall_and_gone_far_out(t, _tree) -> void:
	for side in [BackdropLayer.SIDE_WEST, BackdropLayer.SIDE_NORTH, BackdropLayer.SIDE_EAST, BackdropLayer.SIDE_SOUTH]:
		var quads := LightSpill.spill_quads(W, H, _entrance_for(side))
		var at_wall := 0.0
		var far_out := 0.0
		for q in quads:
			for i in 4:
				var d := _depth(side, q["points"][i])
				if absf(d) < 0.001:
					at_wall = maxf(at_wall, float(q["alphas"][i]))
				if absf(d - LightSpill.SPILL_DEPTH) < 0.001:
					far_out = maxf(far_out, float(q["alphas"][i]))
		t.ok(at_wall > 0.9, "side %d: full strength at the storefront" % side)
		t.ok(far_out < 0.001, "side %d: no spill at the far edge" % side)


func test_spill_is_empty_for_a_store_without_a_layout(t, _tree) -> void:
	t.eq(LightSpill.spill_quads(0, 0, []).size(), 0, "no floor, no spill")

