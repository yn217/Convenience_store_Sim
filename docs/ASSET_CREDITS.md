# 素材・AI生成アセット出典台帳

登録済みの素材は**すべて本プロジェクトで生成した仮アセット**（Blenderの箱ジオメトリ / コード合成）で、外部素材・生成AI素材・第三者テクスチャは含まない。AI素材（#12/#61）は、生成モデル/版・プロンプト・seed・商用再配布可否を確認してから、この表に追記して採用する。`tools/validation/check_asset_credits.py` が、`assets/generated` の全ディレクトリが台帳にあり、ライセンス/再配布欄が空・不明でないことを検査する（run_tests.ps1に組込み）。

生成済みアセットの出典を、生成スクリプトと出力マニフェストに対応付ける台帳。第三者素材の利用条件は確認できていないため、再配布可否が未確認の行をリリース承認済みとして扱わない。

商品アイコン（`scripts/presentation/product_icons.gd`）は、画像ファイルを使わずコードでImage描画する**手続き的な仮アイコン（procedural placeholder）**。オリジナルのコード生成で、第三者素材・実在ブランド・ロゴは含まない。

|asset_id|asset_path|source_type (Blender/AI/third-party/code)|source_link_or_local_path|model_and_version|license_or_usage_terms|generation_date|human_review|redistribution_allowed|
|---|---|---|---|---|---|---|---|---|
|fixture_register_basic|assets/generated/fixtures/register_basic|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_general|assets/generated/fixtures/shelf_general|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_onigiri|assets/generated/fixtures/shelf_onigiri|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_warmer_oden|assets/generated/fixtures/warmer_oden|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_noodle|assets/generated/fixtures/shelf_noodle|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_bread|assets/generated/fixtures/shelf_bread|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_fridge_drink|assets/generated/fixtures/fridge_drink|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_snack|assets/generated/fixtures/shelf_snack|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_fridge_dessert|assets/generated/fixtures/fridge_dessert|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_freezer_ice|assets/generated/fixtures/freezer_ice|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|customer_a|assets/generated/characters/customer_a|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|customer_b|assets/generated/characters/customer_b|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|customer_c|assets/generated/characters/customer_c|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|calibration_fixtures|assets/generated/fixtures/calibration|Blender|tools/assets/render_fixtures.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(校正マーカーのみ)|2026-10-23|自動検査|yes|
|calibration_characters|assets/generated/characters/calibration|Blender|tools/assets/render_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(校正マーカーのみ)|2026-10-23|自動検査|yes|
|sfx_bank|scripts/presentation/sfx_bank.gd|code|scripts/presentation/sfx_bank.gd (正弦波合成、録音・配布音源なし)|GDScript (Godot 4.7.2)|自作|2026-10-23|ピーク/長さを試験で検査|yes|
|product_placeholders|scripts/presentation/fixture_presenter.gd|code|カテゴリ色の矩形をコード描画(パッケージ画像なし)|GDScript (Godot 4.7.2)|自作。実在ブランド/包装を含まない|2026-10-23|目視|yes|
|ui_icons|assets/ui/icons|code|assets/ui/icons/*.svg (手書きのオリジナルSVG。出典・内訳は assets/ui/icons/README.md)|手描きSVG(24x24, #ffffff) + GDScript (Godot 4.7.2)|自作。第三者素材・トレース・ロゴ/商標を含まない。プロジェクトのライセンスに従う|2026-10-24|目視|yes|

UIアイコン（`assets/ui/icons/`、25点: store, box, person, megaphone, bar-chart, gear, cash, wallet, users, sun, chevron-right, trash, rotate, move, heart, calendar, music-note, drop, eye, cart, truck, tag, grid, play, pause）は本プロジェクトで手書きしたSVGで、`scripts/presentation/ui_icons.gd` が実行時にテキストから描画する（.importは不要）。

|fixtures-v1|assets/generated/fixtures|Blender|tools/assets/render_fixtures.py + tools/assets/build_sprites.py; manifest: assets/generated/fixtures/PROVENANCE.json|Blender 2.91.0 / EEVEE / iso2x_v1|プロジェクト作成スクリプト由来。第三者素材なしをコード上で確認。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|PROVENANCE記録|未実施（#9残件）|yes|
|characters-v1|assets/generated/characters|Blender|tools/assets/render_customers.py + tools/assets/build_customers.py; manifest: assets/generated/characters/PROVENANCE.json|Blender 2.91.0 / EEVEE / iso2x_v1|プロジェクト作成スクリプト由来。第三者素材なしをコード上で確認。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|PROVENANCE記録|未実施|yes|
|products-shapes-v1|assets/generated/products|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-bottle_500|assets/generated/products/bottle_500|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-bread_bag|assets/generated/products/bread_bag|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-cup_noodle|assets/generated/products/cup_noodle|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-dessert_cup|assets/generated/products/dessert_cup|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-ice_bar_pack|assets/generated/products/ice_bar_pack|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-oden_piece|assets/generated/products/oden_piece|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-onigiri_triangle|assets/generated/products/onigiri_triangle|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|
|products-snack_pouch|assets/generated/products/snack_pouch|code|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。2026-10-24 ユーザー承認により再配布可(プロジェクト内スクリプトで生成)|生成時に記録|未実施|yes|

## Coverage index for current generated IDs

The three ledger scopes above cover the following generated IDs. This index is an inventory
cross-check, not a license approval; the human review and redistribution fields remain pending.

### Fixture IDs (10)

`freezer_ice`, `fridge_dessert`, `fridge_drink`, `register_basic`, `shelf_bread`,
`shelf_general`, `shelf_noodle`, `shelf_onigiri`, `shelf_snack`, `warmer_oden`

### Product visual IDs (24)

`rice_001_package`, `rice_002_package`, `rice_003_package`, `oden_001_package`,
`oden_002_package`, `oden_003_package`, `noodle_001_package`, `noodle_002_package`,
`noodle_003_package`, `bread_001_package`, `bread_002_package`, `bread_003_package`,
`drink_001_package`, `drink_002_package`, `drink_003_package`, `snack_001_package`,
`snack_002_package`, `snack_003_package`, `dessert_001_package`, `dessert_002_package`,
`dessert_003_package`, `ice_001_package`, `ice_002_package`, `ice_003_package`

## 受入チェック
- [x] 元データと生成方法が再現できる（生成スクリプト、PROVENANCE、ハッシュを登録）
- [ ] 第三者素材のゲーム内利用/商用利用/再配布条件を確認
- [ ] 実在店舗・商品名/商標/ブランド包装に酷似しないことを確認
- [ ] 生成AI出力の破綻した文字・不要な人物/ロゴを修正
- [x] アセットの役割（fixture / character）が明記され、sourceとoutputの対応が付いている
- [x] 各アセットに fixture_type_id / visual_idなどの安定IDを持たせる

## 未解決の確認事項

- [ ] リポジトリの配布ライセンスと、Blender本体・生成物の再配布条件を確認する
- [ ] #9の基準什器について人手による画風・ガラス・接地の承認を記録する
- [ ] 商品パッケージ（product）を追加する場合は、架空デザインであることと出典を個別登録する

推奨ファイル配置とマニフェスト形式は [ASSET_PRODUCTION_SPEC.md](ASSET_PRODUCTION_SPEC.md) を参照。

## 再生成手順
- 什器: [tools/assets/README.md](../tools/assets/README.md)（`render_fixtures.py` → `build_sprites.py` → `validate_manifests.py`）。PROVENANCE.json にBlender版・サンプル数・生成スクリプトのハッシュを記録。
- 客: 同README「Customer sprites」（`render_customers.py` → `build_customers.py` → `validate_customers.py`）。
- 台帳の検査: `python tools/validation/check_asset_credits.py .`（未登録のgenerated素材、不明ライセンス、再配布不可、AI/第三者素材の出典欠落を検出）。
