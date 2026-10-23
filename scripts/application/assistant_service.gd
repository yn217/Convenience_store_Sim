class_name AssistantService
extends RefCounted
## Manager-assistant cues (15 §5). Fixed local texts only; which cue applies is decided from state
## (never from clicks). A cue stays eligible until the player dismisses it, and a dismissed cue is
## saved in progression_state.dismissed_story_cue_ids, so it never returns after a load.
## Order = the order of the story: the first eligible cue the player has not dismissed is shown.

const CUES: Array[String] = [
	"story_start", "story_register", "story_first_restock", "story_first_sale", "story_first_profit",
	"story_sold_out", "story_queue_giveup", "story_event",
]


## Cue ids whose condition holds right now (dismissed or not).
static func eligible(state: GameState) -> Array[String]:
	var out: Array[String] = []
	var p: Dictionary = state.progression_state
	var step := int(p["tutorial_step_index"])
	out.append("story_start")
	if step >= 2:
		out.append("story_register")
	if step >= 5:
		out.append("story_first_restock")
	if int(state.progression_totals["sales"]) >= 1:
		out.append("story_first_sale")
	if p["completed_milestone_ids"].has("ms_first_profit"):
		out.append("story_first_profit")
	if int(state.rate_stats["stockouts"]) > 0:
		out.append("story_sold_out")
	if int(state.rate_stats["abandoned"]) > 0:
		out.append("story_queue_giveup")
	return out


## The cue to show now, or "" when everything eligible has been dismissed.
static func current(state: GameState) -> String:
	var dismissed: Array = state.progression_state["dismissed_story_cue_ids"]
	for id in eligible(state):
		if not dismissed.has(id):
			return id
	return ""
