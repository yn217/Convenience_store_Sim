class_name WindowCloseGuard
extends Node
## The window's close button during a game: it asks like the bottom-right action instead of dropping unsaved
## progress (#236). The title screen keeps closing at once, so the tree is put back when the game scene leaves.


func _ready() -> void:
	get_tree().auto_accept_quit = false


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	var returner := get_parent().get_node_or_null("TitleReturnController")
	if returner != null and returner.has_method("ask_quit_game"):
		returner.ask_quit_game()
	elif returner != null:
		returner.ask_return_to_title()
	else:
		get_tree().quit()
