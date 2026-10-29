# 店内/店外2Dアセット仕様レビュー・不足項目と対応表（2026-10-29）

対象: \`yn217/Convenience_store_Sim\` Draft PR #164、Issue #102/#123/#157/#163。
目的: 既存MVPの契約を壊さず、ChatGPTで日本式2D原画を生成しCodexがGitHub登録/校正/実ゲーム接続する工程を**実装者が推測しなくてよいレベル**にする。

## 確認した正本

- 数学・物理占有: [02_GRID_AND_ASSET_CONTRACT](../implementation/02_GRID_AND_ASSET_CONTRACT.md)、\`scripts/presentation/iso_projection.gd\`。
- Domainの設備カタログ: \`data/fixtures/mvp_v1.json\`、\`scripts/domain/fixture_catalog.gd\`、\`docs/schemas/fixture_definition.schema.json\`。
- SKUの正本: \`data/products/mvp_v1.json\`、\`scripts/domain/product_catalog.gd\`、\`docs/schemas/product_definition.schema.json\`。
- runtime描画: \`scripts/presentation/fixture_sprites.gd\`、\`scripts/presentation/fixture_presenter.gd\`、\`scripts/presentation/visual_variants.gd\`、\`docs/schemas/visual_manifest.schema.json\`。
- 従来のアート方針: \`docs/ASSET_PRODUCTION_SPEC.md\`、\`docs/implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md\`、\`docs/art/GODOT_ASSET_ACCEPTANCE_MATRIX.md\`。
- 実画像とレビュー: \`assets/source/chatgpt_2d_interior\` と \`assets/review/imagegen_candidates/20261029\`（Draft PR #164、製品採用済みという意味ではない）。

## 必須修正と詳細仕様の所在

| ID | 優先 | 発見した仕様不足・不一致 | 今回の補完 / Codex実装作業 | 判定 |
|---|---|---|---|---|
| GAP-01 | P0 | 旧Blender必須と、現行2D原画生成の指示が矛盾 | [2D投影・制作契約](2D_ASSET_PRODUCTION_AND_PROJECTION_V1.md)に方式の優先順位を規定。旧3Dは保存し、新2Dに強制しない | 仕様化済、実装未検証 |
| GAP-02 | P0 | 「45°/30°」のImageGen記述だけで正確な2:1と判断している | 同docにXYZのworld-to-source、足元anchor、辺制御点と許容誤差、4向き校正を追加 | 仕様化済、画像QA未合格 |
| GAP-03 | P0 | 大きな屋根付きEMPTYを正しい基準と誤認し続ける | 什器family別 roof/棚板/冷ケース枠の例外とReference Gateを固定 (#102/#123/#157) | 未承認のcanonicalは使用禁止 |
| GAP-04 | P0 | 商品一体FULLをruntimeへ入れると在庫ゼロでも満棚になり得る | [在庫状態とruntime](2D_ASSET_RUNTIME_AND_EQUIPMENT_V1.md)に2つの方式、A=P−R、閾値、4状態テストを規定 | runtime実装/Schema拡張待ち |
| GAP-05 | P0 | マスタは27什器・59SKU・19カテゴリ、商品/設備Schemaは8カテゴリしか許可せず同期していない | 今回\`fixture_definition.schema.json\`の上位・slot enum、\`product_definition.schema.json\`を**19カテゴリへ拡張**。既存Domain種別と完全一致させる | Schema修正対象、validator/fixture全件実行待ち |
| GAP-06 | P1 | 大型3/4連の画像を1×1/1×2の設備に伸縮してしまう | 既存の物理占有を優先。大型は**新type_id＋別world footprint＋別Domain数値**。未測定はnullの候補とする | バランス値/実測が未決 |
| GAP-07 | P1 | 高解像度原画と小解像度を性能グレードに混同 | [在庫・装備の契約](2D_ASSET_RUNTIME_AND_EQUIPMENT_V1.md)にLOD、設備tier、装飾variantの独立ルール、購買・電力・容量データ契約を規定 | 数値はユーザー/プレイテスト待ち |
| GAP-08 | P1 | 店舗外をタイルごとに作って継ぎ目/Minecraft化、壁頂点に植栽を合わせて浮く、右側が足りない | [店舗外2D契約](2D_ASSET_EXTERIOR_AND_PIPELINE_V1.md)で一体型背景、世界線anchor、足元遮蔽、壁端超過範囲、昼夜レイヤーを固定 | Godot実画面検証待ち |
| GAP-09 | P0 | ImageGenとGitHub画像が別、ZIPがcompactしかない、アップロード報告がファイルと不一致 | full/compact ZIP、無変更原画、実画像blob SHA256、GitHub再取得の証拠、納品判定を定義 | アーカイブ全件監査待ち |
| GAP-10 | P0 | 画像分類違い、実在ブランド・不正AI文字、alphaハロー/透視収束をQAが見逃す | family別Reference Gate、G0-G6の独立Visual QA、段階別FAIL条件を規定 | 未承認候補にはruntime接続禁止 |
| GAP-11 | P1 | 候補情報をruntime manifestとして使用しがち | [asset_candidate.schema.json](../schemas/asset_candidate.schema.json)を新設。QA/分類・ファイルSha・投影・ジオメトリ・GitHub証拠と\`runtime_approved:false\`を別スキーマで記録 | 新候補から順次適用 |
| GAP-12 | P1 | 複数Codexサブエージェントが1度だけ実行、または同じPRを競合編集 | [店舗外・納品](2D_ASSET_EXTERIOR_AND_PIPELINE_V1.md)に継続サイクル、独立worktree、参考/投影/QA/Gitの担当分離を定義 | Codexの実運用ルール |
| GAP-13 | P1 | 既存MVP文書の「10什器/24SKU」が現行の27/59を完全に表していない | 10/24は2026-10-22時点の**初期MVPベースライン**。現行データの数量は新実装・新アセットの対象範囲として別管理。旧文書を削除/全置換しない | カタログ横断監査を追加実施 |
| GAP-14 | P1 | 1枚の高密度商品画像が客の遮蔽/在庫更新/描画負荷を正しく表現できるか未規定 | 前後レイヤー、glass、derived stock、表示LOD、固定負荷ベンチを具体化 | 実Godot test待ち |

**注意**: 「仕様化済」は画像が完成したことではない。既存PRに\`runtime_approved:false\`が多いことは**意図的な安全策**である。実装可能な契約を明確化したのであり、PASS証跡がないGateは未実施のまま残す。

## 19カテゴリのソース/Schema一致対象

\`\`\`text
rice_ball, oden, instant_noodle, bread, drink, snack, dessert, ice_cream,
bento, daily_fresh, coffee, capsule_toy, daily_goods, hygiene,
character_goods, soft_serve, frappe, bakery, pizza
\`\`\`

- \`fixture_definition.schema.json\`の\`allowed_categories\`と\`shelf_slots[].allowed_categories\`、
  \`product_definition.schema.json\`の\`category\`の3か所を同期。
- \`ProductCatalog.CATEGORIES\`（Godot側）が列挙している現行19カテゴリを正本とする。旧8カテゴリのSKU互換性を維持し、未知カテゴリを黙って許可する\`additionalProperties:true\`へ変更しない。
- **テスト要求**: 27件のfixture、59件のSKUすべてをJSON SchemaとGodotのsemantic validatorで検証、全SKUが互換什器の少なくとも1slotに収容可能なこと、既存セーブのtype_id参照が壊れないこと。これらは今回の仕様追記・schema更新だけではPASSを主張しない。

## 2D候補とruntime manifestの境界

\`\`\`text
ChatGPT/Codex 生成原画 -> asset_candidate.schema.json（review / Draft PR）
    -> 種別・参照QA -> 投影/寸法/4方位 -> 在庫/人物/ガラス合成
    -> Godotテスト/ユーザー承認 -> visual_manifest.schema.json（runtime）
    -> VisualVariants.resolve + fallback で段階的に導入
\`\`\`

- \`asset_candidate.schema.json\`はreview用で\`runtime_approved=false\`が必須。旧生成物は現物ファイル/QAと照合して順次正規化するが、古いmanifestを無断上書きしない。
- \`visual_manifest.schema.json\`は**既存runtime正本**。現在は\`state\`がFULLのみで、\`products_baked\`の挙動も明示されているため、レビューのために\`state\` enumを勝手に3～4状態へ広げない。拡張するならDomain/Presenter/テストを一体で改修する。
- 外部の画像生成モデルがプロンプトと違うものを描いた場合は\`requested_subject\`と\`actual_subject\`を記録し、実際の分類で保管。**期待した物に分類し直さない**。
- 同じ主体で高画質/小画質を持っていても\`fixture_type_id\`は変わらない。大型設備に性能差を与えるにはDomain側の新型式/Balance変更が必要。

## Codexへの実装順と完了基準

1. **Schema担当**: 27設備・59 SKUのSchema/Domain横断監査を実行。19カテゴリ以外に現在の実装と矛盾する必須enum/値があれば別Issueに列挙。現状のテスト結果を実数とログで報告。
2. **2D Reference担当**: ゴンドラ型式の正しいEMPTYを検証（巨大天板はP0 FAIL）、日本式パン/おにぎり/カップ麺の商品正面を承認。未承認基準をそのまま量産しない。
3. **Projection担当**: 代表1×2棚、1×1卓上鍋、2×2冷凍庫、大型3連、外観一体帯を実画面へ重ね、X/Y/Z制御点・接地点・r0...r3・壁遮蔽を可視化。
4. **Runtime担当**: \`products_baked\`と実在庫の一体画像矛盾を再現試験で確認し、層分離または正式4状態切替を設計/実装。売切れ時満棚を絶対回避。
5. **納品担当**: full ZIPに原寸PNGが実際に入ること、画像/ZIPのGitHub blob SHA照合、アート元データ保護、\`github_uploaded\`の事実との一致、fallback維持。
6. **独立QA担当**: G0-G6のスクリーンショットとFAIL/PASS、provenance、SKU/在庫/LOD/性能の回帰結果をIssueへ残す。ユーザー承認後のみ\`runtime_approved\`を変更する。

**サブエージェントは上記担当を継続して使う**。異なるworktree/PRで競合を減らし、blockedを全体終了としない。**GitHub Actionsは前提にせずローカルのテスト**で判定する。合格未確認を完了と記録しない。関連 Issue #163（アセット運用）、#157（常温棚）、#123（品質）、#102（什器型式）、Draft PR #164。
