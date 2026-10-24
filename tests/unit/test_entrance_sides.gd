extends RefCounted
## The entrance is data (StoreGrid.entrance_tiles) and may sit on any of the four walls. For each wall, the same
## checks must hold: the storefront is on that wall, the street dressing is on the matching outside edge, nothing
## dressing-related stands on the walkable floor, customers can walk in and out, and the camera fit shows the door.

const W := 16
const H := 12

## name, entrance tiles, entrance side (BackdropLayer.SIDE_*)
const CASES := [
	["west", [Vector2i(0, 5), Vector2i(0, 6)], BackdropLayer.SIDE_WEST],
	["north", [Vector2i(5, 0), Vector2i(6, 0)], BackdropLayer.SIDE_NORTH],
	["east", [Vector2i(15, 5), Vector2i(15, 6)], BackdropLayer.SIDE_EAST],
	["south", [Vector2i(8, 11), Vector2i(9, 11)], BackdropLayer.SIDE_SOUTH],
]


## The wall line of a side, in world coordinates (the across-wall coordinate).
func _plane(side: int) -> float:
	match side:
		BackdropLayer.SIDE_WEST:
			return -0.5
		BackdropLayer.SIDE_NORTH:
			return -0.5
		BackdropLayer.SIDE_EAST:
			return W - 0.5
	return H - 0.5


func _across(p: Vector3, side: int) -> float:
	return p.x if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_EAST else p.y


## Whether a ground item stands outside the store on the given side (beyond the wall line, not on the floor).
func _outside(x: float, y: float, side: int) -> bool:
	match side:
		BackdropLayer.SIDE_WEST:
			return x < -0.5
		BackdropLayer.SIDE_NORTH:
			return y < -0.5
		BackdropLayer.SIDE_EAST:
			return x > W - 0.5
	return y > H - 0.5


func _on_floor(x: float, y: float) -> bool:
	return x > -0.5 and x < W - 0.5 and y > -0.5 and y < H - 0.5


func _typed(ent: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(ent)
	return out


func test_entrance_on_each_wall(t, _tree) -> void:
	for c in CASES:
		_check_wall(t, c[0], c[1], c[2])


func _check_wall(t, name: String, ent: Array, side: int) -> void:
	t.eq(BackdropLayer.entrance_side(W, H, ent), side, "%s: entrance side" % name)
	var wall := StoreDecor.wall_items(W, H, ent, {})
	var street := StoreDecor.exterior_items(W, H, ent)
	var items: Array = wall + street

	# Storefront: one blue fascia band on the entrance wall line, and a store name above it.
	var fascia := items.filter(func(it): return it["kind"] == &"poly" and it["color"] == StoreDecor.FASCIA)
	t.eq(fascia.size(), 1, "%s: one fascia band" % name)
	var on_wall := true
	for p in fascia[0]["points"]:
		on_wall = on_wall and absf(_across(p, side) - _plane(side)) < 1e-6
	t.ok(on_wall, "%s: fascia stands on the entrance wall" % name)
	t.eq(items.filter(func(it): return it["kind"] == &"text" and it["text"] == StoreDecor.NAME).size(), 1, "%s: store name once" % name)

	# Far walls (west, north) carry the glass storefront with doors on the entrance tiles; near walls stay low.
	var doors := items.filter(func(it): return it["kind"] == &"sprite" and it["id"] == "storefront_door")
	if side == BackdropLayer.SIDE_WEST or side == BackdropLayer.SIDE_NORTH:
		t.eq(doors.size(), ent.size(), "%s: one door per entrance tile" % name)
		for d in doors:
			t.ok(_outside(d["x"], d["y"], side), "%s: door stands outside the entrance wall" % name)

	# Street dressing: parking, the vending machine and the bins all stand on the entrance side, outside the store.
	var parking := street.filter(func(it): return it["kind"] == &"sprite" and it["id"] == "parking_lot_straight")
	t.ok(parking.size() > 0, "%s: parking on the entrance side" % name)
	var vending := street.filter(func(it): return it["kind"] == &"sprite" and it["id"] == "vending_machine")
	t.eq(vending.size(), 1, "%s: one vending machine" % name)
	if vending.size() == 1:
		t.ok(_outside(vending[0]["x"], vending[0]["y"], side), "%s: vending machine on the street side" % name)

	# Nothing on the walkable floor: no sprite of the wall or exterior layers stands on a floor tile.
	var on_floor := 0
	for it in items:
		if it["kind"] == &"sprite" and _on_floor(it["x"], it["y"]):
			on_floor += 1
	t.eq(on_floor, 0, "%s: no decor on the walkable floor" % name)

	# Customers enter and leave: every door tile is reachable and the floor is reachable from it, both ways.
	var grid := StoreGrid.create("store_entrance_test", W, H, _typed(ent))
	var reach := PathService.distances(grid, {})
	var centre := Vector2i(7, 6)
	for e in ent:
		t.eq(reach.get(e, -1), 0, "%s: entrance %s is an entry point" % [name, e])
	t.ok(reach.has(centre), "%s: floor reachable from the door" % name)
	t.ok(not PathService.find_path(grid, {}, ent[0], centre).is_empty(), "%s: customers walk in" % name)
	t.ok(not PathService.find_path(grid, {}, centre, ent[0]).is_empty(), "%s: customers walk out" % name)

	# Camera: the default interior fit (shifted toward the entrance) keeps the door inside the view.
	var proj := IsoProjection.new()
	proj.set_zoom(1.0)
	var area := Rect2(0, 0, 1280, 720)
	proj.fit_interior(area, W, H, IsoProjection.entrance_shift(ent, W, H))
	var door_mid := Vector2.ZERO
	for e in ent:
		var seg := BackdropLayer.door_segment(e, W, H)
		door_mid += (seg[0] + seg[1]) * 0.5
	door_mid /= ent.size()
	var door_screen := proj.world_to_screen(door_mid.x, door_mid.y)
	t.ok(area.has_point(door_screen), "%s: the door is inside the default camera view" % name)
