class_name GameClock
extends RefCounted
## Fixed-step accumulator (09 §1). Real delta only fills the accumulator;
## the number of simulation steps never depends on render FPS.

const STEP_GAME_SECONDS := 2.0
const GAME_SECONDS_PER_REAL_SECOND := 60.0

var accumulator: float = 0.0


## Returns the number of fixed steps to run now. Steps beyond `max_steps` stay in
## the accumulator (never skipped), so a slow frame is paid back later.
func advance(delta: float, speed: int, max_steps: int = 240) -> int:
	if speed <= 0:
		return 0
	accumulator += delta * speed * GAME_SECONDS_PER_REAL_SECOND
	var steps := 0
	while accumulator >= STEP_GAME_SECONDS and steps < max_steps:
		accumulator -= STEP_GAME_SECONDS
		steps += 1
	return steps
