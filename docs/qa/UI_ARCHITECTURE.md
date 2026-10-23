# UI アーキテクチャ: オーバーレイ構成 (Phase 1)

対象: `scripts/presentation/main_layout.gd`, `scenes/main/Main.tscn`。計画は `docs/qa/UI_REDESIGN_PLAN.md`。

## 1. 方針
- 店舗ワールド (SubViewportContainer > SubViewport > StoreWorld) は**ウィンドウ全面**の最下層。
- UI は全てその上に**オーバーレイ**として浮く。パネルの開閉でワールドのサイズもカメラも変わらない。
- マウス入力を取るのはパネル (PanelContainer) と SCREEN 中の暗幕 (ScreenDimmer) だけ。コンテナ・空の Control は `MOUSE_FILTER_IGNORE`。
- 層の順序は責務順 (ワールド < HUD/レール/サマリー < 文脈パネル < 通知 < モーダル)。z_index は使わず、子の並び順で決める。
- SubViewport は残す。入力・カメラの分離に使っており、外すと StoreWorld の座標系と入力の経路を全て書き換えることになるため、描画パスは増やしていない。

## 2. シーンツリー (旧 / 新)

旧 (`integration/m6-ui`):
```
Main (Control)
├─ Layout (VBoxContainer)
│  ├─ TopHUD (PanelContainer 64px)            … HUD の行
│  ├─ MainArea (HBoxContainer)                 … 3 列
│  │  ├─ LeftNav (PanelContainer 200px, コード生成)
│  │  ├─ BuildPalette (PanelContainer 280px, 常時)
│  │  ├─ StoreViewport (SubViewportContainer, 残り幅)
│  │  │  └─ SubViewport > StoreWorld
│  │  └─ FixtureInspector (PanelContainer 320px, 常時) > Scroll > Body (11 カード)
│  └─ BottomRow (HBoxContainer, コード生成)
│     ├─ CommandGrid (PanelContainer, 削除)
│     └─ MetricBar
├─ FloatCards (コード生成, 全面 IGNORE)
├─ RemoveDialog / BuildController / BusinessController / ... (コントローラ)
```

新 (`feature/m7-ui-modes`):
```
Main (Control, IGNORE)
├─ Layout (Control 全面, IGNORE)                            … 画面レイヤ
│  ├─ MainArea (Control 全面, IGNORE)                       … 世界 + 文脈パネル
│  │  ├─ StoreViewport (SubViewportContainer 全面)           … 最下層 (ワールド)
│  │  │  └─ SubViewport > StoreWorld
│  │  ├─ LeftNav (PanelContainer, 72px の浮遊レール, 左上 12px, STOP)  … HUD/ナビ層
│  │  ├─ BuildPalette (PanelContainer 280px, 左の浮遊窓, BUILD のみ表示)
│  │  └─ FixtureInspector (PanelContainer 320px, 右の浮遊窓, SELECTED のみ) > Scroll > Body
│  │     └─ 1 枚の窓「インスペクタ」: 什器ブロック (FixtureCard) / 詳細 (折りたたみ) / 移動・回転・撤去 / 客の行
│  ├─ TopHUD (PanelContainer 全幅 64px, 上端, STOP)          … HUD 層
│  └─ MetricBar (下端から 12px の中央寄せ 4 枚のカード, 行自体は IGNORE) … サマリー層
├─ FloatCards (全面 IGNORE, カードのみ STOP)                 … 通知層 (トースト / 浮遊カード)
├─ ScreenDimmer (全面, STOP, SCREEN のみ表示)                … モーダル層
├─ ManagementWindow (中央 PanelContainer 780x600, SCREEN のみ) … モーダル層
│  └─ VBox: 見出し行 (経営管理 / 閉じる) + ScreenTabs (TabContainer)
│     ├─ 商品 > ScrollContainer > Body (在庫, 販売価格)
│     ├─ 経営 > ScrollContainer > Body (営業, 今日のイベント, はじめかた・目標)
│     ├─ データ > ScrollContainer > Body (日次レポート)
│     └─ 設定 > ScrollContainer > Body (演出・音, 表示モード (O), セーブ / ロード)
├─ RemoveDialog / コントローラ (変更なし)
```

## 3. 層とマウス入力
| 層 | 要素 | マウス |
|---|---|---|
| ワールド | MainArea/StoreViewport | 空き部分は全てここに届く (モードによらず) |
| HUD / ナビ / サマリー | TopHUD, LeftNav, MetricBar | パネルの矩形だけ STOP。サマリーの帯自体は IGNORE |
| 文脈パネル | BuildPalette (BUILD), FixtureInspector (SELECTED) | 表示中の矩形だけ STOP |
| 通知 | FloatCards の各カード | カードの矩形だけ STOP (ルート IGNORE) |
| モーダル | ScreenDimmer, ManagementWindow | SCREEN 中だけ。暗幕が全面を覆い、ワールドとレールを止める |

閉じたパネルは `visible = false` (透明度ではない)。`_blockers_at` の試験で、閉じた後に見えない遮断が残らないことを確認している。

## 4. カメラ
- `StoreWorld.safe_inset` (Vector4: 左=レール右端+12, 上=HUD+12, 右=12, 下=サマリー+12 = 76)。レールとサマリーは浮遊しており、安全領域はその外側の余白だけを取る。
- `fit_view()` (起動時の初回フィット, F キー) は、ビューポートからこの安全領域を引いた矩形にフロアを収め、原点をその左上へずらす。
- 開閉・モード切替ではカメラに触れない。`zoom_at` / `pan_by` / `clamp_to_viewport` は従来どおりビューポート全体で動く。
- 画面座標からタイルへの変換 (`screen_to_tile`) は SubViewport 座標のまま。SubViewportContainer は stretch=true でビューポートに一致しているため、ピッキング・配置ゴースト・ドラッグ・ズームは全て同じ座標系で揃っている。

## 5. 固定 3 列レイアウトに依存していたコード
| ファイル | 依存していた箇所 | 変更 |
|---|---|---|
| `scripts/presentation/main_layout.gd` | HBox の 3 列, `apply_layout` の幅, コンパクト切替 (PaletteTab/InspectorTab), `style_sections` のみ | 全面再構成。`_layout_overlay` でアンカー、`UiMode` で表示切替、カードを管理タブへ移動 |
| `scripts/presentation/left_nav.gd` | 200px の縦リスト, 小見出し, `_focus_section` (インスペクタを見出しへスクロール) | 80px のアイコンレール。id を発信 (`item_pressed`)。スクロール処理は削除 |
| `scripts/presentation/command_grid.gd` / `command_bar.gd` | 下段の 2 行, `scroll_to_section`, `_focus_palette`, `_layout()` で親を辿る | 削除 (テスト含む)。機能はレール・インスペクタ・O キーへ |
| `scripts/presentation/store_world.gd` | `fit_view` が全ビューポートを使う | `safe_inset` を導入し安全領域内にフィット |
| `scripts/presentation/float_cards.gd` | `_follow_store` がストアの矩形に追従 (ストアが全面になると左上に重なる) | `inset` (Vector2) を加算する小さな変更のみ。MainLayout が設定 |
| `scenes/main/Main.tscn` | `Layout` が VBoxContainer, `MainArea` が HBoxContainer | Control に変更 (子のアンカーはコードで設定) |
| `tools/capture_screen.gd` | 無し | `--build`, `--screen=タブ` を追加 |
| controllers (`build_controller.gd`, `stock_controller.gd`, `business_controller.gd`, `report_controller.gd`, `price_controller.gd`, `save_controller.gd`, `progression_controller.gd`, `event_controller.gd`, `cue_player.gd`, `overlay_controller.gd`, `fixture_card.gd`) | `Layout/MainArea/FixtureInspector/Scroll/Body` などのノードパス | **変更なし**。ノードは同じ名前・同じ親のまま。カードは管理タブへ移るが、コントローラは参照を保持しているため動作は同じ |
| `scripts/presentation/game_hud.gd`, `metric_bar.gd`, `ui_theme.gd`, `ui_fx.gd` | 無し | **変更なし** (他担当のため)。MetricBar は親の並びだけ変わる |

## 6. テスト
- 追加: `tests/unit/test_ui_mode.gd` (遷移), `tests/scene/test_panel_modes.gd` (モードごとの表示, ワールドの大きさ不変, カメラ不変, 入力の遮断, 閉じた後の遮断なし, Esc/B, 営業状態バッジ)。
- 更新: `test_left_nav.gd` (5 項目・id 発信), `test_section_cards.gd` (インスペクタ 1 枚 / 管理タブ 9 枚), `test_ui_integration.gd` (幅の試験を BUILD 中の寸法試験へ, 配置クリック試験は BUILD を開いてから), `test_shell_camera_input.gd` (コンパクト試験を削除), `test_build_ui.gd` / `test_metric_bar.gd` (パレットの幅を offset で判定)。
- 削除: `test_command_grid.gd`, `test_command_bar.gd`。
