# Convenience_store_Sim

リアル寄りの **2.5Dアイソメトリック・コンビニ経営シミュレーション**（企画・設計段階）。

店舗の棚・レジ・冷蔵ケースなどをタイル単位で配置し、8カテゴリの商品を仕入れ・陳列。顧客行動、レジ会計、粗利・廃棄・広告費の収支を改善しながら経営する。

## 状態
- **仕様書・GitHub Issue登録済み、ゲーム本体は未実装**。
- 初期技術方針: Godot 4 / GDScript / Blender Python → PNG透明スプライト。
- ローカル開発・テスト中心（GitHub Actionsは使用しない）。

## 設計文書
1. [全体ゲーム仕様](docs/GAME_DESIGN_SPEC.md)
2. [2.5Dアセット制作規格](docs/ASSET_PRODUCTION_SPEC.md)
3. [什器10種・初期24SKU制作カタログ](docs/ASSET_CATALOG.md)
4. [顧客・在庫・経営シミュレーション規約](docs/SIMULATION_ECONOMY_SPEC.md)
5. [ゲーム進行・操作UI・初回導線](docs/GAMEPLAY_UX_SPEC.md)
6. [受入・テスト計画](docs/QA_ACCEPTANCE_PLAN.md)
7. [素材出典台帳](docs/ASSET_CREDITS.md)
8. [レビュー指摘と対応記録](docs/SPEC_REVIEW_2026-10-22.md)
9. [Issue連動実装タスクリスト](docs/IMPLEMENTATION_TASKS.md)

## GitHub管理
- [親Issue #1 — MVP全体計画](https://github.com/yn217/Convenience_store_Sim/issues/1)
- [全Issue](https://github.com/yn217/Convenience_store_Sim/issues)
- 実装作業は基盤→店舗配置→商品/在庫→客/会計→広告/経営→QAの依存関係で進行。

## 最初の開発ステップ
1. Godotプロジェクトとheadlessテスト基盤。
2. 16×12直交グリッドを2:1菱形に投影。
3. 1×2什器の配置/回転、レジ未設置でも建設できる状態を実装。
4. Blenderからレジ/棚/飲料ケースの4方向スプライトを自動生成。
5. 商品を仕入れ、補充し、客が会計して日次決算まで動く縦断スライスを構築。

現時点で動くゲームや実画像アセットは含まれません。


## 実装詳細規約（2026-10-22に追加）

**MVP実装時の正本:** [実装ベースライン](docs/implementation/00_BASELINE_AND_DECISIONS.md)。概念仕様だけで実装せず、次の契約書・JSON Schemaを参照する。

1. [00 — 仕様の優先順位、ゲーム定数、MVP凍結事項](docs/implementation/00_BASELINE_AND_DECISIONS.md)
2. [01 — Godotディレクトリ・scene・クラス/API契約](docs/implementation/01_ENGINE_CONTRACT.md)
3. [02 — タイル/アセットの物理寸法、投影、回転・anchor](docs/implementation/02_GRID_AND_ASSET_CONTRACT.md)
4. [03 — 在庫、客AI、会計、広告、日次の確定アルゴリズム](docs/implementation/03_ECONOMY_AND_SIMULATION_CONTRACT.md)
5. [04 — UI、セーブ/ロード、テスト・性能の実装契約](docs/implementation/04_UI_SAVE_QA_CONTRACT.md)
6. [05 — Codex/Claude向け担当レーン・作業順・完了条件](docs/implementation/05_IMPLEMENTATION_HANDOFF.md)
7. [06 — Blender什器Blueprint、商品サイズ、製造・検査手順](docs/implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md)
8. [JSON Schema 5種](docs/schemas/) / [サンプルと初期マスタ（什器10種・商品24SKU）](docs/examples/README.md)

**縮尺の規格:** 1tile=1m、表示128×64px/tile、source=256×128px/tile、Blender共通正投影45°方位・30°仰角、1×2什器は2mの長辺Eを客側とする。PNGのキャンバスを無理に同じ幅/高さへ揃えない。

**注意:** 規則/JSON/例の静的整合性のレビューは済んでいるが、ゲームコード・什器メッシュ・画像アセットの制作および実機検証はまだ行っていない。
