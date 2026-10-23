extends RefCounted
## Issue #26: depth order of fixture segments and customers.


func _cells(x: int, y: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in w:
		for dy in h:
			out.append(Vector2i(x + dx, y + dy))
	return out


func _order(items: Array) -> Array:
	var ids := []
	for it in DrawOrder.sorted(items):
		ids.append(it["id"])
	return ids


func test_segments_split_a_long_fixture_into_screen_columns(t, _tree) -> void:
	var seg := DrawOrder.column_segments(_cells(4, 5, 1, 2))
	t.eq(seg.size(), 2, "1x2 -> two columns")
	t.eq(seg[0]["column"], -2, "(4,6): x-y = -2 is the left column")
	t.eq(seg[1]["column"], -1)
	var big := DrawOrder.column_segments(_cells(2, 2, 2, 2))
	t.eq(big.size(), 3, "2x2 -> columns -1, 0, 1")
	t.eq(big[1]["cells"].size(), 2, "the middle column holds the diagonal pair")
	t.eq(DrawOrder.column_segments(_cells(1, 1, 1, 1)).size(), 1)


func test_customer_in_front_is_drawn_after_the_shelf(t, _tree) -> void:
	var shelf := {"id": "shelf", "rect": DrawOrder.cell_rect(Vector2i(4, 5)).merge(DrawOrder.cell_rect(Vector2i(4, 6)))}
	var front := {"id": "front", "rect": DrawOrder.cell_rect(Vector2i(5, 5))}
	var back := {"id": "back", "rect": DrawOrder.cell_rect(Vector2i(3, 5))}
	t.eq(_order([front, shelf, back]), ["back", "shelf", "front"])
	t.eq(_order([back, front, shelf]), ["back", "shelf", "front"], "input order does not matter")


func test_customer_past_the_far_end_is_not_hidden_by_the_whole_shelf(t, _tree) -> void:
	# 1x2 shelf at (4,5)-(4,6); a customer at (5,4) is beside its y-start end: in front of the x side
	# but behind in y. Neither hides the other, so it must not be forced after the near segment.
	var segs := DrawOrder.column_segments(_cells(4, 5, 1, 2))
	var items: Array = []
	for i in segs.size():
		items.append({"id": "seg%d" % i, "rect": segs[i]["rect"]})
	var walker := {"id": "walker", "rect": DrawOrder.cell_rect(Vector2i(4, 7))}   # past the +y end: in front of both segments
	items.append(walker)
	var o := _order(items)
	t.eq(o[o.size() - 1], "walker")
	var behind_walker := {"id": "behind", "rect": DrawOrder.cell_rect(Vector2i(4, 4))}   # before the -y end
	items.append(behind_walker)
	o = _order(items)
	t.eq(o[0], "behind")
	# A customer next to the +x side of only the second cell is in front of seg1 but not of seg0's cell.
	var side := {"id": "side", "rect": DrawOrder.cell_rect(Vector2i(5, 6))}
	var pair := [items[0], items[1], side]
	var ids := _order(pair)
	t.ok(ids.find("side") > ids.find("seg1"), "in front of the segment it stands next to")


func test_is_behind_basics(t, _tree) -> void:
	var a := DrawOrder.cell_rect(Vector2i(0, 0))
	t.ok(DrawOrder.is_behind(a, DrawOrder.cell_rect(Vector2i(1, 0))))
	t.ok(not DrawOrder.is_behind(DrawOrder.cell_rect(Vector2i(1, 0)), a))
	t.ok(not DrawOrder.is_behind(DrawOrder.cell_rect(Vector2i(1, -1)), a), "diagonal neighbours have no order")
	t.ok(not DrawOrder.is_behind(a, DrawOrder.cell_rect(Vector2i(1, -1))))


func test_sort_is_deterministic_and_complete(t, _tree) -> void:
	var items: Array = []
	for i in 12:
		items.append({"id": i, "rect": DrawOrder.cell_rect(Vector2i((i * 5) % 7, (i * 3) % 5))})
	var a := _order(items)
	var b := _order(items)
	t.eq(a, b)
	t.eq(a.size(), 12)
	for i in range(a.size()):
		for j in range(i + 1, a.size()):
			t.ok(not DrawOrder.is_behind(items[a[j]]["rect"], items[a[i]]["rect"]) or items[a[j]]["rect"] == items[a[i]]["rect"], "%d before %d" % [a[i], a[j]])
