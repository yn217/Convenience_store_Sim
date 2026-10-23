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
static func sorted(items: Array) -> Array:
	var n := items.size()
	var behind: Array = []   # behind[i] = indices that must be drawn before i
	var pending := PackedInt32Array()
	for i in n:
		var list: Array[int] = []
		for j in n:
			if j != i and is_behind(items[j]["rect"], items[i]["rect"]):
				list.append(j)
		behind.append(list)
		pending.append(list.size())
	var done := PackedByteArray()
	done.resize(n)
	var out: Array = []
	while out.size() < n:
		var pick := -1
		var best := 0.0
		for i in n:
			if done[i] == 1 or pending[i] != 0:
				continue
			var r: Rect2 = items[i]["rect"]
			var key := r.get_center().x + r.get_center().y
			if pick < 0 or key < best:
				pick = i
				best = key
		if pick < 0:   # a cycle cannot happen for disjoint boxes; fall back to depth order anyway
			for i in n:
				if done[i] == 0:
					var r2: Rect2 = items[i]["rect"]
					var k2 := r2.get_center().x + r2.get_center().y
					if pick < 0 or k2 < best:
						pick = i
						best = k2
		done[pick] = 1
		out.append(items[pick])
		for i in n:
			if done[i] == 0 and behind[i].has(pick):
				pending[i] -= 1
	return out
