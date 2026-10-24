class_name LightingModel
extends RefCounted
## Time-of-day tint of the store view (14 §2): 06-17 normal, 17-20 evening, 20-05 night, with one-hour
## blends. A function of the game clock only and presentation only (the hour weights of demand are
## separate). Night never goes darker than readable: shelf products and UI text stay legible.

const DAY := Color(1.0, 0.975, 0.93)   # slightly warm even at noon (mockup: warm store light)
const EVENING := Color(1.0, 0.955, 0.9)   # indoor: the shop lights stay on, only a warm hint of dusk (#114: bright)
const NIGHT := Color(1.0, 0.955, 0.9)   # indoor at night: bright shop light with a warm glow seen from outside (#114)


## Outdoor light (issue #114): the street, pavement, trees, parked cars and exterior props. Morning is cool and
## bright, noon neutral, evening orange, night a dark blue at about 0.45 of noon luminance, so the lit shop reads
## against a dark street. Applied as a per-layer modulate (outdoor_modulate), never as a full-screen tint.
const OUT_MORNING := Color(0.92, 0.97, 1.0)
const OUT_NOON := Color(1.0, 1.0, 1.0)
const OUT_EVENING := Color(1.0, 0.70, 0.46)
const OUT_NIGHT := Color(0.39, 0.45, 0.66)
const BUCKET_PER_HOUR := 6      ## spill and lamp glows are rebuilt when the 10-minute bucket changes, not per frame


static func hour_of(time_sec: int) -> float:
	return float(posmod(time_sec, 86400)) / 3600.0


## Clock bucket used to decide when the presentation-only light layers must be redrawn (10-minute steps).
static func bucket(time_sec: int) -> int:
	return int(floor(hour_of(time_sec) * BUCKET_PER_HOUR))


## Indoor light: the shop lights, floor, walls, fixtures, customers and interior decor. Bright at every hour; only
## a slight warm (day, evening) or cool (night) hint, so products keep their colours (see tint()).
static func indoor(time_sec: int) -> Color:
	return tint(time_sec)


## Outdoor light for the exterior layers, blended over an hour at dawn and dusk like tint().
static func outdoor(time_sec: int) -> Color:
	var h := hour_of(time_sec)
	if h >= 9.0 and h < 16.0:
		return OUT_NOON
	if h >= 16.0 and h < 17.0:
		return OUT_NOON.lerp(OUT_EVENING, h - 16.0)
	if h >= 17.0 and h < 19.0:
		return OUT_EVENING
	if h >= 19.0 and h < 20.0:
		return OUT_EVENING.lerp(OUT_NIGHT, h - 19.0)
	if h >= 6.0 and h < 8.0:
		return OUT_MORNING
	if h >= 8.0 and h < 9.0:
		return OUT_MORNING.lerp(OUT_NOON, h - 8.0)
	if h >= 20.0 or h < 5.0:
		return OUT_NIGHT
	return OUT_NIGHT.lerp(OUT_MORNING, h - 5.0)   # 05-06: dawn


## The per-layer modulate for the outdoor layers. The CanvasModulate carries the indoor tint over the whole world,
## so the outdoor layers multiply by outdoor / indoor and end up at outdoor(time) exactly (within float rounding).
static func outdoor_modulate(time_sec: int) -> Color:
	var o := outdoor(time_sec)
	var i := indoor(time_sec)
	return Color(o.r / i.r, o.g / i.g, o.b / i.b, 1.0)


## 0 in full daylight, 1 at night: how much the storefront spill, street lamps and vending glow show.
static func dusk_amount(time_sec: int) -> float:
	var day := luma(OUT_NOON)
	var night := luma(OUT_NIGHT)
	return clampf((day - luma(outdoor(time_sec))) / maxf(day - night, 0.001), 0.0, 1.0)


static func luma(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


static func tint(time_sec: int) -> Color:
	var h := hour_of(time_sec)
	if h >= 6.0 and h < 16.0:
		return DAY
	if h >= 16.0 and h < 17.0:
		return DAY.lerp(EVENING, h - 16.0)
	if h >= 17.0 and h < 19.0:
		return EVENING
	if h >= 19.0 and h < 20.0:
		return EVENING.lerp(NIGHT, h - 19.0)
	if h >= 20.0 or h < 5.0:
		return NIGHT
	return NIGHT.lerp(DAY, (h - 5.0))   # 05-06: dawn


static func phase_name(time_sec: int) -> String:
	var h := hour_of(time_sec)
	if h >= 6.0 and h < 17.0:
		return "day"
	if h >= 17.0 and h < 20.0:
		return "evening"
	return "night"
