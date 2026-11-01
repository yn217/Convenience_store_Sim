# Character visual pilot review — 2026-11-01

Issue: [#230](https://github.com/yn217/Convenience_store_Sim/issues/230)

## Scope

This review covers the 41-image pilot. The remaining 293 candidates stay review-only and are not loaded by the pilot registry.

## Automated checks

- Registry entries: 41
- Runtime pilot PNGs: 41
- Duplicate logical IDs: 0
- Missing runtime paths: 0
- Title candidate: 1344x768
- Full-body/event candidates: 1024x1536
- Bust-up candidates: 1024x1024
- `runtime_approved`: `false`

## Candidate mapping

| ID | Role | Screen / trigger | Initial review state |
|---|---|---|---|
| `title_background_pilot` | title background | SCR-05 / title open | review pending; compare crop and UI safe area |
| `fullbody_dynamic_201` | full body | SCR-06 / tutorial greeting | review pending; check full silhouette and hands |
| `fullbody_tutorial_layout` | full body | SCR-06 / layout guidance | review pending; check white-background extraction |
| `fullbody_emotion_05` | full body | SCR-18 / first milestone | review pending; check expression and feet |
| `reaction_discovery` | bust-up | SCR-06 / discovery | review pending; generated `!` bubble is not authoritative UI text |
| `reaction_deadpan` | bust-up | SCR-11 / quiet street | review pending; generated `...` remains a visual reference |
| `reaction_pleading` | bust-up | SCR-18 / assistant request | review pending; check hands and symbol separation |
| `functional_opening_checklist` | functional pose | SCR-09 / opening checklist | review pending; do not infer checklist text from pixels |
| `functional_sold_out` | functional pose | SCR-11 / sold out | review pending; check full-body framing and hands |
| `functional_rival_store` | functional pose | SCR-11 / rival-store event | review pending; event must be backed by real state |
| `event_neighbor_mentions` | event image | SCR-11 / `evt_neighbor_mentions` | review pending; use only when the event is actually active |
| `event_local_fair` | event image | SCR-11 / `evt_local_fair` | review pending; use only when the event is actually active |
| `event_roadworks` | event image | SCR-11 / `evt_roadworks` | review pending; use only when the event is actually active |
| `event_hot_day` | event image | SCR-11 / `evt_hot_day` | review pending; use only when the event is actually active |
| `event_cold_day` | event image | SCR-11 / `evt_cold_day` | review pending; use only when the event is actually active |
| `event_sweets_spotlight` | event image | SCR-11 / `evt_sweets_spotlight` | review pending; use only when the event is actually active |
| `event_snack_buzz` | event image | SCR-11 / `evt_snack_buzz` | review pending; use only when the event is actually active |
| `event_lunch_pick` | event image | SCR-11 / `evt_lunch_pick` | review pending; inspect the onigiri and hand separation |
| `event_drink_pick` | event image | SCR-11 / `evt_drink_pick` | review pending; inspect bottle label and hand separation |
| `event_bread_feature` | event image | SCR-11 / `evt_bread_feature` | review pending; inspect the packaged bread and hands |
| `event_after_work` | event image | SCR-11 / `evt_after_work` | review pending; use only when the event is actually active |
| `functional_low_stock` | functional pose | SCR-11 / `low_stock_notice` | review pending; warning cue uses a temporary pose |
| `functional_expiry` | functional pose | SCR-11 / `expiry_notice` | review pending; warning cue uses a temporary pose |
| `functional_queue` | functional pose | SCR-11 / `long_queue` | review pending; warning cue uses a temporary pose |
| `functional_access_blocked` | functional pose | SCR-11 / `access_blocked` | review pending; warning cue uses a temporary pose |
| `functional_empty_handed` | functional pose | SCR-11 / `empty_handed` | review pending; customer departure reaction |
| `functional_staff_short` | functional pose | SCR-06 / `story_staff_short` | review pending; staff shortage story reaction |
| `functional_save_complete` | functional pose | SCR-20 / `save_complete` | review pending; save confirmation pose |
| `functional_staff_hiring` | functional pose | SCR-06 / `staff_hired` | review pending; hiring confirmation pose |
| `functional_three_sales` | functional pose | SCR-18 / `challenge_sales_3` | review pending; daily challenge presentation |
| `functional_ten_sales` | functional pose | SCR-18 / `ms_ten_sales` | review pending; milestone presentation |
| `functional_fifty_visitors` | functional pose | SCR-18 / `ms_fifty_visitors` | review pending; milestone presentation |
| `functional_six_categories` | functional pose | SCR-18 / `ms_six_categories` | review pending; milestone presentation |
| `functional_stock_challenge` | functional pose | SCR-18 / `challenge_stock_2` | review pending; daily challenge presentation |
| `functional_no_waste` | functional pose | SCR-18 / `challenge_no_waste` | review pending; daily challenge presentation |

## Visual observations

- The title candidate has a readable ordinary daytime storefront composition and leaves the right side relatively open for title UI, but it already contains Koharu. It must not be combined with a second `title_rikka.png` layer.
- The sampled full-body candidate preserves both odango buns and the uniform, but the white background is still opaque. Alpha extraction must be a separate derived step and must preserve the white blouse, hands, and shoe edges.
- The sampled bust-up candidate communicates surprise, but its generated speech bubble and punctuation are not production UI. Godot should own the symbol/text overlay.
- No candidate is approved for production replacement until the user reviews the gallery at the target resolutions.

## Next gate

1. Open the review gallery scene and inspect all 39 candidates.
2. Select/reject each candidate in the registry without changing Domain state.
3. Create derived alpha PNGs only for approved full-body/bust-up images.
4. Compare the title candidate at 1920x1080, 1600x900, and 1280x720 before connecting it to the title screen.
5. Keep `runtime_approved:false` until the above checks, rights review, and Godot screenshot QA are complete.
