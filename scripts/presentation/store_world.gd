extends Node2D
## Read-only presenter of the store (01 §2). Floor/fixture drawing arrives with #4 onward.

var store_width: int = 0
var store_height: int = 0
var revision: int = -1


func apply_snapshot(snapshot: Dictionary) -> void:
	store_width = int(snapshot["store_width"])
	store_height = int(snapshot["store_height"])
	revision = int(snapshot["revision"])
