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
