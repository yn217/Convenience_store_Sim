# Customer path verification (2026-10-24)

Branch `feature/m14-path-verify`, from `origin/main` 39f54b2 (calm customer motion, #117).

## Answer

Customers do not walk through aisles or shelves. In every run below, the logical walk (4-connected moves, access-side stops) and the drawn figures, live and departing, stayed on free tiles and never crossed a fixture footprint, at x1, x2 and x4, on the 7-fixture test store and on the 20-fixture sample store, with crowded and with normal demand, for 2 game hours each.

Two presentation gaps were found and fixed:

1. **Catch-up after a long stall could jump across shelves.** When the simulation makes more steps between two presenter frames than the customer trail keeps (TRAIL_MAX = 32 steps, about 38 tiles), the presenter placed the figure on the simulation tile, a straight jump across fixtures. Reproduced before the fix (see Findings 2). Fixed: the figure now walks free tiles to the simulation tile.
2. **The F3 debug overlay drew a misleading red line.** It was a straight screen-space line from the shown figure to the logical tile. It is not a route, and in the isometric view it crosses shelves. Replaced by the real route polyline plus a thin dashed "lag" line.

## Method

- **Test:** `tests/scenario/test_customer_paths.gd`. It runs the real `GameState` and `SimulationRunner`, then drives the real `FixturePresenter._sync_customers()` and `compose()` (the same calls `_process` and the StoreWorld make). The snapshot is `GameState._customer_views()`, with real frame deltas at x1, x2 and x4.
- **Current presenter path, not a fallback:** all movement goes through the trail branch of `_take_steps`. On the lab store, 450 arrivals gave 450 placements, so no figure was re-placed.
- **Layouts:** `lab` (the original 7-fixture store, forced arrivals, 1.5 game hours) and `sample` (`data/layouts/sample_store_v1.json`, 20 fixtures placed through `PLACE_FIXTURE`, stocked like the bench, 2 game hours).
- **Demand:** `crowd` = the bench's crowded demand (200000 visitors/day, max 30 active). `normal` = the balance file's own demand.
- **Stall variant:** `sample crowd`, plus a 2 s real stall every 400 frames (x4 gives 240 steps in one frame).
- **Checks:**
  - (a) no standing or walked tile inside a fixture footprint;
  - (b) every move is 4-connected;
  - (d) a shelf visit stops on an access tile;
  - (c) every drawn position and every point of the drawn segment stays outside the footprints (radius 0.2), for live and departing figures;
  - (e) draw order against fixtures;
  - (f) no teleport: a figure moves at most WALK_MAX tiles per real second.
- **Overflow:** sampled every 30 frames. A WAIT_QUEUE customer without a slot is checked for distance to the nearest register cell and for whether standing on its tile would cut off a walkable access tile.

## Results: violations per check, per speed, per layout

Violations are 0 in every cell. The "Moves" and "Picks" columns show how much was exercised.

| Layout, demand, game time | Speed | a | b | d | c | e | f | Moves | Picks | Max steps/frame | Max jump (tiles) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| lab, forced, 1.5 h | x1 | 0 | 0 | 0 | 0 | 0 | 0 | 4077 | 169 | 1 | 0.200 |
| lab, forced, 1.5 h | x2 | 0 | 0 | 0 | 0 | 0 | 0 | 4077 | 169 | 1 | 0.200 |
| lab, forced, 1.5 h | x4 | 0 | 0 | 0 | 0 | 0 | 0 | 4077 | 169 | 2 | 0.200 |
| sample, crowd, 2 h | x1 | 0 | 0 | 0 | 0 | 0 | 0 | 28954 | 1409 | 1 | 0.200 |
| sample, crowd, 2 h | x2 | 0 | 0 | 0 | 0 | 0 | 0 | 28954 | 1409 | 1 | 0.200 |
| sample, crowd, 2 h | x4 | 0 | 0 | 0 | 0 | 0 | 0 | 28954 | 1409 | 2 | 0.153 |
| sample, normal, 2 h | x1 | 0 | 0 | 0 | 0 | 0 | 0 | 74 | 3 | 1 | 0.200 |
| sample, normal, 2 h | x2 | 0 | 0 | 0 | 0 | 0 | 0 | 74 | 3 | 1 | 0.200 |
| sample, normal, 2 h | x4 | 0 | 0 | 0 | 0 | 0 | 0 | 74 | 3 | 2 | 0.200 |
| sample, crowd + 2 s stall, 2 h | x4 | 0 | 0 | 0 | 0 | 0 | 0 | 28954 | 1409 | 240 | 0.153 |

Teleports (f) were 0 in every run, including the stall run where a single frame held 240 steps. Teleports were also 0 before the fix (the same runs, with catch-up disabled), so the sample store never reached the trail limit. Teleports also stayed 0 with the original 0.5 s stall.

Overflow (WAIT_QUEUE without a slot, sampled):

| Layout, demand | Speed | Checks | Cut-off cases | Max distance from register (tiles) |
|---|---|---|---|---|
| lab, forced | x1 / x2 / x4 | 427 / 218 / 109 | 0 / 0 / 0 | 13 |
| sample, crowd | x1 / x2 / x4 | 4958 / 2482 / 1249 | 30 / 16 / 8 | 18 |
| sample, crowd + stall | x4 | 994 | 3 | 18 |
| sample, normal | all | 0 | 0 | 0 |

"Cut-off cases" means that if the waiting customer's tile were blocked, some access tile that is reachable now would become unreachable. Customers are not obstacles in the domain (`CustomerAI._blocked` uses fixture cells only), so these cases are not violations and nothing was changed in the domain.

## Findings

1. **Pass-through in logic and drawing: none found** (checks a to e, all runs).
2. **Catch-up after a long stall: real gap, now fixed.** The test `test_catch_up_after_a_long_stall_stays_on_free_tiles` puts a figure 40 steps behind with only a 32-step trail, behind a 6-shelf wall. Before the fix it failed with "teleport (0,5) -> (8,5)" and "crosses fixture cell (4,5)". The fix (`FixturePresenter._route_gap`) walks a shortest path over free tiles (box margin 12, at most 400 visited tiles) and is used only when the simulation's own trail is too short. Other tile changes (spawns, teleports) are still placed, as the scene test `test_customer_sprites.gd` requires. Setting `GAP_MAX := 0` in the presenter restores the old behaviour.
3. **Shortcut audit while lagging:**
   - Trail trimming (`TRACK_KEEP` and the `s -= 1` shift) keeps the drawn position unchanged. Checked every frame.
   - Trail cap: the only shortcut found, fixed as in Finding 2.
   - Turning tiles: a frame never passes one (`_clip_at_turn`). Checked by the segment test.
   - Catch-up speed: capped at WALK_MAX (12 tiles per real second). Largest per-frame move was 0.20 tile in normal frames and 0.15 tile in the 2 s stall runs at x4 (the final code); the pre-fix stall run at x1 reached 10 tiles in one 2 s frame, all along free tiles.
   - Departing figures (`Walk.departed`) walk only their own remaining history. The check now covers them too: the earlier test looked only at live customers.
4. **Debug overlay (`debug_path_layer.gd`):** the red line was a straight screen-space segment from the shown figure to the logical tile. It is not a route and crosses shelves wherever the trail turns a corner. It now shows:
   - a magenta polyline through tile centres, from the shown position along the trail still to be walked and the remaining path (`FixturePresenter.shown_route`, tested in `test_shown_route_is_walkable_tiles`);
   - a thin dashed "lag" line from the shown position to the logical tile. It is a distance indicator only, not a path.
5. **Overflow customers do not wait near the register.** They wait on a free tile near where they are when they run out of slots, which is often by a shelf. Max distance from the register was 18 tiles on the sample store. This is domain behaviour (`MAX_ROOM_RADIUS` = 3 from the current tile). It was not changed, since no test asks for a register-side wait.
6. **Normal demand is thin coverage:** the balance file gives 3 purchases in 2 game hours on the sample store, so the normal rows check only the first few customers.

## Debug capture

`docs/qa/screens/paths_verify_debug.png`: `--calm` (normal demand), `--zoom=1.3`, `--debug-paths`, 1920x1080 window. The capture is not crowded: 2 customers were in the store, so few route lines are visible. Cyan footprints and access tiles are visible. No script errors.

## Changes

- `scripts/presentation/fixture_presenter.gd`: catch-up route (`_route_gap`, `_blocked_cache`), used only when the trail is too short; `shown_route()` for the overlay.
- `scripts/presentation/debug_path_layer.gd`: route polyline and dashed lag line.
- `tests/scenario/test_customer_paths.gd`: sample variants (crowd, normal, stall at x4), overflow check, departing-figure and teleport checks, catch-up test, route test. The lab tests are unchanged.
- Not touched: `customer_ai.gd`, `demand_generator.gd`, `inventory_service.gd`, `game_state.gd` (the #128 basket work).

## Test status

- Full suite (`tests/run_all.gd`, headless): `tests=506 assertions=27247 failures=0`, 0 SCRIPT ERROR lines.
- Runtime of the path file: about 10 minutes (the sample crowd x1 run alone is about 2 minutes).
