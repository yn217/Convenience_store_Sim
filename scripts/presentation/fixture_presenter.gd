extends Node2D
## Fixtures and customers composed back to front (#9, #26). Manifest sprites where generated,
## placeholder boxes otherwise. Read-only: draws the snapshot's fixtures and customers.
## A fixture is cut into screen-column segments (DrawOrder) so a customer can stand in front of one
## end of a long shelf and behind the other; each segment draws its own slice of the sprite layers
## (shadow, body, products, glass front) and the slice order follows DrawOrder, never one depth per fixture.
## The yellow edge marks the customer-facing access side, so rotation is visible.

const CATEGORY_COLOR := {
	"rice_ball": Color("e8a87c"), "oden": Color("c0794a"), "instant_noodle": Color("e6c35c"),
	"bread": Color("d9b38c"), "drink": Color("5caefd"), "snack": Color("e07a9a"),
	"dessert": Color("b79bdc"), "ice_cream": Color("8fd6e0"),
	"bento": Color("d98c5f"), "daily_fresh": Color("8cc77a"), "coffee": Color("8a6248"),
	"capsule_toy": Color("e05a9c"),
	"daily_goods": Color("7a8fb8"), "hygiene": Color("6cc3d5"), "character_goods": Color("f2b63d"),
	"soft_serve": Color("f3e3c3"), "frappe": Color("f08aa8"),
	"bakery": Color("d9a35f"), "pizza": Color("e0703a"),
	"crane_prize": Color("c77dd9"),
}
const REGISTER_COLOR := Color("7f8c99")
const FRONT_COLOR := Color("ffc873")
const INSET := 0.46
## Product placeholder size in source px (anchor = bottom centre of the item).
const ITEM_W := 22.0
const ITEM_H := 30.0
## From this zoom on (and when the row is not in the far "bar" LOD) a shelf item without its sprite falls back to a
## code-made package icon (ProductIcons). Shelf items are Codex product sprites at every LOD above "bar".
const ICON_MIN_ZOOM := 0.9
const ICON_PX := 32
## Item size caps: height up to this share of the row gap to the board above; width up to this multiple of the
## spacing to the neighbour (so a neighbour overlaps by at most about 15%).
const ROW_FILL := 0.85
const SPACING_FILL := 1.15

var _world: Node2D
var _sprites := FixtureSprites.new()
var _people := CustomerSprites.new()
var _art := ProductSprites.new()   # Codex product sprites by visual_id and facing (cached per direction)
## Presentation-only state of the people shown (never saved, never read by the simulation):
## smoothed tile position, last facing, and the animation clock in game seconds (frozen at speed 0).
var _pos: Dictionary = {}
var _facing: Dictionary = {}
var _alive: Dictionary = {}   # ids seen by the current _sync_customers call (reused, not reallocated)
var _look: Dictionary = {}    # customer_id -> [sheet, variant_id, time offset]; fixed per customer, so computed once
var anim_time: float = 0.0


func _ready() -> void:
	_world = get_parent().get_parent()


func _process(delta: float) -> void:
	if _sprites.refresh():   # the visual variant override changed: rebuild the sprites and their retained segments
		_seg_cache.clear()
		queue_redraw()
	_age_pick_faces(delta)
	if _world == null or _world.speed_setting <= 0:
		return
	if _world.customers.is_empty() and _track.is_empty():
		return
	var dt := delta * float(_world.speed_setting)
	anim_time += dt
	_sync_customers(dt)
	_synced = true   # the draw that follows this frame's step does not need a second (zero-step) sync
	queue_redraw()


## Where the customer is aimed (tile units): the current tile moved toward the next path tile.
static func target_pos(c: Dictionary) -> Vector2:
	var t: Vector2i = c["tile"]
	var n: Vector2i = c.get("next", t)
	return Vector2(t) + Vector2(n - t) * float(c.get("progress", 0.0))


## Presentation-only walk state per customer: {"hist": tiles walked so far (ends at the simulation's tile),
## "seen": steps already taken in from the simulation's trail, "s": shown position as an index into the chain
## hist + remaining path}. The shown position only moves along that chain, so it stays on tile centres.
## Forward motion also stops at every turning tile of the chain, so the straight line between two frames
## never cuts a corner, whatever the frame rate or the speed (x1, x2, x4) and however many steps one frame covers.
var _track: Dictionary = {}
## Set by _process after its step, so the draw that follows does not step again with zero time (#117 perf).
var _synced := false
var _ghost_buf: Array = []   # departing figures of the current compose (reused, not reallocated)
## Shown walking pace in tiles per REAL second (the simulation walks about 36 tiles per real second at x1; the
## figure keeps to this calm pace on its walked trail and catches up when the simulation stops it). Same at every speed.
## The pace grows with the speed as sqrt(speed) (x2 is 1.4 times x1, x4 twice x1): the simulation feeds customers
## faster at higher speeds, so the figures walk a little faster too, but never at the simulation's own pace.
const WALK_TILES_PER_SEC := 5.0
## A figure that is more than WALK_LAG_FREE tiles behind the simulation speeds up to catch up, at most to WALK_MAX.
## (A figure keeps its pace while it is that far behind: pace^2 / (2 * WALK_ACCEL) tiles, so the brake never bites.)
const WALK_LAG_FREE := 6.0
const WALK_MAX := 12.0   # 0.2 tile per frame at 60 fps: no jumps
## #117 v2 (the simulation walks at the shown pace): the figure walks FOLLOW_PACE times the simulation's speed and
## brakes so that it trails the simulation by at most about LAG_FOLLOW tiles (what a click shows is where it stands).
const FOLLOW_PACE := 1.1
const LAG_FOLLOW := 0.3
var _follow := false
var _accel := WALK_ACCEL
## Start and stop: the pace changes by at most this much per real second (tiles/s per s), so figures never snap.
const WALK_ACCEL := 10.0
## Facing turns only after this many tiles of movement in the new direction (no flicker at corners or in queues).
const FACE_HYSTERESIS := 0.35
## After a turn, the figure does not turn straight back for this many real seconds (staircase paths, A-B-A).
const FACE_HOLD := 0.3
## Real seconds the walking animation holds after the figure last moved (no idle/walk flicker between frames).
const MOVING_HOLD := 0.15
## A customer the simulation has removed walks on for at most this many real seconds, fading out over the last
## GHOST_FADE_SEC (the walk never runs ahead of the simulation, so a removed customer is only late, not warped).
const GHOST_MAX_SEC := 1.5
const GHOST_FADE_SEC := 0.4
## Visual budget (#117): above this many figures on screen (live and departing), departing figures fade
## GHOST_CROWD_RATE times faster, so a crowd of lagging walkers does not pile up on the floor.
const FIGURE_BUDGET := 20
const GHOST_CROWD_RATE := 8.0
## A movement larger than this in one frame is a placement (spawn, teleport), not a walk: it does not turn the figure.
const PLACE_TILES := 1.0
const TRACK_KEEP := 4
const MOVE_EPS := 0.0005
const _NO_IDS: Array = []     # shared empty lists (read only), so no list is built per frame
const _NO_TRAIL: Array = []


## Presentation-only walk state of one customer. Typed fields: this is read and written for every figure every
## frame, and dictionary lookups were most of the presenter's per-frame cost (#117 perf).
## hist: tiles walked so far (ends at the simulation's tile); seen: steps taken in from the simulation's trail;
## s: shown position as an index into hist + remaining path (the shown position moves only along that chain, so
## it stays on tile centres); v: shown speed (tiles per real second); run: net movement since the last facing change;
## hold: real seconds the walk animation still holds; prev_face / face_age: the last turn, for FACE_HOLD;
## ghost: real seconds left for a customer the simulation removed (set when it leaves).
class Walk extends RefCounted:
	var hist: Array[Vector2i] = []
	var seen := 0
	var s := 0.0
	var v := 0.0
	var run := Vector2.ZERO
	var hold := 0.0
	var prev_face := -1
	var face_age := 1.0e6
	var placed := false
	var departed := false
	var ghost := 0.0


## Moves the shown positions along each customer's walk and keeps each person's facing. `dt` is the game-time step
## (real time x speed); the walk itself runs in real time, so the pace is the same at x1, x2 and x4.
func _sync_customers(dt: float) -> void:
	_alive.clear()
	var real := dt / float(maxi(_world.speed_setting, 1))
	var pace := WALK_TILES_PER_SEC * sqrt(float(maxi(_world.speed_setting, 1)))
	# #117 v2: the simulation itself walks slowly. The figure keeps to the simulation's own pace (a little
	# faster, so it never falls behind) and accelerates hard enough to stay within LAG_FOLLOW tiles of it.
	var sim_walk := float(_world.get("walk_tiles_per_game_second")) if _world.get("walk_tiles_per_game_second") != null else 0.0
	_follow = sim_walk > 0.0
	if _follow:
		pace = sim_walk * GameClock.GAME_SECONDS_PER_REAL_SECOND * float(maxi(_world.speed_setting, 1)) * FOLLOW_PACE
		_accel = maxf(WALK_ACCEL, pace * pace / (2.0 * LAG_FOLLOW))
	else:
		_accel = WALK_ACCEL
	for c in _world.customers:
		var id: String = c["customer_id"]
		_alive[id] = true
		var tile: Vector2i = c["tile"]
		var path: Array = c.get("path", [])
		if not c.has("path") and c.has("next") and c["next"] != tile:
			path = [c["next"]]   # a view without the full path: the next tile is all there is
		var tr: Walk = _track[id] if _track.has(id) else null
		if tr == null:
			tr = Walk.new()
			tr.hist.append(tile)
			tr.seen = int(c.get("moved", 0))
			_track[id] = tr
			if not _facing.has(id):
				_facing[id] = CustomerSprites.facing_for(Vector2(c.get("next", tile) - tile), CustomerSprites.FACING_E)
		else:
			_take_steps(tr, c)
		_walk(id, tr, path, float(c.get("progress", 0.0)), real, pace)
		if int(c.get("browse_left", -1)) > 0 and not _pick_faces.has(id):
			note_pick(id, String(c.get("fixture_id", "")))   # browsing a shelf (#117 v2): face it, as for a pick
	# Visual budget only (#117): when more figures than FIGURE_BUDGET are on screen (fast speeds feed customers
	# faster than they can walk out), departing figures fade GHOST_CROWD_RATE times faster. The simulation is untouched.
	var ghosts := _track.size() - _alive.size()   # tracked figures the simulation no longer has (approximately)
	var ghost_rate := GHOST_CROWD_RATE if _track.size() > FIGURE_BUDGET and ghosts > 0 else 1.0
	for id in (_track.keys() if ghosts > 0 else _NO_IDS):   # the key list is only built when someone has left
		if _alive.has(id):
			continue
		# A customer the simulation removed walks on to the end of its trail (a ghost), then is forgotten.
		var tr: Walk = _track[id]
		if not tr.departed:
			tr.departed = true
			tr.ghost = GHOST_MAX_SEC
		tr.ghost -= real * ghost_rate
		if tr.ghost > 0.0 and tr.s < float(tr.hist.size() - 1) - 0.001:
			_walk(id, tr, _NO_IDS, 0.0, real, pace)
		else:
			_track.erase(id)
			_pos.erase(id)
			_facing.erase(id)
			_look.erase(id)
			_pick_faces.erase(id)


## One step of the shown walk of one customer along its chain (history + remaining path).
func _walk(id: String, tr: Walk, path: Array, progress: float, real: float, pace: float) -> void:
	var hist: Array[Vector2i] = tr.hist
	var target := float(hist.size() - 1)
	if not path.is_empty():
		target += progress
	var s0 := tr.s
	var want := maxf(target - s0, 0.0)   # tiles the simulation is ahead of the shown figure
	var placed := tr.placed   # the trail was restarted this frame (spawn, teleport): place, do not walk
	tr.placed = false
	# At rest with no path (a queue, a shelf, a register): nothing moves, so skip the walk (per-frame cost, #117 perf).
	if want <= 0.0 and path.is_empty() and tr.v <= 0.0 and _pos.has(id) and not placed:
		tr.hold = maxf(tr.hold - real, 0.0)
		_update_facing(id, tr, Vector2.ZERO, _pos[id], real)   # still ages the turn hold and the pick pose
		return
	# Pace: walk at the calm pace while the simulation is ahead (faster only when far behind), and brake so the
	# figure comes to rest on its position instead of stopping dead.
	var lag_free := LAG_FOLLOW if _follow else WALK_LAG_FREE
	var goal := clampf(pace + maxf(want - lag_free, 0.0) * 1.5, pace, WALK_MAX) if want > 0.001 else 0.0
	var v := move_toward(tr.v, goal, _accel * real)
	v = minf(v, sqrt(2.0 * _accel * want))
	tr.v = v
	var s := s0 + minf(v * real, want)
	# Never past a turning tile in one frame (no corner cutting). A turn can only be passed when the step
	# crosses a tile boundary, which is rare per frame (pace 0.08 tile per frame at x1).
	if s > s0 and int(floor(s)) > int(floor(s0)):
		s = _clip_at_turn(hist, path, s0, s)
	tr.s = s
	tr.hold = maxf(tr.hold - real, 0.0)
	var pos := _point_on(hist, path, s)
	var old: Vector2 = _pos.get(id, pos)
	var delta := pos - old
	_pos[id] = pos
	if delta.length() > MOVE_EPS and delta.length() < PLACE_TILES:
		tr.hold = MOVING_HOLD
	_update_facing(id, tr, delta, pos, real)


## Facing with hysteresis: a figure turns only after walking FACE_HYSTERESIS tiles in a new direction (the net
## movement, so back-and-forth wobble cancels), and it does not turn straight back within FACE_HOLD real seconds
## of its last turn. A pick cue turns a standing figure toward its shelf.
func _update_facing(id: String, tr: Walk, delta: Vector2, pos: Vector2, real: float) -> void:
	var cur := int(_facing.get(id, CustomerSprites.FACING_E))
	var run := tr.run
	if delta.length() > MOVE_EPS and delta.length() < PLACE_TILES:
		run += delta
	tr.face_age += real
	if run.length() >= FACE_HYSTERESIS:
		var want := CustomerSprites.facing_for(run, cur)
		run = Vector2.ZERO
		var turning_back: bool = want == tr.prev_face
		if want != cur and not (turning_back and tr.face_age < FACE_HOLD):
			tr.prev_face = cur
			tr.face_age = 0.0
			cur = want
	tr.run = run
	if _pick_faces.has(id):
		var pick: Dictionary = _pick_faces[id]
		var away := pos.distance_to(pick["center"])
		if away < PICK_NEAR_TILES:
			pick["near"] = true
		elif pick["near"] and away > PICK_LEAVE_TILES:
			_pick_faces.erase(id)   # the figure walked away from its shelf: the pose is over
		elif delta.length() <= MOVE_EPS:
			cur = CustomerSprites.facing_for(pick["center"] - pos, cur)
	_facing[id] = cur


## Whether the figure is walking now (movement within MOVING_HOLD real seconds).
func _is_moving(id: String) -> bool:
	return _track.has(id) and (_track[id] as Walk).hold > 0.0


## Customers the simulation removed that are still walking out (drawn after the live customers).
func _ghost_views() -> Array:
	var out: Array = _ghost_buf
	out.clear()
	for id in _track.keys():
		if _alive.has(id):
			continue
		var tr: Walk = _track[id]
		var last: Vector2i = tr.hist.back()
		var alpha := clampf(tr.ghost / GHOST_FADE_SEC, 0.0, 1.0)
		out.append({"customer_id": id, "tile": last, "next": last, "path": [], "progress": 0.0, "phase": "EXIT", "alpha": alpha})
	return out


## Appends the tiles the simulation walked since the last call to the customer's history (from its trail).
## Any tile change the trail does not explain (a spawn, a teleport, a gap longer than the trail) restarts
## the history at the current tile: the one place where the shown position is placed rather than walked.
func _take_steps(tr: Walk, c: Dictionary) -> void:
	var tile: Vector2i = c["tile"]
	var moved := int(c.get("moved", 0))
	var new_steps := moved - tr.seen
	var hist: Array[Vector2i] = tr.hist
	var trail: Array = c["trail"] if c.has("trail") else _NO_TRAIL
	tr.seen = moved
	var still: bool = new_steps == 0 and hist.back() == tile
	var walked: bool = new_steps > 0 and new_steps <= trail.size() and trail.back() == tile
	if not (still or walked):
		# The simulation walked more steps than its trail keeps (a stall longer than the trail: at x4 about 0.3 s of
		# frames). The figure walks the free tiles between its last shown tile and the simulation's tile (catch-up),
		# never a straight jump. Any other change of tile is a placement (spawn, teleport), as before.
		var gap: Array = []
		if new_steps > 0 and not trail.is_empty() and trail.back() == tile:
			gap = _route_gap(hist.back(), tile)
		if gap.is_empty():
			hist.clear()
			hist.append(tile)
			tr.s = 0.0
			tr.v = 0.0
			tr.run = Vector2.ZERO
			tr.placed = true
			return
		for g in gap:
			hist.append(g)
		return
	for i in range(trail.size() - new_steps, trail.size()):   # only the steps since the last frame (usually one)
		hist.append(trail[i])
	while hist.size() > TRACK_KEEP and tr.s >= 1.0:
		hist.pop_front()
		tr.s -= 1.0


## Free tiles of the store for the catch-up route (fixture footprints only, as the simulation's paths see them).
var _blocked_cache: Dictionary = {}
const GAP_MARGIN := 12   # the catch-up search stays this many tiles around the two ends
const GAP_MAX := 400     # and gives up beyond this many visited tiles (then the figure is placed, as before)


## Shortest walk on free tiles from a to b (4-connected, exclusive of a, inclusive of b), or [] when there is none
## in the search box. Presentation only: it only decides how a stalled figure catches up.
func _route_gap(a: Vector2i, b: Vector2i) -> Array:
	_fixture_items()   # keeps _blocked_cache in step with the layout
	var lo := Vector2i(mini(a.x, b.x) - GAP_MARGIN, mini(a.y, b.y) - GAP_MARGIN)
	var hi := Vector2i(maxi(a.x, b.x) + GAP_MARGIN, maxi(a.y, b.y) + GAP_MARGIN)
	var prev := {a: a}
	var queue: Array[Vector2i] = [a]
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size() and head < GAP_MAX and not prev.has(b):
		var c: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = c + d
			if n.x < lo.x or n.y < lo.y or n.x > hi.x or n.y > hi.y or _blocked_cache.has(n) or prev.has(n):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(b):
		return []
	var out: Array = []
	var cur := b
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	return out


## The chain is the history followed by the remaining path, read by index without building a joined array
## (this runs for every customer every frame).
static func _chain_at(hist: Array, path: Array, i: int) -> Vector2i:
	var n := hist.size()
	return hist[i] if i < n else path[i - n]


static func _chain_size(hist: Array, path: Array) -> int:
	return hist.size() + path.size()


## Position s, clipped at the first turning tile of the chain in (s0, s] (the walk stops there for the frame).
## Only the tiles between s0 and s are looked at, so the cost does not grow with the length of the path.
static func _clip_at_turn(hist: Array, path: Array, s0: float, s: float) -> float:
	var last := _chain_size(hist, path) - 1
	var i := int(floor(s0)) + 1
	while i < last and float(i) <= s:
		if (_chain_at(hist, path, i) - _chain_at(hist, path, i - 1)) != (_chain_at(hist, path, i + 1) - _chain_at(hist, path, i)):
			return float(i)
		i += 1
	return s


## Point at chain position s (index + fraction): always on the straight segment between two chain tiles.
static func _point_on(hist: Array, path: Array, s: float) -> Vector2:
	var n := hist.size()
	var size := n + path.size()
	if size == 1 or s <= 0.0:
		return Vector2(hist[0])
	var i := int(floor(s))
	if i >= size - 1:
		return Vector2(hist[n - 1] if size - 1 < n else path[size - 1 - n])
	var a: Vector2i = hist[i] if i < n else path[i - n]
	var b: Vector2i = hist[i + 1] if i + 1 < n else path[i + 1 - n]
	return Vector2(a).lerp(Vector2(b), s - float(i))


## Pick cue (presentation only, real time): the customer faces the fixture it takes an item from, from the
## reservation event until it walks away from the shelf. Keyed by customer id -> {"center", "left", "near"}.
var _pick_faces: Dictionary = {}
## The pose lasts while the figure stands by its shelf: it starts within PICK_NEAR_TILES of the shelf centre and
## ends once it has walked beyond PICK_LEAVE_TILES. PICK_FACE_SECONDS is only a safety limit (real seconds).
const PICK_FACE_SECONDS := 12.0
const PICK_NEAR_TILES := 1.2
const PICK_LEAVE_TILES := 1.6


## Called for each product_pickup cue. Only turns the drawing; the simulation never reads it.
func note_pick(customer_id: String, fixture_id: String) -> void:
	var center := _fixture_center(fixture_id)
	if customer_id == "" or center == Vector2.INF:
		return
	_pick_faces[customer_id] = {"center": center, "left": PICK_FACE_SECONDS, "near": false}


func _age_pick_faces(delta: float) -> void:
	for id in _pick_faces.keys():
		_pick_faces[id]["left"] = float(_pick_faces[id]["left"]) - delta
		if float(_pick_faces[id]["left"]) <= 0.0:
			_pick_faces.erase(id)


## Centre of a placed fixture's footprint in tile units, or Vector2.INF when it is not on the layout.
func _fixture_center(fixture_id: String) -> Vector2:
	if _world == null or _world.fixture_catalog == null:
		return Vector2.INF
	for inst in _world.fixtures:
		if inst["instance_id"] != fixture_id:
			continue
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var sum := Vector2.ZERO
		for c in cells:
			sum += Vector2(c)
		return sum / float(maxi(cells.size(), 1)) if not cells.is_empty() else Vector2.INF
	return Vector2.INF


## Sprite sheet, variant id and animation time offset of a customer, looked up once per id (not per frame).
func _look_for(id: String) -> Array:
	if not _look.has(id):
		var variant_id := CustomerSprites.variant_for(id)
		_look[id] = [_people.variant(variant_id), variant_id, float(id.hash() % 7) * 0.37]
	return _look[id]


## Debug overlay only: the route the drawn figure still walks, as tile-unit points: its shown position, then every
## tile after it on the chain (walked trail first, then the remaining path). Empty when the figure is not tracked.
func shown_route(c: Dictionary) -> PackedVector2Array:
	var id: String = c["customer_id"]
	if not _track.has(id):
		return PackedVector2Array()
	var tr: Walk = _track[id]
	var hist: Array[Vector2i] = tr.hist
	var path: Array = c.get("path", [])
	var size := hist.size() + path.size()
	var out := PackedVector2Array([_pos[id] if _pos.has(id) else Vector2(hist.back())])
	var i := int(floor(tr.s)) + 1
	while i < size:
		out.append(Vector2(_chain_at(hist, path, i)))
		i += 1
	return out


## What is drawn for a customer now: {"pos", "facing", "anim", "frame", "variant"}.
func customer_view(c: Dictionary) -> Dictionary:
	var id: String = c["customer_id"]
	var anim := CustomerSprites.anim_for_state(c["phase"], _is_moving(id), _pick_faces.has(id) or int(c.get("browse_left", -1)) > 0)   # browsing at a shelf (#117 v2) poses too
	var look := _look_for(id)
	var sheet: Dictionary = look[0]
	var frame := 0
	if not sheet.is_empty() and not (sheet["animations"] as Dictionary).has(anim):
		anim = "checkout" if c.get("phase", "") == "REGISTER" and (sheet["animations"] as Dictionary).has("checkout") else "idle"   # the clerk sheet has idle + checkout only; no eat pose -> idle
	if not sheet.is_empty():
		frame = CustomerSprites.frame_index(sheet["animations"][anim], anim_time + float(look[2]))
	var pos: Vector2 = _pos[id] if _pos.has(id) else target_pos(c)
	return {"pos": pos, "facing": int(_facing.get(id, CustomerSprites.FACING_E)), "anim": anim, "frame": frame, "variant": look[1]}


const CUSTOMER_HEIGHT_M := 1.6
const CUSTOMER_HALF_W_M := 0.16
const CUSTOMER_COLOR := Color("3d6fb5")
const OUTLINE_ZOOM := 1.5
const FADE_ALPHA := 0.35
const XRAY_ALPHA := 0.5


## The draw list in back-to-front order: {"kind": "fixture"|"customer", "rect": Rect2, ...}.
func compose() -> Array:
	var fixture_items := _fixture_items()   # refreshes _fixed when the layout changed
	var fixed := _fixed
	_clear_fade()
	if _synced:
		_synced = false   # _process has just moved the figures for this frame
	else:
		_sync_customers(0.0)
	var items: Array = fixture_items.duplicate()
	var cells: Array[Vector2i] = []
	for c in _world.customers:
		_add_customer_item(c, items, cells)
	for c in _ghost_views():
		_add_customer_item(c, items, cells)
	var sorted := DrawOrder.sorted_fixed(items, fixed, cells)
	_mark_see_through(sorted)
	return sorted


## One customer's draw item (its cell from the shown position, its alpha for departing figures).
func _add_customer_item(c: Dictionary, items: Array, cells: Array[Vector2i]) -> void:
	var shown: Vector2 = _pos.get(c["customer_id"], target_pos(c))
	var cell := Vector2i(roundi(shown.x), roundi(shown.y))
	items.append({"kind": "customer", "rect": DrawOrder.cell_rect(cell), "customer": c, "pos": shown, "alpha": float(c.get("alpha", 1.0))})
	cells.append(cell)


## Segment items of the fixtures; rebuilt only when the layout revision changes.
var _fixture_items_cache: Array = []
var _fixture_revision := -2
var _fixture_count := -1
var _fixed: DrawOrder.FixedSet   # the fixture segments in their depth order, rebuilt with them
var _faded: Array = []           # items given "fade" by the last compose, cleared by the next one


func _fixture_items() -> Array:
	if _world.revision == _fixture_revision and _world.fixtures.size() == _fixture_count:
		return _fixture_items_cache
	_fixture_revision = _world.revision
	_fixture_count = _world.fixtures.size()
	_fixture_items_cache = []
	_seg_cache.clear()   # segment keys and commands belong to the item list that was just rebuilt
	_blocked_cache = {}
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		for c in cells:
			_blocked_cache[c] = true
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-1, -1)
		for c in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var segs := DrawOrder.column_segments(cells)
		for k in segs.size():
			_fixture_items_cache.append({
				"kind": "fixture", "rect": segs[k]["rect"], "inst": inst, "def": def, "lo": lo, "hi": hi,
				"column": segs[k]["column"], "first": k == 0, "last": k == segs.size() - 1,
			})
	var rects: Array[Rect2] = []
	for it in _fixture_items_cache:
		rects.append(it["rect"])
	_fixed = DrawOrder.FixedSet.new(rects)
	return _fixture_items_cache


func _clear_fade() -> void:
	for it in _faded:
		it.erase("fade")
	_faded.clear()


## Things that stand in front of the selected fixture / customer and cover it are drawn translucent,
## so what the player picked stays readable behind a tall case (#24).
func _mark_see_through(items: Array) -> void:
	var proj: IsoProjection = _world.projection
	var rect := Rect2()
	var bounds := Rect2()
	var found := false
	var sel_id: String = _world.selected_fixture_id()   # once per draw, not once per item
	if sel_id == "" and _world.selected_customer == "":
		return   # nothing selected: nothing can be in front of it
	for it in items:
		if it["kind"] == "fixture" and sel_id == it["inst"]["instance_id"]:
			rect = it["rect"] if not found else rect.merge(it["rect"])
			bounds = _fixture_bounds(proj, it) if not found else bounds.merge(_fixture_bounds(proj, it))
			found = true
		elif it["kind"] == "customer" and _world.selected_customer == it["customer"]["customer_id"]:
			rect = it["rect"]
			bounds = OverlayModel.customer_rect(proj, it["pos"])
			found = true
	if not found:
		return
	for it in items:
		if it["kind"] != "fixture" or sel_id == it["inst"]["instance_id"]:
			continue
		if DrawOrder.is_behind(rect, it["rect"]) and _fixture_bounds(proj, it).intersects(bounds):
			it["fade"] = true
			_faded.append(it)


func _fixture_bounds(proj: IsoProjection, it: Dictionary) -> Rect2:
	var cells := StoreGrid.footprint_cells(it["def"]["footprint"], it["inst"]["x"], it["inst"]["y"], it["inst"]["rotation"])
	return OverlayModel.fixture_bounds(proj, cells, float(it["def"]["dimensions_m"]["height"]))


## Customers hidden behind a fixture get a translucent copy on top (information / layout modes).
func hidden_customers(items: Array) -> Array:
	var out: Array = []
	var proj: IsoProjection = _world.projection
	for it in items:
		if it["kind"] != "customer":
			continue
		var r := OverlayModel.customer_rect(proj, it["pos"])
		for other in items:
			if other["kind"] == "fixture" and DrawOrder.is_behind(it["rect"], other["rect"]) and _fixture_bounds(proj, other).intersects(r):
				out.append(it)
				break
	return out


func _draw() -> void:
	if _world == null or _world.fixture_catalog == null:
		return
	var t0 := Time.get_ticks_usec()
	_draw_all()
	draw_usec_total += Time.get_ticks_usec() - t0
	draw_count += 1


## Cost of the script side of drawing (for tools/perf_bench.gd).
var draw_usec_total := 0
var draw_count := 0
var prof_compose := 0
var prof_customers := 0
var prof_fixtures := 0


func _draw_all() -> void:
	var proj: IsoProjection = _world.projection
	var boxes_done := {}
	var q0 := Time.get_ticks_usec()
	var ordered := compose()
	prof_compose += Time.get_ticks_usec() - q0
	for it in ordered:
		if it["kind"] == "customer":
			q0 = Time.get_ticks_usec()
			_draw_customer(proj, it["customer"], float(it.get("alpha", 1.0)))
			prof_customers += Time.get_ticks_usec() - q0
			continue
		var entry := _sprites.rotation_entry(it["inst"]["type_id"], int(it["inst"]["rotation"]))
		if not entry.is_empty():
			q0 = Time.get_ticks_usec()
			_draw_sprite(proj, it, entry)
			prof_fixtures += Time.get_ticks_usec() - q0
		elif not boxes_done.has(it["inst"]["instance_id"]):
			boxes_done[it["inst"]["instance_id"]] = true   # the placeholder is one box, drawn with its first segment in order
			_draw_box(proj, it)
	if _world.overlay_mode != OverlayModel.Mode.NORMAL or _world.selected_customer != "":
		for it in hidden_customers(ordered):
			_draw_customer(proj, it["customer"], XRAY_ALPHA)


## Sprite person (#23); a plain bar stands in when the art is missing. Anchor = feet, shared by all frames.
func _draw_customer(proj: IsoProjection, c: Dictionary, alpha: float = 1.0) -> void:
	var view := customer_view(c)
	var pos: Vector2 = view["pos"]
	var sheet := _people.variant(view["variant"])
	if sheet.is_empty():
		_draw_customer_bar(proj, pos)
		return
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var top_left := proj.sprite_top_left(proj.world_to_screen(pos.x, pos.y), sheet["anchor"])
	var shadow: Texture2D = sheet["shadow"]
	var tint := Color(1, 1, 1, alpha)
	draw_texture_rect(shadow, Rect2(top_left, shadow.get_size() * s), false, tint)
	var tex: Texture2D = sheet["frames"][view["facing"]][view["anim"]][view["frame"]]
	draw_texture_rect(tex, Rect2(top_left, tex.get_size() * s), false, tint)


func _draw_customer_bar(proj: IsoProjection, pos: Vector2) -> void:
	var foot := proj.world_to_screen(pos.x, pos.y)
	var hw := CUSTOMER_HALF_W_M * IsoProjection.HALF_TILE_W * proj.zoom
	draw_colored_polygon(_ellipse(foot, hw * 1.6, hw * 0.8), Color(0, 0, 0, 0.25))
	var top := proj.world_to_screen(pos.x, pos.y, CUSTOMER_HEIGHT_M)
	var body := Rect2(Vector2(foot.x - hw, top.y), Vector2(hw * 2.0, foot.y - top.y))
	draw_rect(body, CUSTOMER_COLOR)
	draw_rect(body, CUSTOMER_COLOR.darkened(0.5), false, 1.0)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Screen x range owned by this segment's column (a tile diamond is 2 * HALF_TILE_W * zoom wide);
## the outermost segments reach past the sprite edge so nothing of the sprite is lost.
func _strip(proj: IsoProjection, it: Dictionary) -> Vector2:
	var lo: Vector2i = it["lo"]
	var hw := IsoProjection.HALF_TILE_W * proj.zoom
	var x_center := proj.world_to_screen(lo.x, lo.y).x + float(int(it["column"]) - (lo.x - lo.y)) * hw
	var x0 := x_center - hw
	var x1 := x_center + hw
	if it["first"]:
		x0 = -1e6
	if it["last"]:
		x1 = 1e6
	return Vector2(x0, x1)


## Retained draw commands of fixture segments (#25), keyed "instance_id/column". A segment's commands
## depend only on zoom, its screen ground point, its stock and its fade state, so they are rebuilt when
## one of those changes and replayed otherwise. Customers moving never invalidate them, and compose()
## order is unchanged because replay happens at the same point of the back-to-front loop.
var _seg_cache: Dictionary = {}


## Layers back to front: shadow, body, products, glass_front, each cut to this segment's column.
func _draw_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var ground := proj.world_to_screen(lo.x, lo.y)
	var stock: Dictionary = _world.shelf_stock.get(it["inst"]["instance_id"], {})
	var skus: Dictionary = _world.shelf_skus.get(it["inst"]["instance_id"], {})
	var fade: bool = it.get("fade", false)
	var key := "%s/%d" % [it["inst"]["instance_id"], int(it["column"])]
	var hit: Dictionary = _seg_cache.get(key, {})
	if hit.is_empty() or hit["zoom"] != proj.zoom or hit["ground"] != ground or hit["fade"] != fade or hit["stock"] != stock or hit["skus"] != skus:
		var cmds: Array = []
		_emit_sprite(proj, it, entry, ground, stock, skus, cmds)
		hit = {"zoom": proj.zoom, "ground": ground, "fade": fade, "stock": stock.duplicate(true), "skus": skus.duplicate(true), "cmds": cmds}
		_seg_cache[key] = hit
	_replay(hit["cmds"])


## Command = [type, args...]: 0 texture region (tex, dst, src, tint), 1 rect (rect, color, filled, width),
## 2 line (a, b, color, width), 3 texture rect (tex, rect, tint: a package icon). Emitting in the original
## order keeps the output identical.
func _replay(cmds: Array) -> void:
	for c in cmds:
		match c[0]:
			0:
				draw_texture_rect_region(c[1], c[2], c[3], c[4])
			1:
				draw_rect(c[1], c[2], c[3], c[4])
			3:
				draw_texture_rect(c[1], c[2], false, c[3])
			_:
				draw_line(c[1], c[2], c[3], c[4])


func _emit_sprite(proj: IsoProjection, it: Dictionary, entry: Dictionary, ground: Vector2, stock: Dictionary, skus: Dictionary, cmds: Array) -> void:
	var top_left := proj.sprite_top_left(ground, entry["anchor"])
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	var strip := _strip(proj, it)
	var tint := Color(1, 1, 1, FADE_ALPHA if it.get("fade", false) else 1.0)
	var layers: Dictionary = entry["layers"]
	for name in FixtureSprites.LAYER_ORDER_BELOW:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint, cmds)
	if draws_products(entry):
		_emit_products(it, entry, top_left, s, proj.zoom, strip, stock, skus, tint.a, cmds)
	for name in FixtureSprites.LAYER_ORDER_ABOVE:
		if layers.has(name):
			_blit(layers[name], top_left, s, strip, tint, cmds)


func _blit(tex: Texture2D, top_left: Vector2, s: float, strip: Vector2, tint: Color, cmds: Array) -> void:
	var size := tex.get_size()
	var u0 := clampf((strip.x - top_left.x) / s, 0.0, size.x)
	var u1 := clampf((strip.y - top_left.x) / s, 0.0, size.x)
	if u1 - u0 < 0.5:
		return
	cmds.append([0, tex, Rect2(top_left + Vector2(u0 * s, 0.0), Vector2(u1 - u0, size.y) * s), Rect2(u0, 0.0, u1 - u0, size.y), tint])


## Items are drawn on top of the sprite unless the variant has its products baked in (painted FULL, issue #91).
static func draws_products(entry: Dictionary) -> bool:
	return not bool(entry.get("baked", false))


## True when shelf items are drawn as package icons: close zoom and not the far "bar" LOD. Otherwise rects.
static func use_icons(zoom: float) -> bool:
	return zoom >= ICON_MIN_ZOOM and ShelfDisplay.lod(zoom) != "bar"


## The product dictionary held in one slot, or {} when the slot holds nothing or the SKU is unknown
## (those items keep the plain rect). `per_slot` is {slot_id: sku_id} of one fixture.
static func sku_in_slot(per_slot: Dictionary, slot_id: String, products: ProductCatalog) -> Dictionary:
	var sku_id := str(per_slot.get(slot_id, ""))
	if sku_id == "" or products == null or not products.has_sku(sku_id):
		return {}
	return products.get_sku(sku_id)


func _emit_products(it: Dictionary, entry: Dictionary, top_left: Vector2, s: float, zoom: float, strip: Vector2, stock: Dictionary, skus: Dictionary, alpha: float, cmds: Array) -> void:
	var slots: Dictionary = entry["slots"]
	if slots.is_empty():
		return
	var def: Dictionary = it["def"]
	var color := _color_for(def)
	var lod := ShelfDisplay.lod(zoom)
	var icons := use_icons(zoom)
	var small := ProductSprites.sprite_lod(zoom) == "small"
	var rot := int(it["inst"]["rotation"])
	var half := ITEM_W * 0.5 * s
	var size := Vector2(ITEM_W * s, ITEM_H * s)
	var outline := zoom >= OUTLINE_ZOOM   # the outline doubles the draw commands; small items read fine without it
	var edge := Color(color.darkened(0.45), alpha)
	var fill := Color(color, alpha)
	var anchors := _slot_anchors(entry)
	for slot in def["shelf_slots"]:
		var sid: String = slot["slot_id"]
		if not anchors.has(sid):
			continue
		var pts: PackedVector2Array = anchors[sid]
		var qty := int(stock.get(sid, 0))
		var cap := int(slot["capacity_units"])
		if lod == "bar":
			_emit_row_bar(pts, ShelfDisplay.fill_ratio(qty, cap), color, top_left, s, strip, cmds)
			continue
		var sku: Dictionary = sku_in_slot(skus, sid, _world.product_catalog)
		var n := mini(ShelfDisplay.visible_items(qty, cap, zoom), pts.size())
		if n == 0:
			_emit_price_tag(top_left + pts[0] * s, zoom, strip, alpha, cmds)
			continue
		var sku_tint := ProductSprites.tint_for(str(sku.get("sku_id", "")), str(sku.get("category", "")))
		var tint := Color(sku_tint.r, sku_tint.g, sku_tint.b, alpha)
		# An item stays within its row: at most ROW_FILL of the gap to the board above, and no wider than its spacing.
		var max_h := float(_row_gaps(entry).get(sid, INF)) * s * ROW_FILL
		# Item 0 is the end nearest the viewer's right; draw far items first so near ones overlap.
		for i in range(n - 1, -1, -1):
			var a: Vector2 = top_left + pts[i] * s
			if a.x < strip.x or a.x >= strip.y:
				continue   # belongs to another column segment
			var spr := _art.sprite(str(sku.get("visual_id", "")), rot, ProductSprites.variant_for(sid, i), small) if not sku.is_empty() else {}
			if not spr.is_empty():
				var max_w := _item_spacing(pts, i) * s * SPACING_FILL
				var px := ProductSprites.screen_size(spr, zoom, Vector2(max_w, max_h))
				var base := a + Vector2(ProductSprites.jitter_px(sid, i), 0.0)
				cmds.append([3, spr["texture"], Rect2(base - Vector2(px.x * 0.5, px.y), px), tint])
				continue
			var r := Rect2(a - Vector2(half, ITEM_H * s), size)
			if icons and not sku.is_empty():
				cmds.append([3, ProductIcons.texture(sku, ICON_PX), r, Color(1, 1, 1, alpha)])
				continue
			cmds.append([1, r, fill, true, -1.0])
			if outline:
				cmds.append([1, r, edge, false, 1.0])


## A small price tag on the shelf front of an empty row (the bare shelf otherwise).
func _emit_price_tag(a: Vector2, zoom: float, strip: Vector2, alpha: float, cmds: Array) -> void:
	if a.x < strip.x or a.x >= strip.y:
		return
	var w := 7.0 * maxf(zoom, 0.75)
	var h := 5.0 * maxf(zoom, 0.75)
	var r := Rect2(a + Vector2(-w * 0.5, -h - 2.0 * zoom), Vector2(w, h))
	cmds.append([1, r, Color(1.0, 0.86, 0.3, alpha), true, -1.0])
	cmds.append([1, r, Color(0.2, 0.16, 0.1, alpha), false, 1.0])


## Horizontal distance (source px) from item i to its neighbour along the row: the item may be this wide at most,
## so neighbours overlap by about SPACING_FILL at most. Unbounded for a single-item slot.
static func _item_spacing(pts: PackedVector2Array, i: int) -> float:
	var nb := i + 1 if i + 1 < pts.size() else i - 1
	if nb < 0 or nb >= pts.size():
		return INF
	var d := absf(pts[nb].x - pts[i].x)
	if d < 1.0:
		d = pts[nb].distance_to(pts[i])
	return d if d >= 1.0 else INF


## Vertical distance (source px) from each slot's first item up to the board above it, at the same column; the top
## row measures to the fixture top. Cached on the entry (the manifest never changes at runtime).
func _row_gaps(entry: Dictionary) -> Dictionary:
	if entry.has("_gaps"):
		return entry["_gaps"]
	var anchors := _slot_anchors(entry)
	var out := {}
	for sid in anchors:
		var base: Vector2 = anchors[sid][0]
		var gap := base.y   # no board above: the distance to the fixture top
		for other in anchors:
			var o: Vector2 = anchors[other][0]
			if other != sid and absf(o.x - base.x) < 2.0 and o.y < base.y:
				gap = minf(gap, base.y - o.y)
		out[sid] = gap
	entry["_gaps"] = out
	return out


## Slot anchors of a sprite entry as {slot_id: PackedVector2Array}, built once (the manifest never changes at runtime).
func _slot_anchors(entry: Dictionary) -> Dictionary:
	if entry.has("_anchors"):
		return entry["_anchors"]
	var out := {}
	var slots: Dictionary = entry["slots"]
	for key in slots:
		var k: String = key
		var cut := k.rfind("_item")
		if cut < 0:
			continue
		var sid := k.substr(0, cut)
		if not out.has(sid):
			var pts := PackedVector2Array()
			var n := 0
			while slots.has("%s_item%d" % [sid, n]):
				pts.append(slots["%s_item%d" % [sid, n]])
				n += 1
			out[sid] = pts
	entry["_anchors"] = out
	return out


func _emit_row_bar(pts: PackedVector2Array, ratio: float, color: Color, top_left: Vector2, s: float, strip: Vector2, cmds: Array) -> void:
	var a: Vector2 = top_left + pts[0] * s
	var last := pts.size() - 1
	var b: Vector2 = top_left + pts[last] * s
	if last == 0:
		b = a + Vector2(18.0 * s, 9.0 * s)   # single-cell slot: short bar along the +X screen direction
	var mid := (a.x + b.x) * 0.5
	if mid < strip.x or mid >= strip.y:
		return   # the bar is drawn by the segment that holds its middle
	cmds.append([2, a, b, Color(0, 0, 0, 0.25), 4.0])
	if ratio > 0.0:
		cmds.append([2, a, a.lerp(b, ratio), color, 4.0])


func _color_for(def: Dictionary) -> Color:
	if def["allowed_categories"].is_empty():
		return REGISTER_COLOR
	return CATEGORY_COLOR.get(def["allowed_categories"][0], REGISTER_COLOR)


func _draw_box(proj: IsoProjection, it: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var hi: Vector2i = it["hi"]
	var h: float = float(it["def"]["dimensions_m"]["height"])
	var x0 := lo.x - INSET
	var y0 := lo.y - INSET
	var x1 := hi.x + INSET
	var y1 := hi.y + INSET
	var base := _color_for(it["def"])
	var a_g := proj.world_to_screen(x0, y0)
	var b_g := proj.world_to_screen(x1, y0)
	var c_g := proj.world_to_screen(x1, y1)
	var d_g := proj.world_to_screen(x0, y1)
	var a_t := proj.world_to_screen(x0, y0, h)
	var b_t := proj.world_to_screen(x1, y0, h)
	var c_t := proj.world_to_screen(x1, y1, h)
	var d_t := proj.world_to_screen(x0, y1, h)
	draw_colored_polygon(PackedVector2Array([b_g, c_g, c_t, b_t]), base.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([d_g, c_g, c_t, d_t]), base.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([a_t, b_t, c_t, d_t]), base)
	var edge := Color(0, 0, 0, 0.45)
	draw_polyline(PackedVector2Array([a_t, b_t, c_t, d_t, a_t]), edge, 1.5)
	draw_polyline(PackedVector2Array([d_t, d_g, c_g, c_t]), edge, 1.5)
	draw_line(c_g, b_g, edge, 1.5)
	var w := 4.0 * maxf(proj.zoom, 0.75)
	for e in it["def"]["access_edges"]:
		match PlacementRules.rotate_edge(e, it["inst"]["rotation"]):
			"N":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x1, y0, h), FRONT_COLOR, w)
			"E":
				draw_line(proj.world_to_screen(x1, y0, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"S":
				draw_line(proj.world_to_screen(x0, y1, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"W":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x0, y1, h), FRONT_COLOR, w)
