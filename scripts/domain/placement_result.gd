class_name PlacementResult
extends RefCounted
## Read-only answer of PlacementRules.validate (UI preview and command commit share it).

var ok: bool = false
var code: StringName = &"INVALID_OPERATION"
var message_key: StringName = &""
var cells: Array[Vector2i] = []
## Walkable cells in front of the access edges after the placement (empty = unreachable).
var access_cells: Array[Vector2i] = []
var cost_yen: int = 0
