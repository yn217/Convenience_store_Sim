class_name LightingModel
extends RefCounted
## Time-of-day tint of the store view (14 §2): 06-17 normal, 17-20 evening, 20-05 night, with one-hour
## blends. A function of the game clock only and presentation only (the hour weights of demand are
## separate). Night never goes darker than readable: shelf products and UI text stay legible.

const DAY := Color(1.0, 0.975, 0.93)   # slightly warm even at noon (mockup: warm store light)
const EVENING := Color(1.0, 0.93, 0.84)   # indoor: the shop lights stay on, only a warm hint of dusk
const NIGHT := Color(0.90, 0.92, 0.98)   # indoor at night: bright shop light, a cool hint only


static func hour_of(time_sec: int) -> float:
	return float(posmod(time_sec, 86400)) / 3600.0


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
