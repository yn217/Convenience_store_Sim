# Asset replacement audit

更新日: 2026-10-23

## 対象と結論

この監査は、#61 のアセット候補を現在のゲームへ接続する境界を整理するためのものです。今回のPRでは、Claudeが進行中のGodot実装を変更せず、`assets/generated`、`data`、`tools/assets`、アセット仕様・台帳だけを対象にします。

候補アセットは、固定の `iso2x_v1` カメラから同一Blenderソースを4回転レンダリングし、fixture manifestの `body` / `shadow` / `products` / `glass` と商品manifestのshape/slot情報で解決します。実行時の本番切替は未実施です。既存の仮アセットへ戻す経路を維持したまま、Godot側の受入確認後に別PRで接続します。

## 差し替え点

| 境界 | 現在の正本 | 候補側 | 変更可否 |
|---|---|---|---|
| 什器の論理定義 | `data/fixtures/mvp_v1.json` の `fixture_type_id` / footprint / access | `assets/generated/fixtures/<id>/manifest.json` | 候補側のみ変更 |
| 商品visual ID | `data/products/mvp_v1.json` の `visual_id` | `assets/generated/products/products_manifest.json` | 候補側のみ変更 |
| 什器画像生成 | 既存のGodot presentation経路 | `tools/assets/render_fixtures.py` → `build_sprites.py` | 候補生成のみ |
| 商品overlay計画 | Godot側の表示契約 | `scripts/presentation/product_overlay_plan.gd` と商品manifest | runtime受入待ち |
| provenance | `docs/ASSET_CREDITS.md` | `assets/generated/**/PROVENANCE.json` と validator | 台帳・validatorのみ変更 |

## Claudeとの境界

共有Worktreeでは、`scripts/application/**`、`scripts/domain/**`、`scripts/presentation/**`、`tests/**` に未コミット変更があるため、Codexはそれらを編集・退避・コミットしません。本PRではGodot scene、GameState、Pathfinding、Economy、Save/Load、SceneTree、描画順の実装変更を含めません。

Godot受入時に必要な確認は、別の統合PRで以下の順に行います。

1. 既存fixtureのfallbackを保持したまま、manifest解決だけを接続する。
2. 同一店舗で回転0/90/180/270、zoom 0.5/1/2、商品empty/low/medium/fullを比較する。
3. 客が什器の前後を通る場面で、body/product/glassと客の深度順を確認する。
4. 失敗時は候補manifestを無効化し、既存visual_idへ戻す。

## 現時点の証跡

- fixture: 10種、4回転、manifest検証 `0 problems`
- product: 8形状、4回転、24 SKU mapping、検証 `0 problems`
- customer: 3 manifest、検証 `0 problems`
- provenance: ledger 3行、参照検証 `0 problems`
- Godot実行時の配置・選択・ズーム・深度順: 未受入

この文書は設計・監査証跡であり、未実施のGodot受入や人手の画質承認を完了扱いにしません。
