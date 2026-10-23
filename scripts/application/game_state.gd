class_name GameState
extends RefCounted
## Mutable runtime state. Only GameCommands / SimulationRunner write to it;
## presenters receive snapshot() copies (01 §2, §6).

const SCHEMA_VERSION := 1
const SETUP := &"SETUP"
const OPEN := &"OPEN"
const CLOSING := &"CLOSING"
const PAYMENT_BLOCKED := &"PAYMENT_BLOCKED"
const SPEED_OPTIONS: Array[int] = [0, 1, 2, 4]

var revision: int = 0
var time_sec: int = 0
var day: int = 0
var business_state: StringName = SETUP
var speed_setting: int = 0
var last_nonzero_speed: int = 1
var applied_command_ids: Array[String] = []
var rng_states: Dictionary = {}
var store_width: int = 16
var store_height: int = 12
## Fixed west-wall door (00_BASELINE §2.1); players cannot move or remove it.
var entrance_tiles: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 6)]
var cash_yen: int = 0
var reputation: int = 0


static func from_balance(balance: Dictionary, seeds: Dictionary) -> GameState:
	var s := GameState.new()
	s.store_width = int(balance["store_width_tiles"])
	s.store_height = int(balance["store_height_tiles"])
	s.cash_yen = int(balance["starting_cash_yen"])
	s.reputation = int(balance["starting_reputation"])
	s.rng_states = seeds.duplicate()
	return s


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"time_sec": time_sec,
		"day": day,
		"business_state": String(business_state),
		"speed_setting": speed_setting,
		"store_width": store_width,
		"store_height": store_height,
		"entrance_tiles": entrance_tiles.duplicate(),
		"cash_yen": cash_yen,
		"reputation": reputation,
		"rng_states": rng_states.duplicate(),
	}
