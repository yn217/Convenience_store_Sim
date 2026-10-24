extends RefCounted
## The customer pace before #117 v2 (0.6 tiles per game second, checkout 20 + 8 s, no browsing, 600 s hold,
## 120 s patience). Tests of the state machine's logic pin it, so their step counts and golden values do not
## depend on the tuning of the slow pace; the slow pace has its own tests (test_customer_pace.gd).

const VALUES := {
	"customer_walk_tiles_per_game_second": 0.6,
	"checkout_base_game_seconds": 20,
	"checkout_per_item_game_seconds": 8,
	"browse_min_game_seconds": 0,
	"browse_max_game_seconds": 0,
	"reservation_hold_game_seconds": 600,
	"queue_patience_game_seconds": 120,
}


static func apply(balance: Dictionary) -> Dictionary:
	balance.merge(VALUES, true)
	return balance
