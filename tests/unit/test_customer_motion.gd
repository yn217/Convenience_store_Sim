extends RefCounted
## Issue #117: presentation of customer motion. Facing hysteresis, idle versus walk selection and the shown speed cap
## (presentation only: the simulation is never touched here).

const Presenter := preload("res://scripts/presentation/fixture_presenter.gd")
const FRAME := 1.0 / 60.0


## Just the fields FixturePresenter reads in _sync_customers and customer_view.
class FakeWorld extends Node2D:
	var customers: Array = []
	var speed_setting := 1
	var fixtures: Array = []
	var fixture_catalog: FixtureCatalog
	var product_catalog: ProductCatalog
	var projection: IsoProjection = null
	var revision := 0
	var overlay_mode := 0
	var selected_customer := ""
	var shelf_stock: Dictionary = {}
	var shelf_skus: Dictionary = {}

	func selected_fixture_id() -> String:
		return ""


## A fresh walk state of one figure (as the presenter creates it), with the turn hold already expired or set.
func _walk_state(face_age: float) -> Presenter.Walk:
	var w := Presenter.Walk.new()
	w.face_age = face_age
	return w


func _presenter(speed: int) -> Presenter:
	var p: Presenter = Presenter.new()
	var w := FakeWorld.new()
	w.speed_setting = speed
	p._world = w
	return p


func _customer(id: String, tile: Vector2i, path: Array, phase: String, progress: float = 0.0) -> Dictionary:
	var next: Vector2i = path[0] if not path.is_empty() else tile
	return {"customer_id": id, "tile": tile, "path": path, "next": next, "progress": progress, "phase": phase, "moved": 0, "trail": []}


## Facing: a figure turns only after FACE_HYSTERESIS tiles of net movement in a new direction.
func test_facing_turns_only_after_sustained_movement(t, _tree) -> void:
	var p := _presenter(1)
	var tr := _walk_state(10.0)
	p._facing["c1"] = CustomerSprites.FACING_E
	for i in 2:
		p._update_facing("c1", tr, Vector2(0.0, 0.1), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_E, "a 0.2 tile wobble does not turn the figure")
	p._update_facing("c1", tr, Vector2(0.0, 0.2), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_S, "0.4 tiles of movement to the south turns it")


## A wobble that goes back and forth cancels out in the net movement: no turn at all.
func test_back_and_forth_wobble_never_turns(t, _tree) -> void:
	var p := _presenter(1)
	var tr := _walk_state(10.0)
	p._facing["c1"] = CustomerSprites.FACING_E
	for i in 40:
		var d := Vector2(0.0, 0.05) if i % 2 == 0 else Vector2(0.0, -0.05)
		p._update_facing("c1", tr, d, Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_E, "40 wobbles of 0.05 tile at a corner keep the facing")


## Right after a turn the figure does not turn straight back (staircase paths flicker otherwise).
func test_no_immediate_reversal_after_a_turn(t, _tree) -> void:
	var p := _presenter(1)
	var tr := _walk_state(10.0)
	p._facing["c1"] = CustomerSprites.FACING_E
	p._update_facing("c1", tr, Vector2(0.4, 0.0), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_E)
	p._update_facing("c1", tr, Vector2(0.0, 0.4), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_S, "turned south")
	# Walking back east (0.4 tile) within the hold: suppressed.
	p._update_facing("c1", tr, Vector2(0.4, 0.0), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_S, "no turn back to the east within FACE_HOLD")
	# After the hold has passed, the same move is allowed.
	tr.face_age = Presenter.FACE_HOLD + 0.01
	p._update_facing("c1", tr, Vector2(0.4, 0.0), Vector2.ZERO, FRAME)
	t.eq(p._facing["c1"], CustomerSprites.FACING_E, "after the hold the figure turns east again")


## Animation follows what the figure does on screen, not the simulation phase alone.
func test_idle_selection_follows_the_shown_movement(t, _tree) -> void:
	t.eq(CustomerSprites.anim_for_state("WALK_SHELF", true, false), "walk", "moving on screen walks")
	t.eq(CustomerSprites.anim_for_state("WAIT_QUEUE", false, false), "idle", "standing in a queue is idle")
	t.eq(CustomerSprites.anim_for_state("QUEUE", false, false), "idle")
	t.eq(CustomerSprites.anim_for_state("EXIT", false, false), "idle", "standing still at the exit is idle, not a walk")
	t.eq(CustomerSprites.anim_for_state("WAIT_QUEUE", false, true), "inspect", "a pick pose at the shelf inspects")
	t.eq(CustomerSprites.anim_for_state("SELECT", false, false), "inspect", "choosing inspects")
	t.eq(CustomerSprites.anim_for_state("QUEUE", true, false), "walk", "moving in the queue walks")


## A figure that stands still shows the idle pose after the walking hold has run out (no walk cycle on the spot).
func test_standing_figure_plays_idle_not_walk(t, _tree) -> void:
	var p := _presenter(1)
	var tile := Vector2i(2, 2)
	var c := _customer("c1", tile, [], "QUEUE")
	p._world.customers = [c]
	p._sync_customers(0.0)
	t.eq(p.customer_view(c)["anim"], "idle", "at rest from the start")
	p._sync_customers(FRAME)
	p._sync_customers(0.5)
	t.eq(p.customer_view(c)["anim"], "idle", "still after a second of rest")
	t.eq(p.customer_view(c)["pos"], Vector2(2, 2), "stays on its tile centre")


## Shown speed cap: no frame moves a figure more than WALK_MAX per real second, it never runs past the simulation,
## and it never cuts a corner: while it is short of a turning tile the drawn position stays on the segment before it.
func test_shown_speed_is_capped_and_follows_the_path(t, _tree) -> void:
	for speed in [1, 2, 4]:
		var p := _presenter(speed)
		var tr := _walk_state(0.0)
		tr.hist.append(Vector2i(0, 0))
		p._track["c1"] = tr
		var path: Array = []
		for x in range(1, 4):
			path.append(Vector2i(x, 0))
		path.append(Vector2i(3, 1))
		for y in range(2, 5):
			path.append(Vector2i(3, y))
		var pace := Presenter.WALK_TILES_PER_SEC * sqrt(float(speed))
		var max_step := 0.0
		var prev := Vector2(0, 0)
		var corner_ok := true
		var pos := Vector2(0, 0)
		for f in 240:
			p._walk("c1", tr, path, 6.5, FRAME, pace)
			pos = p._pos["c1"]
			max_step = maxf(max_step, pos.distance_to(prev))
			prev = pos
			# The corner tile is (3,0): before reaching it the figure stays on the row y=0; after it, x stays 3.
			if pos.x < 3.0 - 1e-6 and absf(pos.y) > 1e-6:
				corner_ok = false
		t.ok(max_step <= Presenter.WALK_MAX * FRAME + 1e-6, "x%d: no frame moves more than WALK_MAX per real second (max %.4f)" % [speed, max_step])
		t.ok(corner_ok, "x%d: the figure follows the row and turns at the corner tile, no cut" % speed)
		t.ok(pos.distance_to(Vector2(3, 3.5)) < 0.01, "x%d: ends on the walked path where the simulation is (3, 3.5), got %s" % [speed, str(pos)])


## The pace is the calm one at x1 (about 5 tiles per real second once it has accelerated), and grows with speed.
func test_pace_is_calm_and_grows_with_speed(t, _tree) -> void:
	var path: Array = []
	for x in range(1, 200):
		path.append(Vector2i(x, 0))
	for speed in [1, 4]:
		var p := _presenter(speed)
		var tr := _walk_state(0.0)
		tr.hist.append(Vector2i(0, 0))
		p._track["c1"] = tr
		var pace := Presenter.WALK_TILES_PER_SEC * sqrt(float(speed))
		var sim := Presenter.WALK_LAG_FREE   # the simulation is that far ahead: inside the free lag, the figure keeps its pace
		var last_second := 0.0
		for f in 600:   # 10 s: the start-up lag settles first
			sim += pace * FRAME   # the simulation walks at the same pace
			var before: float = tr.s
			p._walk("c1", tr, path, sim, FRAME, pace)
			if f >= 540:
				last_second += float(tr.s) - before
		t.ok(absf(last_second - pace) < 0.25, "x%d: a figure at pace walks %.2f tiles per real second (expected %.2f)" % [speed, last_second, pace])
	t.ok(Presenter.WALK_TILES_PER_SEC * sqrt(4.0) > Presenter.WALK_TILES_PER_SEC, "x4 walks faster than x1")
	t.ok(Presenter.WALK_MAX < 36.0, "the shown speed stays far below the simulation's own pace (about 36 tiles per real second at x1)")
