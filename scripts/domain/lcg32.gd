class_name Lcg32
extends RefCounted
## Domain PRNG (09_DETERMINISTIC_SIMULATION_AND_SAVE §1). Never use the global Godot RNG in Domain.

const MODULUS := 4294967296

var state: int = 0


func _init(seed_value: int = 0) -> void:
	state = seed_value % MODULUS


func next_state() -> int:
	state = (1664525 * state + 1013904223) % MODULUS
	return state


func uniform_0_1() -> float:
	return float(next_state()) / 4294967296.0
