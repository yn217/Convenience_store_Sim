class_name Passersby
extends RefCounted
## People walking past the store on the pavement (#142). Presentation only: they never enter, the simulation
## never sees them, and nothing is saved. Who walks when is a pure function of the game clock (a hash per game
## minute), so a pause freezes them and a reload shows the same people. They use the entrance wall's pavement row
## (CustomerAI.away_route) from one end to the other, at the customers' walking speed, and their views have the
## same fields as the simulation's customer views, so the presenter draws and animates them like customers.

const MINUTE := 60
const ID_PREFIX := "ped_"


## Views of the passers-by on the pavement at `time_sec`. `per_day` people a day, spread over the hours like the
## visitors (DemandModel hour weights); `walk` tiles per game second.
static func views(time_sec: int, grid_w: int, grid_h: int, entrances: Array, walk: float, per_day: int) -> Array:
	var out: Array = []
	if per_day <= 0 or walk <= 0.0 or entrances.is_empty() or grid_w <= 0:
		return out
	var row := _row(grid_w, grid_h, entrances[0])
	var length := row.size()
	var duration := int(ceil(float(length - 1) / walk))
	var weights := DemandModel.normalized_hour_weights()
	var first := (time_sec - duration) / MINUTE
	for m in range(maxi(first, 0), time_sec / MINUTE + 1):
		var hour := (m / 60) % 24
		var p := float(per_day) * float(weights[hour]) / 24.0 / 60.0   # people per game minute
		if _hash01(m, 1) >= p:
			continue
		var t0 := m * MINUTE + int(_hash01(m, 2) * MINUTE)
		var s := float(time_sec - t0) * walk
		if s < 0.0 or s > float(length - 1):
			continue
		var forward := _hash01(m, 3) < 0.5
		var tiles: Array = row if forward else _reversed(row)
		var i := int(floor(s))
		var view := {
			"customer_id": "%s%06d" % [ID_PREFIX, m], "passerby": true, "phase": "WALK_AWAY",
			"tile": tiles[i], "path": tiles.slice(i + 1), "next": tiles[mini(i + 1, length - 1)],
			"progress": s - float(i) if i < length - 1 else 0.0,
			"trail": tiles.slice(maxi(i - 31, 0), i + 1), "moved": i,
			"fixture_id": "", "sku_id": "", "register_id": "", "queue_slot": -1, "outcome": "",
		}
		out.append(view)
	return out


static var _row_key := []
static var _row_cache: Array = []


## The whole pavement row of the entrance wall, low end to high end (cached per store size and door).
static func _row(grid_w: int, grid_h: int, door: Vector2i) -> Array:
	var key := [grid_w, grid_h, door]
	if key == _row_key:
		return _row_cache
	var ents: Array[Vector2i] = [door]
	var grid := StoreGrid.create("passersby", grid_w, grid_h, ents)
	# away_route starts at the door; a passer-by walks the whole row: low end -> high end (or back).
	var low: Array = CustomerAI.away_route(grid, door, true).slice(1)
	low.reverse()
	var high: Array = CustomerAI.away_route(grid, door, false).slice(1)
	_row_cache = low + high.slice(1)   # low end ... door column ... high end
	_row_key = key
	return _row_cache


static func _reversed(a: Array) -> Array:
	var b := a.duplicate()
	b.reverse()
	return b


## Deterministic 0..1 from a game minute and a salt.
static func _hash01(m: int, salt: int) -> float:
	var h := hash("%d:%d" % [m, salt])
	return float(absi(h) % 100000) / 100000.0
