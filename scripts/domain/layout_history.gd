class_name LayoutHistory
extends RefCounted
## Undo/Redo of one placement-edit session (04 §8). Entries (Dictionary):
##   kind: "PLACE" | "MOVE" | "REMOVE", instance_id, type_id,
##   from / to: {x, y, rotation} or null, cost_yen, purchase_event_id,
##   segments: [{segment_id, location}] (REMOVE only: where stock was before it went to the backroom)
## Any non-layout command, simulation tick, or load clears the whole history.

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []


func push(entry: Dictionary) -> void:
	undo_stack.append(entry)
	redo_stack.clear()


func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()
