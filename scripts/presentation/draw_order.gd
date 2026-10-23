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


## Stable topological sort of items (each has "rect"); returns a new back-to-front array.
## Ready items (everything behind them is already out) are taken in depth-key order.
static func sorted(items: Array) -> Array:
	var n := items.size()
	var after: Array = []        # after[j] = items that must come later than j
	var pending := PackedInt32Array()
	var keys := PackedFloat64Array()
	pending.resize(n)
	keys.resize(n)
	var x0 := PackedFloat64Array()
	var y0 := PackedFloat64Array()
	var x1 := PackedFloat64Array()
	var y1 := PackedFloat64Array()
	var person := PackedByteArray()
	for i in n:
		after.append([] as Array[int])
		var r: Rect2 = items[i]["rect"]
		x0.append(r.position.x)
		y0.append(r.position.y)
		x1.append(r.end.x)
		y1.append(r.end.y)
		keys[i] = r.get_center().x + r.get_center().y
		person.append(1 if items[i].get("kind", "") == "customer" else 0)
	for i in n:
		for j in range(i + 1, n):
			if person[i] == 1 and person[j] == 1:
				continue   # two people never share a cell; the depth key orders them
			# j behind i: j lies wholly on the smaller-x or smaller-y side of i (and i is not the reverse, diagonal case)
			var jx := x1[j] <= x0[i] + EPS
			var jy := y1[j] <= y0[i] + EPS
			var ix := x1[i] <= x0[j] + EPS
			var iy := y1[i] <= y0[j] + EPS
			if (jx and iy) or (jy and ix):
				continue   # diagonal neighbours: no shared screen area
			if jx or jy:
				after[j].append(i)
				pending[i] += 1
			elif ix or iy:
				after[i].append(j)
				pending[j] += 1
	var ready: Array[int] = []
	for i in n:
		if pending[i] == 0:
			ready.append(i)
	var done := PackedByteArray()
	done.resize(n)
	var out: Array = []
	while out.size() < n:
		var pick := -1
		var at := -1
		for k in ready.size():
			var i := ready[k]
			if pick < 0 or keys[i] < keys[pick] or (keys[i] == keys[pick] and i < pick):
				pick = i
				at = k
		if pick >= 0:
			ready.remove_at(at)
		else:   # a cycle cannot happen for disjoint boxes; fall back to depth order anyway
			for i in n:
				if done[i] == 0 and (pick < 0 or keys[i] < keys[pick]):
					pick = i
		done[pick] = 1
		out.append(items[pick])
		for s in after[pick]:
			pending[s] -= 1
			if pending[s] == 0 and done[s] == 0:
				ready.append(s)
	return out
