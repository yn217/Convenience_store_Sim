class_name UiShape
extends Control
## One shape of the 2026-11-01 mockup look, drawn in code (no picture): a rounded panel, a menu plate with pointed
## ends, a ribbon with a round right end, a speech bubble or a circle, filled with a top-to-bottom gradient, with an
## outer border, an optional inner rim line, a soft drop shadow, an outer glow and a gloss on its upper part.
## Presentation only; it never takes the mouse (the Button or Control it sits in does).

enum Kind { ROUND, PLATE, RIBBON, CIRCLE, CLOUD }

var kind := Kind.ROUND
var top := Color.WHITE
var bottom := Color.WHITE
var border := Color(0, 0, 0, 0)
var border_width := 0.0
var inner := Color(0, 0, 0, 0)        # a thin rim line inside the border
var inner_inset := 4.0
var radius := 10.0
var tip := 14.0                       # PLATE: how far the pointed ends stick out; RIBBON with arrow: the point's length
var arrow := false                    # RIBBON: a pointed right end instead of a round one
var bumps := 7                        # CLOUD: bumps along the top and bottom edges
var shadow := Color(0, 0, 0, 0)
var shadow_offset := Vector2(0, 3)
var glow := Color(0, 0, 0, 0)
var glow_size := 0.0
var gloss := 0.0                      # alpha of the white sheen on the upper part


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


## Sets several properties at once and redraws: setup({"top": .., "bottom": ..}).
func setup(props: Dictionary) -> UiShape:
	for k in props:
		set(k, props[k])
	queue_redraw()
	return self


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if glow.a > 0.0 and glow_size > 0.0:
		var steps := 6
		for i in steps:
			var g := glow_size * float(steps - i) / float(steps)
			draw_colored_polygon(outline(r.grow(g)), Color(glow, glow.a / float(steps)))
	if shadow.a > 0.0:
		var sh := outline(r)
		for i in sh.size():
			sh[i] += shadow_offset
		draw_colored_polygon(sh, shadow)
	var fill_rect := r
	if border_width > 0.0 and border.a > 0.0:
		draw_colored_polygon(outline(r), border)
		fill_rect = r.grow(-border_width)
	var pts := outline(fill_rect)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - fill_rect.position.y) / maxf(fill_rect.size.y, 1.0), 0.0, 1.0)))
	draw_polygon(pts, cols)
	if gloss > 0.0:
		var g_rect := Rect2(fill_rect.position + Vector2(3, 2), Vector2(fill_rect.size.x - 6, fill_rect.size.y * 0.48))
		var gp := outline(g_rect)
		var gc := PackedColorArray()
		for p in gp:
			gc.append(Color(1, 1, 1, gloss * (1.0 - clampf((p.y - g_rect.position.y) / maxf(g_rect.size.y, 1.0), 0.0, 1.0))))
		draw_polygon(gp, gc)
	if inner.a > 0.0:
		var ip := outline(fill_rect.grow(-inner_inset))
		ip.append(ip[0])
		draw_polyline(ip, inner, 1.5, true)


## The shape's outline in `r`, clockwise, convex.
func outline(r: Rect2) -> PackedVector2Array:
	match kind:
		Kind.CIRCLE:
			return _ellipse(r)
		Kind.PLATE:
			return _plate(r)
		Kind.RIBBON:
			return _ribbon(r)
		Kind.CLOUD:
			return _cloud(r)
	return _round_rect(r, minf(radius, minf(r.size.x, r.size.y) * 0.5))


static func _arc(out: PackedVector2Array, c: Vector2, rad: float, from_deg: float, to_deg: float) -> void:
	var n := maxi(3, int(rad / 2.0))
	for i in n + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(n)))
		out.append(c + Vector2(cos(a), sin(a)) * rad)


static func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	_arc(out, Vector2(x0 + rad, y0 + rad), rad, 180, 270)
	_arc(out, Vector2(x1 - rad, y0 + rad), rad, 270, 360)
	_arc(out, Vector2(x1 - rad, y1 - rad), rad, 0, 90)
	_arc(out, Vector2(x0 + rad, y1 - rad), rad, 90, 180)
	return out


static func _ellipse(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := r.get_center()
	for i in 48:
		var a := TAU * float(i) / 48.0
		out.append(c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
	return out


## A plate with both short ends pointed (the mockup's menu buttons), the corners slightly rounded.
func _plate(r: Rect2) -> PackedVector2Array:
	var t := minf(tip, r.size.y * 0.5)
	var rad := minf(radius, r.size.y * 0.25)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var ym := r.get_center().y
	var out := PackedVector2Array()
	var tr := t * 0.55   # the points are rounded too
	_arc(out, Vector2(x0 + tr * 1.25, ym), tr, 150, 210)
	_arc(out, Vector2(x0 + t + rad, y0 + rad), rad, 225, 270)
	_arc(out, Vector2(x1 - t - rad, y0 + rad), rad, 270, 315)
	_arc(out, Vector2(x1 - tr * 1.25, ym), tr, -30, 30)
	_arc(out, Vector2(x1 - t - rad, y1 - rad), rad, 45, 90)
	_arc(out, Vector2(x0 + t + rad, y1 - rad), rad, 90, 135)
	return out


## Left corners rounded by `radius`, the right end a half circle.
func _ribbon(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rad := minf(radius, r.size.y * 0.5)
	var h := r.size.y * 0.5
	_arc(out, Vector2(r.position.x + rad, r.position.y + rad), rad, 180, 270)
	if arrow:
		var t := minf(tip, h)
		_arc(out, Vector2(r.end.x - t - 3, r.position.y + 3), 3, 270, 300)
		_arc(out, Vector2(r.end.x - 3, r.position.y + h), 3, -40, 40)
		_arc(out, Vector2(r.end.x - t - 3, r.end.y - 3), 3, 60, 90)
	else:
		_arc(out, Vector2(r.end.x - h, r.position.y + h), h, 270, 450)
	_arc(out, Vector2(r.position.x + rad, r.end.y - rad), rad, 90, 180)
	return out


## A speech cloud: a rounded box whose top and bottom edges bulge in `bumps` soft arcs and whose sides bulge once.
func _cloud(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := r.get_center()
	var a := r.size.x * 0.5
	var b := r.size.y * 0.5
	var n := 160
	for i in n:
		var th := TAU * float(i) / float(n)
		var dx := cos(th)
		var dy := sin(th)
		# a superellipse (boxy) base, then gentle bumps
		var p := 4.0
		var base := 1.0 / pow(pow(absf(dx), p) + pow(absf(dy), p), 1.0 / p)
		var bump := 1.0 - 0.035 * (0.5 + 0.5 * cos(th * float(bumps * 2)))
		out.append(c + Vector2(dx * a, dy * b) * base * bump)
	return out
