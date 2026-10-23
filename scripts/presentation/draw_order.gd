class_name DrawOrder
extends RefCounted
## Back-to-front order of the things drawn in the store (02 §F): fixture segments and customers.
## Each item has a `rect` in tile-edge coordinates (a tile (x, y) covers [x-0.5, x+0.5]). Item A is
## behind item B when A lies entirely on the smaller-x or the smaller-y side of B; items that are
## neither (they never overlap on screen) keep a stable depth order. Sorting by the foot point alone
## would put a whole 1x2 shelf in front of a customer walking past its far end.


## Cells grouped by screen column (x - y). An orthographic Z axis is vertical on screen, so a column
## of a tall fixture can be cut out of its sprite exactly and ordered on its own.
## -> Array of {"column": int, "rect": Rect2, "cells": Array[Vector2i]}, left to right.
static func column_segments(cells: Array[Vector2i]) -> Array[Dictionary]:
	var by_col := {}
	for c in cells:
		var col := c.x - c.y
		if not by_col.has(col):
			by_col[col] = []
		by_col[col].append(c)
	var cols: Array = by_col.keys()
	cols.sort()
	var out: Array[Dictionary] = []
	for col in cols:
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for c in by_col[col]:
			lo = Vector2(minf(lo.x, c.x - 0.5), minf(lo.y, c.y - 0.5))
			hi = Vector2(maxf(hi.x, c.x + 0.5), maxf(hi.y, c.y + 0.5))
		out.append({"column": col, "rect": Rect2(lo, hi - lo), "cells": by_col[col]})
	return out


static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c.x - 0.5, c.y - 0.5), Vector2.ONE)


const EPS := 1e-6


static func is_behind(a: Rect2, b: Rect2) -> bool:
	var ax := a.end.x <= b.position.x + EPS
	var ay := a.end.y <= b.position.y + EPS
	var bx := b.end.x <= a.position.x + EPS
	var by := b.end.y <= a.position.y + EPS
	if (ax and by) or (ay and bx):
		return false   # diagonal neighbours: no shared screen area
	return ax or ay


## Stable topological sort of items (each has "rect" and "kind"); returns a new back-to-front array.
## Ready items (everything behind them is already out) are taken in depth-key order.
## Two customers never share a cell, so no constraint is computed between them.
static func sorted(items: Array) -> Array:
	var n := items.size()
	var rects: Array[Rect2] = []
	var keys := PackedFloat64Array()
	var person := PackedByteArray()
	keys.resize(n)
	person.resize(n)
	for i in n:
		var r: Rect2 = items[i]["rect"]
		rects.append(r)
		keys[i] = _depth_key(r)
		person[i] = 1 if items[i].get("kind", "") == "customer" else 0
	var pending := PackedInt32Array()
	pending.resize(n)
	var edges := EdgeList.new(n)
	for i in n:
		for j in range(i + 1, n):
			if person[i] == 1 and person[j] == 1:
				continue
			if is_behind(rects[j], rects[i]):   # j is drawn first
				edges.add(j, i)
				pending[i] += 1
			elif is_behind(rects[i], rects[j]):
				edges.add(i, j)
				pending[j] += 1
	return _emit(items, _pick_order(keys, pending, [], edges))


## Same order as sorted(items) when items = the fixed set's fixtures (first, in the set's order)
## followed by one customer per entry of cells (its rect is cell_rect(cell)). The constraints among
## the fixtures and the constraints of a customer on a given cell are cached, so a frame only pays for
## the customers that moved onto new cells.
static func sorted_fixed(items: Array, fixed: FixedSet, cells: Array[Vector2i]) -> Array:
	var nf := fixed.rects.size()
	var n := nf + cells.size()
	var keys := fixed.keys.duplicate()
	keys.resize(n)
	var pending := fixed.pending.duplicate()
	pending.resize(n)
	var edges := EdgeList.new(n)
	for k in cells.size():
		var node := nf + k
		keys[node] = _depth_key(cell_rect(cells[k]))
		var rel: Array = fixed.relations(cells[k])
		for f in rel[0]:   # fixtures drawn before this customer
			edges.add(f, node)
			pending[node] += 1
		for f in rel[1]:   # fixtures drawn after this customer
			edges.add(node, f)
			pending[f] += 1
	return _emit(items, _pick_order(keys, pending, fixed.succ, edges))


static func _depth_key(r: Rect2) -> float:
	var c := r.get_center()
	return c.x + c.y


static func _emit(items: Array, order: PackedInt32Array) -> Array:
	var out: Array = []
	for k in order.size():
		out.append(items[order[k]])
	return out


## Kahn's algorithm with a min-(key, index) pick. pending counts the constraints still open per node;
## static_succ[i] (for the fixed nodes) and edges hold the successors. The pick rule is unique, so the
## order does not depend on how the ready set is stored.
static func _pick_order(keys: PackedFloat64Array, pending: PackedInt32Array, static_succ: Array, edges: EdgeList) -> PackedInt32Array:
	var n := keys.size()
	var ready := PackedInt32Array()
	for i in n:
		if pending[i] == 0:
			ready.append(i)
	var done := PackedByteArray()
	done.resize(n)
	var order := PackedInt32Array()
	while order.size() < n:
		var pick := -1
		var at := -1
		for k in ready.size():
			var i: int = ready[k]
			if pick < 0 or keys[i] < keys[pick] or (keys[i] == keys[pick] and i < pick):
				pick = i
				at = k
		if pick >= 0:
			ready[at] = ready[ready.size() - 1]
			ready.resize(ready.size() - 1)
		else:   # a cycle cannot happen for disjoint boxes; fall back to depth order anyway
			for i in n:
				if done[i] == 0 and (pick < 0 or keys[i] < keys[pick]):
					pick = i
		done[pick] = 1
		order.append(pick)
		if pick < static_succ.size():
			for s in static_succ[pick]:
				pending[s] -= 1
				if pending[s] == 0 and done[s] == 0:
					ready.append(s)
		var e: int = edges.head[pick]
		while e >= 0:
			var s: int = edges.to[e]
			pending[s] -= 1
			if pending[s] == 0 and done[s] == 0:
				ready.append(s)
			e = edges.link[e]
	return order


## Adjacency in packed arrays: edge e goes from its tail to to[e]; head[a] is the first edge out of a.
class EdgeList extends RefCounted:
	var head := PackedInt32Array()
	var link := PackedInt32Array()
	var to := PackedInt32Array()

	func _init(n: int) -> void:
		head.resize(n)
		head.fill(-1)

	func add(a: int, b: int) -> void:
		link.append(head[a])
		to.append(b)
		head[a] = to.size() - 1


## The fixed items of one layout (fixture segments in their order). Fixtures never move within a layout
## revision, so their mutual constraints are computed once, and a customer's constraints are cached per cell.
class FixedSet extends RefCounted:
	var rects: Array[Rect2] = []
	var keys := PackedFloat64Array()
	var pending := PackedInt32Array()   # fixtures that must be drawn before each fixture
	var succ: Array = []                # succ[f]: fixtures drawn after f
	var _memo := {}                     # cell -> [fixtures before a customer there, fixtures after it]

	func _init(fixture_rects: Array[Rect2]) -> void:
		rects = fixture_rects
		var n := rects.size()
		keys.resize(n)
		pending.resize(n)
		succ.resize(n)
		for i in n:
			keys[i] = DrawOrder._depth_key(rects[i])
			succ[i] = []
		for i in n:
			for j in range(i + 1, n):
				if DrawOrder.is_behind(rects[j], rects[i]):
					succ[j].append(i)
					pending[i] += 1
				elif DrawOrder.is_behind(rects[i], rects[j]):
					succ[i].append(j)
					pending[j] += 1

	## Fixtures that must be drawn before (behind) and after (in front of) a customer standing on `cell`.
	func relations(cell: Vector2i) -> Array:
		if _memo.has(cell):
			return _memo[cell]
		var r := DrawOrder.cell_rect(cell)
		var before := PackedInt32Array()
		var after := PackedInt32Array()
		for f in rects.size():
			if DrawOrder.is_behind(rects[f], r):
				before.append(f)
			elif DrawOrder.is_behind(r, rects[f]):
				after.append(f)
		var out := [before, after]
		_memo[cell] = out
		return out
