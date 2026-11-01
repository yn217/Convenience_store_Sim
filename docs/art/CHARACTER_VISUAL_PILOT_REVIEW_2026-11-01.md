# Character visual pilot review — 2026-11-01

Issue: [#230](https://github.com/yn217/Convenience_store_Sim/issues/230)

## Scope

This review covers the 48-image pilot. The remaining 286 candidates stay review-only and are not loaded by the pilot registry.

## Automated checks

- Registry entries: 48
- Runtime pilot PNGs: 48
- Duplicate logical IDs: 0
- Missing runtime paths: 0
- Title candidate: 1344x768
- Full-body/event candidates: 1024x1536
- Bust-up candidates: 1024x1024
- Derived alpha integrity: 47 files keep their expected canvas (44 full-body at 1024x1536 and 3 bust-up reactions at 1024x1024), non-empty alpha, and transparent corners (`tests/tools/test_character_pilot_assets.py`)
- Runtime event-panel spot check: `evt_quiet_street` at 1280x720 displays the transparent `reaction_deadpan` pilot in the dedicated event slot without the source white rectangle.
- Event panel layout: the event illustration and a dedicated pilot column are arranged horizontally. Full-body pilots use `EventPilotFullbodyPicture` (160x240) and bust-up reactions use `EventPilotReactionPicture` (220x220); only the matching slot is visible, preventing the pilot from being clipped below the event card at 1280x720.
- Runtime event-panel spot checks: `build/character_pilot_event_roadworks_management_1280.png` shows the full-body `event_roadworks` pilot beside the event CG, and `build/character_pilot_event_quiet_management_1280.png` shows the `reaction_deadpan` bust-up in the same dedicated column.
- Runtime map spot check: the `map_proposal_open` full-body pilot is visible in the area-map side panel at 1280x720 without covering the map controls.
- Runtime day-end spot check: the normal and worried report routes select their separate full-body pilots; the focused scene test covers both switches.
- Runtime warning spot check: `low_stock_notice` keeps `functional_low_stock` visible above an open management window; the focused scene test covers the warning route.
- Runtime story-reaction spot check: `story_start` shows `reaction_discovery` and `story_queue_giveup` shows `reaction_pleading` in a dedicated 260x260 layer. The full-body pilot layer is hidden while either bust-up is active, so the two representations do not stack. `story_staff_short` intentionally keeps its dedicated `functional_staff_short` full-body pose.
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
| `functional_campaign` | functional pose | SCR-13 / `seasonal_campaign_started` | review pending; campaign product-presentation pose |
| `functional_map_proposal` | functional pose | SCR-13 / `map_proposal_open` | review pending; map proposal pose shown in the area-map side panel |
| `functional_register_guidance` | functional pose | SCR-06 / `story_register` | review pending; register placement tutorial pose |
| `functional_restock_guidance` | functional pose | SCR-06 / `story_first_restock` | review pending; restocking tutorial pose |
| `functional_day_report` | functional pose | SCR-18 / `day_end_normal` | review pending; normal daily-report pose |
| `functional_business_greeting` | functional pose | SCR-09 / `business_started` | review pending; opening greeting pose; replaces the mismatched rival-store candidate |
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
- Functional pose QC: No.001 was selected for the opening greeting after checking its full-body framing. No.008 remains review-only because the raised hands use strong foreshortening and unstable finger anatomy; No.009 remains review-only because the camera is too close and the body is dominated by the upper torso. Neither candidate is connected to runtime.

## Runtime cue overlay

The staff-management screen requests `staff_schedule_open`, the order and restock actions request `order_help` and `restock_help`, and successful save, hiring, and promotion commands request their corresponding functional cues. These cues temporarily keep the selected pilot figure visible above the management window; ordinary story lines continue to step aside while a management screen is open.

Story reactions use a separate layer from full-body poses. For visual QA, `tools/capture_screen.gd` accepts `--story-cue=story_start` or `--story-cue=story_queue_giveup`; `--inspect-pilot` reports both the full-body and bust-up texture paths. The reaction layer is presentation-only and does not alter story or economy state.

Reaction symbols are rendered by Godot from the registry's `overlay_symbol` field (`!`, `?`, `...`) in their own label layer; punctuation baked into a generated PNG is not treated as authoritative UI. The 1280x720 story capture `build/character_pilot_story_symbol_1280_fixed.png` confirms the discovery portrait and independent `!` overlay remain readable without a second assistant.

The `business_started` opening cut-in is exclusive: while `開店！` is animating, the ordinary assistant stage and the mockup's baked assistant figure/bubble are suppressed. This prevents the cut-in's generated greeting from appearing alongside a second assistant.

The pilot review UI exists only in a Godot debug build and defaults on there for local review. Release builds do not create the review controls, so entries with `runtime_approved:false` cannot appear in the normal runtime.

## 334-candidate placement review

The complete read-only placement gallery is `scenes/review/ComfyUIPlacementReview.tscn`. Launch it directly with:

```text
Godot_v4.7.2-stable_win64.exe --path . --scene res://scenes/review/ComfyUIPlacementReview.tscn
```

It reads `docs/art/COMFYUI_334_IMAGE_PLACEMENT_20261101.json`, lists all 334 candidate IDs, and loads only the selected source PNG. Search and group filtering do not modify the registry, CSV/JSON approval state, or runtime assets. A focused loader test verifies 334 unique entries, explicit approval states, and `visual_match=not_yet_verified`; all 334 source PNG paths are present in the review asset tree.

## Title candidate QA

The `title_background_pilot` candidate is now the daylight residential-store composition `title_screen_variant_04_1344x768_00001_.png`. The explicit `--visual-variant=painted_v1` QA path keeps the title logo, buttons, and embedded character separate from a second `TitleRikka` layer. It remains held for visual and rights review; the default title continues to use `assets/ui/title/title_background.png` with the existing fallback path.

The same title candidate was captured at 1280x720, 1600x900, and 1920x1080 as `build/character_pilot_title_{1280,1600,1920}.png`. Across all three sizes, the embedded character's face and both odango buns remain inside the frame, the logo and menu buttons remain readable, and the standalone `TitleRikka` layer is not created. The hand/lower-body crop is part of the candidate's bust-up composition and does not obscure a control. This is a visual comparison result only; the candidate remains a local QA override and is not yet the default title asset.

The focused `test_character_art.gd` run also passed: 14 tests, 329 assertions, 0 failures, including the title pilot no-double-figure check.

## Runtime screen QA (2026-11-02)

The 1280x720 management-screen capture `build/character_pilot_roadworks_management_latest.png` was checked with `evt_roadworks`, the `経営` screen, and `--inspect-pilot`. The event illustration and the selected `event_roadworks` full-body pilot are both rendered by the event panel. The pilot remains inside the panel, does not cover the management tabs or bottom controls, and no second assistant layer is visible. The event status text and event image remain owned by the existing event UI; the generated character is presentation-only.

Focused verification after this capture:

- `test_character_visual_pilot.gd`: 4 tests, 273 assertions, 0 failures.
- `test_event_ui.gd`: 4 tests, 47 assertions, 0 failures.

The capture is a layout/visibility check only. It does not approve the candidate for release; `runtime_approved:false` and the rights-review gate remain unchanged.

The functional cue capture `build/character_pilot_low_stock_clean_latest.png` also exercises `low_stock_notice`. The capture helper now reapplies the requested cue after settling `CuePlayer` effects, so the short cue timer cannot expire before the frame is saved. The startup achievement popup is cleared, and the full-body pilot remains in the assistant slot without covering the store controls.

The follow-up parse check covered 263 GDScript files with 0 errors, and the focused pilot route test remained at 4 tests / 273 assertions / 0 failures.

The story reaction capture `build/character_pilot_story_queue_clean_latest.png` exercises `story_queue_giveup`. The queue-departure explanation remains in the existing assistant bubble, the bust-up reaction is shown in its dedicated layer, the independent `?` symbol is visible, and the full-body pilot is hidden. The capture helper reapplies the requested story cue after the final animation settle so the saved image matches the requested route.

## Derived-alpha contact-sheet review (2026-11-02)

The 47 PNGs under `assets/runtime/character_pilot/derived_alpha` were reviewed together on a dark matte in `build/character_pilot_alpha_contact.png`. At contact-sheet scale, the full-body set keeps the white blouse, apron silhouette, trousers, and shoes, with no gross white-background island or large surrounding residue visible. This is a coarse alpha/silhouette gate, not per-image hand or edge approval.

The three bust-up reactions remain held because generated bubbles/symbols are still present in the source-derived pixels. Godot's independent symbol layer remains authoritative, so these candidates are not promoted or added to the runtime registry until a clean derivation and detailed hand/edge review are available.

### Individual functional-pose spot checks

| Candidate | Coarse alpha / costume result | Remaining review item | State |
|---|---|---|---|
| `functional_low_stock` | White blouse, apron, both odango buns, trousers, and boots retained | Clipboard-to-forearm contact and hand anatomy | placement candidate; hand review pending |
| `functional_sold_out` | White sleeves and both arms remain visible; silhouette is clean | Finger count/shape on both open hands | placement candidate; hand review pending |
| `functional_queue` | White blouse, clipboard, shoes, and outer silhouette retained | Fingers around the clipboard and wrist connection | placement candidate; hand review pending |

These spot checks do not change `runtime_approved`; the assets remain available through the pilot route only.

The staff-management capture `build/character_pilot_staff_hired_latest.png` opens the internal `店員` tab and exercises `staff_hired`. The staff list, candidate cards, and hiring controls remain visible while the full-body pilot is shown in the assistant slot; no button/card is covered and no second character is introduced. (`スタッフ` is the chrome label; `店員` is the internal tab ID used by the capture helper.)

## Assistant placement QA (2026-11-02)

The assistant stage now reserves the area to the right of the mockup's left menu (`MainLayout.CHROME_MENU_RIGHT` plus a margin), clips its stage to the viewport, and applies the same safe-area placement to full-body pilots, bust-up reactions, and reaction symbols. The speech bubble is anchored beside the figure and lowered by `BUBBLE_TOP_DROP`, so it no longer sits on top of the left menu. Screen-scoped pilot cues are cleared when their management screen closes.

Visual captures:

- `build/character_pilot_layout_fixed_1280.png`
- `build/character_pilot_layout_fixed_1920.png`

Both resolutions show the `low_stock_notice` pilot without left-menu overlap; the bubble is lower and the summary strip remains the figure's baseline. Focused verification: `parse_all` covered 263 scripts with 0 errors, `character_visual_pilot` passed 4 tests / 273 assertions / 0 failures, and `onboarding` passed 6 tests / 69 assertions / 0 failures.

## Next gate

1. Open the review gallery scene and inspect all 47 derived-alpha candidates.
2. Select/reject each candidate in the registry without changing Domain state.
3. Create derived alpha PNGs only for approved full-body/bust-up images.
4. Compare the title candidate at 1920x1080, 1600x900, and 1280x720 before connecting it to the title screen.
5. Keep `runtime_approved:false` until the above checks, rights review, and Godot screenshot QA are complete.
