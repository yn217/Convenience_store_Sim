# Repository / Project Directory Architecture — 2.5D Convenience Store Sim

Status: Proposed and registered (2026-10-23). This document reserves paths for the implementation; **there is no Godot executable yet**.

## 1. Proposed final tree
```text
Convenience_store_Sim/
├── project.godot                          # Godot 4.7.2 project config — to implement
├── .gitignore                             # Godot/Blender/Python generated caches
├── README.md
├── scenes/
│   ├── main/Main.tscn
│   ├── store/{StoreWorld,FixtureView}.tscn
│   ├── characters/CustomerView.tscn
│   └── ui/{HUD,BuildPalette,FixtureInspector,InventoryPanel,
│           OrderPanel,DailyReport,AdPanel,SaveDialog}.tscn
├── scripts/
│   ├── domain/                            # Pure deterministic simulation (no SceneTree)
│   │   ├── {store_grid,placement_rules,fixture_catalog,product_catalog}.gd
│   │   ├── {inventory,ledger,customers,advertising,clock,events}.gd
│   │   └── path_service.gd
│   ├── application/                       # Command bus, snapshots, safe save / scene bootstrap
│   │   └── {game_state,game_commands,simulation_runner,save_manager,scenario_factory}.gd
│   └── presentation/                      # Isometric projection + input/view only
│       └── {iso_projection,store_world,fixture_presenter,
│            customer_presenter,ui_input_controller}.gd
├── data/
│   ├── fixtures/mvp_v1.json               # Canonical seed: 10 fixture types
│   ├── products/mvp_v1.json               # Canonical seed: 24 SKUs
│   ├── balance/mvp_v1.json                # Economy defaults
│   ├── scenarios/                         # Reproducible playable/benchmark scenes
│   └── visuals/                           # Fixture/product visual ID mappings
├── assets/
│   ├── source/
│   │   ├── blender/{fixtures,characters,environment}/
│   │   ├── textures/{packages,signage,environment}/
│   │   └── references/                    # License-cleared non-runtime refs, if used
│   ├── generated/
│   │   ├── fixtures/<fixture_type_id>/    # 4 rotations + layers + manifest
│   │   ├── products/<visual_id>/          # Item shape/labels/LOD sprites
│   │   ├── characters/<character_id>/     # Sprite sequences
│   │   └── environment/                   # Floor/wall/door pieces
│   └── ui/{icons,decoration}/             # Runtime UI art
├── tools/
│   ├── assets/{render_fixtures,validate_manifests,render_products}.py
│   └── validation/{check_catalog,check_save_schema}.py
├── tests/
│   ├── unit/                              # Domain math, money, grid, fixed RNG
│   ├── contract/                          # JSON schema, visual manifest, cross-refs
│   ├── scenario/                          # Placement → sale → daily close
│   ├── scene/                             # UI pointer/input and 2.5D composition
│   └── performance/                       # Fixed 16×12 / 20 fixtures / 30 customers
└── docs/
    ├── GAME_DESIGN_SPEC.md
    ├── ASSET_PRODUCTION_SPEC.md
    ├── implementation/                   # Normative 00..12 contracts
    ├── schemas/                          # Machine-readable schema docs
    ├── examples/                         # Review/example JSON data
    └── design/
        ├── PROJECT_DIRECTORY_STRUCTURE.md
        └── mockups/
            ├── README.md
            ├── 01_store_overview.svg
            ├── 02_layout_editor.svg
            ├── 03_inventory_management.svg
            └── 04_daily_report.svg
```

## 2. Directory rules
- **docs/design/mockups** stores *UI/experience reference*, not deployable in-game sprites. A screenshot showing tiles at smaller size for composition does not override the production 128×64-screen-pixel diamond specification.
- **assets/source** retains Blender parametric generators/mesh sources, package label sources, and source-of-license metadata. Source models use 1 Blender unit = 1 metre, standard camera/lighting preset.
- **assets/generated** holds the *actual runtime sprite images* after calibration. Four headings (0°,90°,180°,270°), shared origin and manifest, alpha PNG. All sprite assets in a fixture instance use the same anchor/crop per direction. Don't crop each independent layer arbitrarily.
- **data** is the runtime canonical master. Until #3 copies/imports the examples, `docs/examples/mvp_v1.*.json` are the canonical seeds. **Never silently maintain two divergent fixture/product copies**. Use import or generated files with equivalence tests.
- **scripts/domain** only depends on pure data and deterministic math. No Godot Nodes/sprites/UI. **scripts/presentation** reads domain snapshots; sends player actions via **scripts/application** only.
- **tools** is offline authoring/validation; Godot should not need Python/Blender to launch. Blender does not run during customer simulation.
- **tests** must include negative and scenario tests as well as golden mathematical tests; no GitHub Actions required. Record commands/versions locally.
- File naming: `snake_case` for data/tool files, `PascalCase` for Godot .tscn scenes to match scene tree in contract 01; stable `type_id`/SKU IDs are lower snake_case.

## 3. Version-control policy
| Category | Git policy | Reason |
|---|---|---|
| Godot code/scenes/JSON/tests/docs | Track normally | Core reproducible build |
| SVG screen mockups | Track under docs/design/mockups | Small, reviewable UI design reference |
| Blender generator scripts | Track normally | Reproducible assets |
| .blend project meshes (if used) | Track source; for large meshes discuss Git LFS beforehand | Binary source files can grow |
| Output PNG/WebP sprites | Track approved runtime assets, with manifests | Offline game build can work without Blender |
| Raw AI prompt/label provenance | Track reviewable text; record model/license | Traceability and license audit |
| .godot caches, Blender autosaves, Python cache, temp/executables | Ignore | Not source of truth |
| Concept exploration renders | Review first; only approved material moves to versioned docs or source | Avoid bloating repo with multiple low-quality drafts |

## 4. Git folder limitation and current status
Git does not track empty directories. Creating this specification and four SVG files creates **docs/design/mockups** as a real path. The other proposed paths are a *blueprint* until implementation generates code/assets. Empty runtime directories do not need placeholder files.
When code is introduced, preserve the app-layer boundaries and implement `project.godot`, scenes and tests as a first vertical slice, rather than precreating every path.

## 5. Mockup mappings, screens and issue ownership
| Mockup | Screen | Implementation owner / issue | Must validate |
|---|---|---|---|
| 01_store_overview.svg | Main gameplay HUD, isometric store, customer activity | #5, #15, #21, #23 | view hierarchy, camera, UI overdraw and tile selection |
| 02_layout_editor.svg | Build grid/ghost/rotation/fixture preview | #6, #7, #8, #21 | E-long edge access, 16×12, no build in OPEN+speed0 |
| 03_inventory_management.svg | SKU category list and product pricing, shelf quantity | #10, #11, #12, #21 | catalog IDs, price override, stock/expiry values |
| 04_daily_report.svg | Daily trend chart, revenue, gross/operating profit, visitor metrics | #17, #19, #21 | accounting ledger and cash separated |

## 6. Screen design decisions to settle before UI code
1. **Preferred visual target:** realistic, readable isometric supermarket fixtures and staff, clean cool-blue controls, green confirmation, warm food/product colors.
2. **Canvas is the protagonist**; overlay panels must not hide the whole 16×12 view, especially for building mode. Collapse side panes at narrow width.
3. Keep `P` pause separate from **close shop**. Build panel controls should show an explicit message if game is OPEN and merely paused.
4. For price/inventory, distinguish **shelf qty** from **backroom qty**, **supplier purchase cost** from **sale price**.
5. Report must distinguish **cash flow**, **revenue**, **COGS**, **gross margin**, **operating margin**. Illustrative mockup numbers are not authoritative gameplay fixtures.
6. Use icons/text along with colour for placement allow/disallow and stock warning.
7. The 4 SVGs are deliberately *editable composition mockups*, not final pixel-perfect 1920×1080 UI layouts. Production reference dimensions remain in `docs/implementation/02_GRID_AND_ASSET_CONTRACT.md` and `04_UI_SAVE_QA_CONTRACT.md`.
