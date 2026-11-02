# Character visual pilot review — 2026-11-01

Issue: [#230](https://github.com/yn217/Convenience_store_Sim/issues/230)

## Scope

This review covers the 50-image pilot. The remaining 284 candidates stay review-only and are not loaded by the pilot registry.

## Automated checks

- Registry entries: 50
- Runtime pilot PNGs: 50
- Duplicate logical IDs: 0
- Missing runtime paths: 0
- Title candidate: 1344x768
- Full-body/event candidates: 1024x1536
- Bust-up candidates: 1024x1024
- Derived alpha integrity: 49 files keep their expected canvas (44 full-body at 1024x1536 and 5 bust-up reactions at 1024x1024), non-empty alpha, and transparent corners (`tests/tools/test_character_pilot_assets.py`)
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
| `functional_layout_guidance` | functional pose | SCR-06 / `layout_help` | review pending; construction-mode guidance candidate, check palette-safe display |
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
| `functional_restock_guidance` | functional pose | SCR-06 / `story_first_restock` | review pending; replaced with candidate `functional_005` (closed stock box / inventory arrival pose) |
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

The `title_background_pilot` candidate is now the bright spring/sakura residential-store composition `title_screen_bright_sakura_1664x936.png`. The project keeps the generated source at its original size and uses a separate 1344x768 runtime display copy. The explicit `--visual-variant=painted_v1` QA path keeps the title logo, buttons, and embedded character separate from a second `TitleRikka` layer. It remains held for visual and rights review; the default title continues to use `assets/ui/title/title_background.png` with the existing fallback path.

The same title candidate was captured at 1280x720, 1600x900, and 1920x1080 as `build/character_pilot_title_{1280,1600,1920}.png`. Across all three sizes, the embedded character's face and both odango buns remain inside the frame, the logo and menu buttons remain readable, and the standalone `TitleRikka` layer is not created. The hand/lower-body crop is part of the candidate's bust-up composition and does not obscure a control. This is a visual comparison result only; the candidate remains a local QA override and is not yet the default title asset.

The 1600x900 capture was re-run through the requested non-headless CLI path with `Godot_v4.7.2-stable_win64_console.exe --rendering-method gl_compatibility --path . --resolution 1600x900 --script res://tools/capture_screen.gd -- --title --visual-variant=painted_v1 build/title_bright_sakura_pilot_1600.png`. The saved frame keeps the embedded character, title plate, and real Godot buttons readable; no second standalone character is introduced. This is additional visual evidence only and does not change the approval gate.

The focused `test_character_art.gd` run also passed: 14 tests, 329 assertions, 0 failures, including the title pilot no-double-figure check.

## Runtime screen QA (2026-11-02)

The 1280x720 management-screen capture `build/character_pilot_roadworks_management_latest.png` was checked with `evt_roadworks`, the `経営` screen, and `--inspect-pilot`. The event illustration and the selected `event_roadworks` full-body pilot are both rendered by the event panel. The pilot remains inside the panel, does not cover the management tabs or bottom controls, and no second assistant layer is visible. The event status text and event image remain owned by the existing event UI; the generated character is presentation-only.

For the main store screen, generated full-body pilot PNGs are now displayed through `AssistantPilotBustupCrop`, a 300 px-high clipped Control. The child keeps the original 1024x1536 `Texture2D`; only the display frame clips the lower body. The source PNGs are not cropped or overwritten, and event-panel full-body slots retain their original full-body presentation.

Focused verification after this capture:

- `test_character_visual_pilot.gd`: 4 tests, 273 assertions, 0 failures.
- `test_event_ui.gd`: 4 tests, 47 assertions, 0 failures.

The capture is a layout/visibility check only. It does not approve the candidate for release; `runtime_approved:false` and the rights-review gate remain unchanged.

The functional cue capture `build/character_pilot_low_stock_clean_latest.png` also exercises `low_stock_notice`. The capture helper now reapplies the requested cue after settling `CuePlayer` effects, so the short cue timer cannot expire before the frame is saved. The startup achievement popup is cleared, and the full-body pilot remains in the assistant slot without covering the store controls.

The follow-up parse check covered 263 GDScript files with 0 errors, and the focused pilot route test remained at 4 tests / 273 assertions / 0 failures.

The story reaction capture `build/character_pilot_story_queue_clean_latest.png` exercises `story_queue_giveup`. The queue-departure explanation remains in the existing assistant bubble, the bust-up reaction is shown in its dedicated layer, the independent `?` symbol is visible, and the full-body pilot is hidden. The capture helper reapplies the requested story cue after the final animation settle so the saved image matches the requested route.

## Derived-alpha contact-sheet review (2026-11-02)

The 49 PNGs under `assets/runtime/character_pilot/derived_alpha` were reviewed together on a dark matte in `build/character_pilot_alpha_contact_20261103.png`. At contact-sheet scale, the full-body set keeps the white blouse, apron silhouette, trousers, and shoes, with no gross white-background island or large surrounding residue visible. This is a coarse alpha/silhouette gate, not per-image hand or edge approval. The two additional clean bust-up routes are included; the older reaction routes with baked symbols remain held.

The three original bust-up reactions remain held because generated bubbles/symbols are still present in their source-derived pixels. `reaction_milestone_calm` is a fourth pilot route derived from candidate 043, and `reaction_first_sale_joy` is a fifth route derived from candidate 031 after its proposed trigger was corrected from an opening failure to the actual first-sale celebration shown in the image. BiRefNet removed their disconnected generated effects, and the routes are limited to `story_first_profit` and `story_first_sale`. Godot's independent symbol layer remains authoritative, so both candidates are still `runtime_approved:false` pending detailed hand/edge and rights review.

### Individual functional-pose spot checks

| Candidate | Coarse alpha / costume result | Remaining review item | State |
|---|---|---|---|
| `functional_low_stock` | White blouse, apron, both odango buns, trousers, and boots retained | Clipboard-to-forearm contact and hand anatomy | placement candidate; hand review pending |
| `functional_sold_out` | White sleeves and both arms remain visible; silhouette is clean | Finger count/shape on both open hands | placement candidate; hand review pending |
| `functional_queue` | White blouse, clipboard, shoes, and outer silhouette retained | Fingers around the clipboard and wrist connection | placement candidate; hand review pending |

These spot checks do not change `runtime_approved`; the assets remain available through the pilot route only.

The staff-management capture `build/character_pilot_staff_hired_latest.png` opens the internal `店員` tab and exercises `staff_hired`. The staff list, candidate cards, and hiring controls remain visible while the full-body pilot is shown in the assistant slot; no button/card is covered and no second character is introduced. (`スタッフ` is the chrome label; `店員` is the internal tab ID used by the capture helper.)

The follow-up functional-cue capture `build/character_pilot_campaign_1280_latest.png` exercises `seasonal_campaign_started` at 1280x720. The selected `functional_campaign` texture is reported by `--inspect-pilot`, and the display frame clips the lower portion of the source full-body image without modifying the original 1024x1536 PNG. The character remains to the right of the left menu, the speech bubble stays readable, and the bottom objective/stat controls remain unobstructed. This is layout QA only; the candidate remains `runtime_approved:false`.

## Assistant placement QA (2026-11-02)

The assistant stage now reserves the area to the right of the mockup's left menu (`MainLayout.CHROME_MENU_RIGHT` plus a margin), clips its stage to the viewport, and applies the same safe-area placement to full-body pilots, bust-up reactions, and reaction symbols. The speech bubble is anchored beside the figure and lowered by `BUBBLE_TOP_DROP`, so it no longer sits on top of the left menu. Screen-scoped pilot cues are cleared when their management screen closes.

Visual captures:

- `build/character_pilot_layout_fixed_1280.png`
- `build/character_pilot_layout_fixed_1920.png`

Both resolutions show the `low_stock_notice` pilot without left-menu overlap; the bubble is lower and the summary strip remains the figure's baseline. Focused verification: `parse_all` covered 263 scripts with 0 errors, `character_visual_pilot` passed 4 tests / 273 assertions / 0 failures, and `onboarding` passed 6 tests / 69 assertions / 0 failures.

The same layout was rechecked through the repository's CLI capture path after a headless import (`--headless --import --quit`): `build/character_pilot_cli_1280.png` was produced with `Godot_v4.7.2-stable_win64_console.exe --rendering-method gl_compatibility --path . --resolution 1280x720 --script res://tools/capture_screen.gd -- --calm --pilot-cue=low_stock_notice --freeze --inspect-pilot`. The capture log reports `stage_visible=true`, `pilot_visible=true`, and the expected `derived_alpha/functional_low_stock.png` texture; the saved PNG shows the figure clear of the left menu and the speech bubble below the figure head.

Follow-up CLI captures also passed at 1920x1080 (`build/character_pilot_cli_1920.png`) and on the active roadworks management event at 1280x720 (`build/character_pilot_event_cli_1280.png`). The former keeps the assistant stage clear of the left menu at the target desktop resolution; the latter reports `event_roadworks.png` in `EventPilotFullbodyPicture` while the management window remains usable. The event pilot is shown only for the active event and does not replace the event's domain text or illustration.

The latest management-page capture is `build/character_pilot_event_roadworks_management_1280.png`. It opens the real `経営` page, reveals the event visual row, and shows the roadworks illustration beside the selected full-body event pilot while the store assistant remains in its separate cropped stage. The capture log reports `pilot_event ... visible=true ... event_roadworks.png`; this is display QA only and does not approve the candidate.

The capture helper was tightened in commit `8a055181`: when a story or pilot cue is requested, it clears any late startup achievement toast and reapplies the requested cue at the final save boundary. The 1280x720 capture `build/runtime_assistant_story_start_1280.png` therefore shows the requested story line and independent reaction mark without the unrelated `目標達成` overlay. The ordinary placement capture `build/runtime_assistant_placement_1280.png` confirms the same display-only bust-up crop: the source remains a 1024x1536 full-body texture, while only the 300 px-high assistant frame clips it at runtime.

## Next gate

1. Open the review gallery scene and inspect all 49 derived-alpha candidates.
2. Select/reject each candidate in the registry without changing Domain state.
3. Create derived alpha PNGs only for approved full-body/bust-up images.
4. Compare the title candidate at 1920x1080, 1600x900, and 1280x720 before connecting it to the title screen.
5. Keep `runtime_approved:false` until the above checks, rights review, and Godot screenshot QA are complete.

## Bust-up reaction candidate review (2026-11-02)

The 50 generated bust-up reaction candidates are available as a numbered contact sheet at
`docs/art/character_reaction_candidates_contact_20261102.png`. The sheet is a review aid only; it does not
promote any candidate into the runtime registry. The candidates preserve the intended differences in eye shape and
gesture, but many still contain generated speech bubbles or reaction marks inside the pixels. Those baked marks must
not be treated as the authoritative game UI, because the runtime owns the independent symbol/text layer.

The current runtime pilot therefore keeps five detailed bust-up routes (`reaction_discovery`,
`reaction_pleading`, `reaction_deadpan`, `reaction_milestone_calm`, and `reaction_first_sale_joy`) and leaves the other 45 candidates in the 334-image placement review.
Each candidate needs a clean derivation, hand/edge inspection, and a concrete game trigger before it can be added to
`character_visuals_v1.json`; `runtime_approved:false` remains unchanged.

## Derived-alpha review set completion (2026-11-02)

The remaining reaction candidates `reaction_019` through `reaction_050` were processed with the local BiRefNet
background-removal workflow into `assets/review/derived_alpha/`. All 50 reaction rows now have a review-only
RGBA derivative, and the numbered contact sheet is available at
`docs/art/character_reaction_derived_alpha_contact_20261102.png`.

The dark-matte contact-sheet pass confirms that the character silhouettes, blouse, apron, hair buns, and visible
hands remain present at coarse scale. It is not a per-image hand/edge approval: any candidate with uncertain fingers,
clothing holes, or baked reaction graphics still requires individual review. The source PNGs, placement mapping,
and `runtime_approved:false` states were not changed; these derivatives are not connected to the normal release
runtime. The focused asset check also asserts that all 50 reaction rows have a 1024x1024 RGBA review derivative.
Across the full placement table, the review-alpha scope is now explicit: 329 character candidates have derived
alpha PNGs, while all five `title_screen` candidates remain opaque background sources with no alpha derivative.

The pilot registry now has an explicit release gate in `character_visual_pilot_panel.gd`: debug builds can inspect
unapproved candidates, while a non-debug build selects a character visual only when that individual registry row has
`runtime_approved:true` and its texture exists. With the current registry (all 50 rows still unapproved), the legacy
assistant art remains the release fallback.

## Title pilot placement check (2026-11-02)

The CLI capture `build/standing_title_pilot_1280.png` was produced with
`--title --visual-variant=painted_v1`. The selected title candidate already contains the character, so
`TitleScreen` suppresses the standalone `title_rikka.png` layer and keeps the Godot-owned logo, menu buttons, and
notice control separate. The 1280x720 capture shows one character only and no baked-in menu is used as an input
surface. This remains a visual pilot capture; the title candidate is still not runtime-approved.

The opening cut-in was also checked at 1280x720 in `build/standing_opening_cutin_clean_1280.png`. The capture-only
transient cleanup removes unrelated startup notices before saving. The selected
`functional_business_greeting` full-body image is shown in the dedicated opening band, with the complete silhouette
inside the frame and no second assistant figure or input-blocking character layer. This is separate from the cropped
assistant stage used during ordinary store operation.

## Latest CLI display evidence (2026-11-02)

The current branch was re-captured through the non-headless CLI path. `build/standing_impl_low_stock_1280_current.png`
uses `--pilot-cue=low_stock_notice` and reports
`pilot_texture=res://assets/runtime/character_pilot/derived_alpha/functional_low_stock.png`,
`pilot_size=(1024,1536)`, and `legacy_visible=false`. The visible character sits immediately below the left menu,
the dialogue bubble follows the same left-side group with no large gap, and the bottom summary UI remains usable.
The full-body source remains unchanged; only the 300 px display frame clips it.

The title candidate was also re-captured at 1600x900 as
`build/title_bright_sakura_pilot_1600_current.png` with `--title --visual-variant=painted_v1`. The embedded Koharu
Rikka remains the only character layer, while the Godot-owned title logo, real buttons, and notice control remain
separate. This confirms the QA override path still works; it does not change the title candidate's
`runtime_approved:false` state.

## Assistant placement adjustment (2026-11-03)

Following the latest visual check, the assistant group was moved slightly right and raised above the mockup bottom
menu. The portrait anchor now uses `MainLayout.CHROME_BOTTOM + 52px`; the dialogue bubble keeps its independent
lower slot at `MainLayout.CHROME_BOTTOM + 12px`. The full-body source image and the display-only crop policy are
unchanged. The adjusted captures are:

- `build/character_pilot_low_stock_positioned_1280.png`
- `build/character_pilot_low_stock_positioned_1600.png`
- `build/character_pilot_low_stock_positioned_1920.png`

The 1280/1600/1920 captures move the display frame approximately 32px right and 22px up; at all three resolutions the
portrait and dialogue remain above the bottom menu, with the dialogue following the portrait horizontally. The source
full-body PNG is unchanged.
This is layout QA only; `runtime_approved:false` and the rights-review gate remain unchanged.

## Re-capture after route verification (2026-11-02)

`build/standing_impl_low_stock_1280_current2.png` was captured through the Godot CLI with
`--setup --pilot-cue=low_stock_notice`. The selected functional pilot remains visible in the
display-only frame, the original full-body source is not modified, and the bottom menu is still
clear. This capture also confirms the setup checklist and assistant bubble can coexist without
duplicating the legacy assistant layer. The asset remains review-only and is not runtime-approved.

## Bust-up candidate display check (2026-11-02)

`build/standing_review_reaction_001_1280.png` was captured with
`--setup --pilot-candidate=reaction_001`. The candidate is rendered in the dedicated
bust-up reaction slot with its generated symbol kept separate from the character layer;
it does not replace or stack with the full-body assistant frame. This is a review-only
candidate capture and does not change the runtime registry or approval state.

## Current focused CLI verification (2026-11-02)

The current branch was rechecked without Computer Use through the Godot 4.7.2 CLI. The
`character_visual_pilot` suite passed in four shards: **4 tests / 362 assertions / 0 failures**.
The event-panel suite also passed in four shards: **4 tests / 51 assertions / 0 failures**.
These checks cover registry routing, display-only bust-up cropping of the unchanged full-body
source texture, left-menu/bottom-chrome safe placement, separate reaction layers, and selected
event-pilot presentation. They do not change `runtime_approved:false` or replace the pending
human visual and rights review.

## Latest title and event route captures (2026-11-03)

`build/title_standing_pilot_latest.png` was captured at 1280x720 with
`--title --visual-variant=painted_v1`. The embedded character is rendered once, while the
Godot-owned title logo, real buttons, and notice control remain independent. The title route now
also permits an approved registry row to load in a normal build; an unapproved row still falls back
to the existing title background.

`build/standing_event_hot_day_latest.png` was captured at 1280x720 with
`--event=evt_hot_day --screen=経営`. The event CG and selected event standing pilot appear in the
event panel, while the persistent corner assistant is suppressed to prevent double rendering. The
event pilot does not cover the bottom controls.

The asset integrity check now compares each full-body/event source PNG with its derived alpha PNG
and rejects interior colored pixels that became transparent, which protects sleeves, apron areas,
hands, and held objects from background-removal regressions. The current focused run passed
**9 tests / 0 failures**. These are still QA captures; all 50 registry rows remain
`runtime_approved:false` pending visual, rights, and redistribution review.

The registry now also names an explicit 11-image core QA set in `core_pilot_ids`:
one title candidate, three full-body/service poses, three bust-up reactions, three
operation-state poses, and one event image. The remaining registry entries stay
available for route review; this core list is a QA baseline, not an approval or a
reduction of the 50-entry pilot registry.

The core set has a dedicated read-only contact sheet at
`build/character_pilot_core_contact_20261103.png`. It can be regenerated with:

```powershell
python tools/assets/build_character_pilot_contact_sheet.py --core-only
```

The sheet is a visual review aid only; it does not alter source PNGs, runtime
derivatives, or approval flags.

The per-image open-gate record for the core set is
`docs/art/CHARACTER_VISUAL_CORE_QA_20261103.csv`. It records the route capture
where one exists, while keeping detailed hand review, rights review, and
`runtime_approved` explicitly pending.

The Presentation routes use deferred `load(runtime_path)` calls for the selected
entry and do not `preload` the pilot registry. A focused asset test guards this
rule so the 50 candidate textures are not turned into a startup cache by a later
route change.

## Approval rollback procedure

Approval is intentionally separate from the image-processing and display work.
Before applying an approval, run the tool without `--apply` for the exact asset
IDs and save its validation output. When `--apply` is used, `tools/assets/approve_character_pilot.py`
writes a timestamped backup next to `data/presentation/character_visuals_v1.json`
before changing only the requested registry rows.

If a newly approved route causes a visual or runtime regression:

1. Disable the route immediately by restoring the timestamped registry backup, or
   revert the commit that contains the approval. Do not delete or overwrite the
   original candidate PNG or its derived alpha PNG.
2. Run the focused `character_visual_pilot` and asset-integrity tests; the legacy
   assistant/event/title fallback remains the expected result while the row is
   `runtime_approved:false`.
3. Keep the affected row held for visual/rights review and record the asset ID,
   backup timestamp, screenshot, and reason in the PR conversation before any
   re-approval.

The current branch has no applied approvals, so the fallback path is still the
baseline and no rollback artifact is required yet.

## Deferred-load measurement (2026-11-03)

`tools/measure_character_pilot_load.gd` measures actual Godot texture loads without
changing the registry. On Godot 4.7.2 with the OpenGL Compatibility renderer and an
RTX 3090, the 11-image core set loaded **11/11** entries in **480.492 ms** total;
the slowest entry was **60.284 ms**, and the observed video-memory peak was
**29.96 MB** (baseline **6.12 MB**). The 50 registered pilot entries loaded
**50/50** in **2134.629 ms**, with a slowest entry of **86.676 ms** and the same
observed peak **29.96 MB** in this run.

These measurements cover only the selected pilot registry, not all 334 review
images. They confirm that the runtime paths are loadable and that the Presentation
routes do not need a startup preload of the review set. Re-run with:

```powershell
Godot_v4.7.2-stable_win64_console.exe --rendering-method gl_compatibility --path . --script res://tools/measure_character_pilot_load.gd -- build/character_pilot_load_20261103.json
Godot_v4.7.2-stable_win64_console.exe --rendering-method gl_compatibility --path . --script res://tools/measure_character_pilot_load.gd -- --all-pilot build/character_pilot_load_all_20261103.json
```

## Latest stock-sold-out route capture (2026-11-03)

`build/character_pilot_stock_sold_out_current_1280.png` was captured through the
non-headless Godot CLI with `--pilot-cue=stock_sold_out --freeze --inspect-pilot`.
The selected `functional_sold_out` full-body pilot is displayed in the normal
assistant stage at 1280x720; the left menu, speech bubble, bottom objective/stat
strip, and event controls remain usable. The source full-body PNG is unchanged and
the display-only crop is still used. This is runtime route evidence only and does
not alter the `runtime_approved:false` gate.
