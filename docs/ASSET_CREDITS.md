# 素材・AI生成アセット出典台帳

登録済みの素材は**すべて本プロジェクトで生成した仮アセット**（Blenderの箱ジオメトリ / コード合成）で、外部素材・生成AI素材・第三者テクスチャは含まない。AI素材（#12/#61）は、生成モデル/版・プロンプト・seed・商用再配布可否を確認してから、この表に追記して採用する。`tools/validation/check_asset_credits.py` が、`assets/generated` の全ディレクトリが台帳にあり、ライセンス/再配布欄が空・不明でないことを検査する（run_tests.ps1に組込み）。

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

## 受入チェック
- [ ] 元データと生成方法が再現できる
- [ ] 第三者素材のゲーム内利用/商用利用/再配布条件を確認
- [ ] 実在店舗・商品名/商標/ブランド包装に酷似しないことを確認
- [ ] 生成AI出力の破綻した文字・不要な人物/ロゴを修正
- [ ] アセットの役割（fixture / product / environment / character）が明記され、sourceとoutputの対応が付いている
- [ ] 各アセットにfixture_type_id / visual_idなどの安定IDを持たせる

推奨ファイル配置とマニフェスト形式は [ASSET_PRODUCTION_SPEC.md](ASSET_PRODUCTION_SPEC.md) を参照。

## 再生成手順
- 什器: [tools/assets/README.md](../tools/assets/README.md)（`render_fixtures.py` → `build_sprites.py` → `validate_manifests.py`）。PROVENANCE.json にBlender版・サンプル数・生成スクリプトのハッシュを記録。
- 客: 同README「Customer sprites」（`render_customers.py` → `build_customers.py` → `validate_customers.py`）。
- 台帳の検査: `python tools/validation/check_asset_credits.py .`（未登録のgenerated素材、不明ライセンス、再配布不可、AI/第三者素材の出典欠落を検出）。
