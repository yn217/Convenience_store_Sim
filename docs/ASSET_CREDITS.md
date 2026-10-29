# 素材・AI生成アセット出典台帳

登録済みの素材にはBlender、コード合成、生成AIによる画像が含まれる。
生成方法、公開されているモデル情報、プロンプト、利用条件を素材ごとに記録する。
ツールが公開しないseedやモデルの内部識別子は推測しない。
`tools/validation/check_asset_credits.py` が台帳の登録漏れと利用条件の空欄を検査する。

生成済みアセットの出典を、生成スクリプトと出力マニフェストに対応付ける台帳。第三者素材の利用条件は確認できていないため、再配布可否が未確認の行をリリース承認済みとして扱わない。

商品アイコン（`scripts/presentation/product_icons.gd`）は、画像ファイルを使わずコードでImage描画する**手続き的な仮アイコン（procedural placeholder）**。オリジナルのコード生成で、第三者素材・実在ブランド・ロゴは含まない。

|asset_id|asset_path|source_type (Blender/AI/third-party/code)|source_link_or_local_path|model_and_version|license_or_usage_terms|generation_date|human_review|redistribution_allowed|
|---|---|---|---|---|---|---|---|---|
|fixture_register_basic|assets/generated/fixtures/register_basic|Blender|tools/assets/blueprints.py + render_fixtures.py + fixture_looks.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ＋Blender手続きノードの質感。外部素材・画像テクスチャなし)。プロジェクトのライセンスに従う|2026-10-24|自動検査(validate_manifests, validate_fixture_zoom)＋目視|yes|
|fixture_shelf_general|assets/generated/fixtures/shelf_general|Blender|tools/assets/blueprints.py + render_fixtures.py + fixture_looks.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ＋Blender手続きノードの質感。外部素材・画像テクスチャなし)。プロジェクトのライセンスに従う|2026-10-24|自動検査(validate_manifests, validate_fixture_zoom)＋目視|yes|
|fixture_shelf_onigiri|assets/generated/fixtures/shelf_onigiri|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_warmer_oden|assets/generated/fixtures/warmer_oden|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_noodle|assets/generated/fixtures/shelf_noodle|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_shelf_bread|assets/generated/fixtures/shelf_bread|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_fridge_drink|assets/generated/fixtures/fridge_drink|Blender|tools/assets/blueprints.py + render_fixtures.py + fixture_looks.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ＋Blender手続きノードの質感。外部素材・画像テクスチャなし)。プロジェクトのライセンスに従う|2026-10-24|自動検査(validate_manifests, validate_fixture_zoom)＋目視|yes|
|fixture_shelf_snack|assets/generated/fixtures/shelf_snack|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_fridge_dessert|assets/generated/fixtures/fridge_dessert|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_freezer_ice|assets/generated/fixtures/freezer_ice|Blender|tools/assets/blueprints.py + render_fixtures.py + build_sprites.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う|2026-10-23|自動検査(validate_manifests)＋目視|yes|
|fixture_atm|assets/generated/fixtures/atm|AI|ユーザー提供AI画像 S01_atm.png → https://github.com/TencentARC/Pixal3D via tools/assets/pixal3d (cutout → Pixal3D → render_fixture.py → crop_fixture.py); assets/generated/fixtures/atm/PROVENANCE.json|Pixal3D b0cb2e1 (MIT) + DINOv3 ViT-L/16 (DINOv3 License) + NAF (Apache-2.0) + Blender 4.5.3 Cycles|ユーザー自身の参照画像から生成。実在ブランド・ロゴなし。RMBG-2.0(非商用)不使用|2026-10-25|ユーザーが採用(2026-10-25)＋validate_manifests|yes|
|fixture_copier|assets/generated/fixtures/copier|AI|ユーザー提供AI画像 S02_multifunction_copier.png → https://github.com/TencentARC/Pixal3D via tools/assets/pixal3d (cutout → Pixal3D → render_fixture.py → crop_fixture.py); assets/generated/fixtures/copier/PROVENANCE.json|Pixal3D b0cb2e1 (MIT) + DINOv3 ViT-L/16 (DINOv3 License) + NAF (Apache-2.0) + Blender 4.5.3 Cycles|ユーザー自身の参照画像から生成。実在ブランド・ロゴなし。RMBG-2.0(非商用)不使用|2026-10-25|ユーザーが採用(2026-10-25)＋validate_manifests|yes|
|customer_a|assets/generated/characters/customer_a|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|customer_b|assets/generated/characters/customer_b|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|customer_c|assets/generated/characters/customer_c|Blender|tools/assets/figures.py + render_customers.py + build_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(箱の人形、実在人物・商標なし)|2026-10-23|自動検査(validate_customers)＋目視|yes|
|office_worker|assets/generated/characters/office_worker|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|student_uniform|assets/generated/characters/student_uniform|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|casual_woman|assets/generated/characters/casual_woman|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|casual_man|assets/generated/characters/casual_man|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|older_person|assets/generated/characters/older_person|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|parent|assets/generated/characters/parent|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|clerk|assets/generated/characters/clerk|code|tools/assets/generate_character_variants.py|Python procedural sprites (iso2x_v1)|自作(架空の人物、ロゴ・商標・実在人物なし。AI生成のターンアラウンドは設計参考のみで同梱しない)|2026-10-24|自動検査(validate_customers)＋目視|yes|
|calibration_fixtures|assets/generated/fixtures/calibration|Blender|tools/assets/render_fixtures.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(校正マーカーのみ)|2026-10-23|自動検査|yes|
|calibration_characters|assets/generated/characters/calibration|Blender|tools/assets/render_customers.py|Blender 2.91.0 (EEVEE) + tools/assets スクリプト|自作(校正マーカーのみ)|2026-10-23|自動検査|yes|
|sfx_bank|scripts/presentation/sfx_bank.gd|code|scripts/presentation/sfx_bank.gd (正弦波合成、録音・配布音源なし)|GDScript (Godot 4.7.2)|自作|2026-10-23|ピーク/長さを試験で検査|yes|
|product_placeholders|scripts/presentation/fixture_presenter.gd|code|カテゴリ色の矩形をコード描画(パッケージ画像なし)|GDScript (Godot 4.7.2)|自作。実在ブランド/包装を含まない|2026-10-23|目視|yes|
|ui_icons|assets/ui/icons|code|assets/ui/icons/*.svg (手書きのオリジナルSVG。出典・内訳は assets/ui/icons/README.md)|手描きSVG(24x24, #ffffff) + GDScript (Godot 4.7.2)|自作。第三者素材・トレース・ロゴ/商標を含まない。プロジェクトのライセンスに従う|2026-10-24|目視|yes|

UIアイコン（`assets/ui/icons/`、41点。内訳は README: store, box, person, megaphone, bar-chart, gear, cash, wallet, users, sun, chevron-right, trash, rotate, move, heart, calendar, music-note, drop, eye, cart, truck, tag, grid, play, pause, coin, clock）は本プロジェクトで手書きしたSVGで、`scripts/presentation/ui_icons.gd` が実行時にテキストから描画する（.importは不要）。

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

|issue103-props-v1|assets/generated/props|project-generated Pillow fallback|tools/assets/generate_props.py; per-prop visual manifest and PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic fixtures and Japanese POP labels; no real brands or logos|PROVENANCE.json per prop|yes|
|issue103-back_counter_set|assets/generated/props/back_counter_set|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-bicycle_stand|assets/generated/props/bicycle_stand|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_bread|assets/generated/props/category_pop_bread|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_cup_noodle|assets/generated/props/category_pop_cup_noodle|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_dessert|assets/generated/props/category_pop_dessert|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_drink|assets/generated/props/category_pop_drink|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_ice|assets/generated/props/category_pop_ice|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_oden|assets/generated/props/category_pop_oden|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_onigiri|assets/generated/props/category_pop_onigiri|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-category_pop_snack|assets/generated/props/category_pop_snack|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-cherry_tree_a|assets/generated/props/cherry_tree_a|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-cherry_tree_b|assets/generated/props/cherry_tree_b|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-ceiling_light_strip|assets/generated/props/ceiling_light_strip|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-cigarette_shelf_generic|assets/generated/props/cigarette_shelf_generic|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-coffee_machine|assets/generated/props/coffee_machine|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-flower_bed_planter|assets/generated/props/flower_bed_planter|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-fryer_hot_snack_case|assets/generated/props/fryer_hot_snack_case|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-open_a_board|assets/generated/props/open_a_board|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-potted_plant_large|assets/generated/props/potted_plant_large|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-potted_plant_small|assets/generated/props/potted_plant_small|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-reachin_cooler_row|assets/generated/props/reachin_cooler_row|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-storefront_door|assets/generated/props/storefront_door|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-storefront_wall|assets/generated/props/storefront_wall|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|
|issue103-storefront_window|assets/generated/props/storefront_window|project-generated Pillow fallback|tools/assets/generate_props.py; PROVENANCE.json|iso2x_v1 / transparent RGBA|Fictional generic; no real brands/logos|yes|

## Coverage index for current generated IDs
|issue103-back_counter_set-v1|assets/generated/props/back_counter_set|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-bicycle_stand-v1|assets/generated/props/bicycle_stand|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_bread-v1|assets/generated/props/category_pop_bread|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_cup_noodle-v1|assets/generated/props/category_pop_cup_noodle|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_dessert-v1|assets/generated/props/category_pop_dessert|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_drink-v1|assets/generated/props/category_pop_drink|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_ice-v1|assets/generated/props/category_pop_ice|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_oden-v1|assets/generated/props/category_pop_oden|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_onigiri-v1|assets/generated/props/category_pop_onigiri|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-category_pop_snack-v1|assets/generated/props/category_pop_snack|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-cherry_tree_a-v1|assets/generated/props/cherry_tree_a|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-cherry_tree_b-v1|assets/generated/props/cherry_tree_b|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-ceiling_light_strip-v1|assets/generated/props/ceiling_light_strip|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-cigarette_shelf_generic-v1|assets/generated/props/cigarette_shelf_generic|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-coffee_machine-v1|assets/generated/props/coffee_machine|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-flower_bed_planter-v1|assets/generated/props/flower_bed_planter|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-fryer_hot_snack_case-v1|assets/generated/props/fryer_hot_snack_case|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-open_a_board-v1|assets/generated/props/open_a_board|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-potted_plant_large-v1|assets/generated/props/potted_plant_large|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-potted_plant_small-v1|assets/generated/props/potted_plant_small|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-reachin_cooler_row-v1|assets/generated/props/reachin_cooler_row|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-storefront_door-v1|assets/generated/props/storefront_door|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-storefront_wall-v1|assets/generated/props/storefront_wall|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue103-storefront_window-v1|assets/generated/props/storefront_window|code|tools/assets/generate_props.py|iso2x_v1 / Pillow fallback|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|

### Issue #111 exterior props

|issue111-vending_machine|assets/generated/props/vending_machine|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional NOVA DRINK branding; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-bench|assets/generated/props/bench|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-trash_recycle_bins|assets/generated/props/trash_recycle_bins|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; Japanese generic labels; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-nobori_banner_obento|assets/generated/props/nobori_banner_obento|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic Japanese label; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-nobori_banner_ice|assets/generated/props/nobori_banner_ice|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic Japanese label; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-nobori_banner_coffee|assets/generated/props/nobori_banner_coffee|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic Japanese label; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-car_stop_bollard|assets/generated/props/car_stop_bollard|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-parking_lot_straight|assets/generated/props/parking_lot_straight|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic road marking|2026-10-24|PROVENANCE.json|yes|
|issue111-parking_lot_corner|assets/generated/props/parking_lot_corner|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic road marking|2026-10-24|PROVENANCE.json|yes|
|issue111-parking_lot_end|assets/generated/props/parking_lot_end|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic road marking|2026-10-24|PROVENANCE.json|yes|
|issue111-parking_lot_crosswalk|assets/generated/props/parking_lot_crosswalk|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic road marking|2026-10-24|PROVENANCE.json|yes|
|issue111-pole_sign|assets/generated/props/pole_sign|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional コンビニ24-style NOVA sign; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-street_lamp|assets/generated/props/street_lamp|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional generic; no real brands/logos|2026-10-24|PROVENANCE.json|yes|
|issue111-parked_car_blue|assets/generated/props/parked_car_blue|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional compact hatchback; no real maker logos|2026-10-24|PROVENANCE.json|yes|
|issue111-parked_car_red|assets/generated/props/parked_car_red|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional compact hatchback; no real maker logos|2026-10-24|PROVENANCE.json|yes|
|issue111-poster_board|assets/generated/props/poster_board|code|tools/assets/generate_exterior_props.py; PROVENANCE.json|iso2x_v1 / Pillow deterministic primitives|Project-generated; fictional 新生活フェア campaign; no real brands/logos|2026-10-24|PROVENANCE.json|yes|

The three ledger scopes above cover the following generated IDs. This index is an inventory
cross-check, not a license approval; the human review and redistribution fields remain pending.

### Issue #104 character additions

`assets/generated/characters/{office_worker,student_uniform,casual_woman,casual_man,older_person,parent,clerk}` are original fictional procedural sprites generated by `tools/assets/generate_character_variants.py`. A built-in AI-generated turnaround was used only as a design reference and is not shipped. No logos, brands, or third-party likenesses are included. Reproducible under `iso2x_v1`; validated by `validate_customers.py`.

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
|painted_fridge_drink_v1|assets/generated/fixtures/fridge_drink|AI|prompt: painted FULL 4-view fridge, soft anime convenience-store illustration, dense fictional products; guide fridge_drink_0_body.png|built-in image generation|AI-generated; fictional products, no real logos|2026-10-24|PROVENANCE.json|yes|
|painted_shelf_general_v1|assets/generated/fixtures/shelf_general|AI|prompt: painted FULL 4-view gondola, soft anime convenience-store illustration, dense fictional products; guide shelf_general_0_body.png|built-in image generation|AI-generated; fictional products, no real logos|2026-10-24|PROVENANCE.json|yes|
|prop_storefront_window_painted_v1|assets/generated/props/storefront_window|AI|prompt: painted storefront window, blue/white fascia, warm glass, fictional NOVA MART; guide storefront_window_0_body.png|built-in image generation|AI-generated; fictional sign only|2026-10-24|PROVENANCE.json|yes|
|prop_storefront_door_painted_v1|assets/generated/props/storefront_door|AI|prompt: painted storefront door, blue/white fascia, warm glass, fictional NOVA MART; guide storefront_door_0_body.png|built-in image generation|AI-generated; fictional sign only|2026-10-24|PROVENANCE.json|yes|
|prop_storefront_wall_painted_v1|assets/generated/props/storefront_wall|AI|prompt: painted storefront wall, blue/white fascia, warm glass, fictional NOVA MART; guide storefront_wall_0_body.png|built-in image generation|AI-generated; fictional sign only|2026-10-24|PROVENANCE.json|yes|
|map_kakogawa_city_v1|assets/generated/maps/kakogawa_city_v1|AI|ユーザー提供 kakogawa_map_v1_package.zip（kakogawa_base.png。ユーザーの ChatGPT/Codex 会話で生成、prompt はその会話に保存。#154 / PR #155）; assets/generated/maps/kakogawa_city_v1/PROVENANCE.json|ChatGPT 画像生成（ユーザー提供、版はユーザー記録）|ユーザーが本プロジェクト用に生成・提供した架空化コンセプト地図。実在の商標・ロゴなし、測量地図ではない|2026-10-26|目視（座標QA画像 kakogawa_coordinate_qa.png でピンと建物の一致を確認）|yes|
|map_aoba_city_central_district_v2|assets/generated/maps/aoba_city_central_district_v2|AI|ユーザー提供 ui_free_map_bundle.zip（aoba_city_central_district_map_no_ui.png。ユーザーの ChatGPT/Codex 会話で生成、prompt はその会話に保存。#150）|ChatGPT 画像生成（ユーザー提供、版はユーザー記録）|ユーザーが本プロジェクト用に生成・提供した架空都市の地図。実在の商標・ロゴなし|2026-10-26|目視（ピン・ラベルの位置を測り直して座標と一致を確認）|yes|
|map_kobe_akashi_awaji_region_v2|assets/generated/maps/kobe_akashi_awaji_region_v2|AI|ユーザー提供 ui_free_map_bundle.zip（kobe_akashi_awaji_region_map_no_ui.png。ユーザーの ChatGPT/Codex 会話で生成、prompt はその会話に保存。#150 / #153）|ChatGPT 画像生成（ユーザー提供、版はユーザー記録）|ユーザーが本プロジェクト用に生成・提供した概念地図（神戸・明石・淡路を参考にした架空化。測量地図ではない）。実在の商標・ロゴなし|2026-10-26|目視（ピン・ラベルの位置を測り直して座標と一致を確認。岩屋港の番号なしピンは区画として扱わない）|yes|
|green_street_tree_v1|assets/generated/props/green_street_tree_v1|AI|assets/generated/props/green_street_tree_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|cherry_tree_painted_v1|assets/generated/props/cherry_tree_painted_v1|AI|assets/generated/props/cherry_tree_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|flower_planter_painted_v1|assets/generated/props/flower_planter_painted_v1|AI|assets/generated/props/flower_planter_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|bench_painted_v1|assets/generated/props/bench_painted_v1|AI|assets/generated/props/bench_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|compact_car_painted_v1|assets/generated/props/compact_car_painted_v1|AI|assets/generated/props/compact_car_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|compact_car_painted_v2|assets/generated/props/compact_car_painted_v2|AI|assets/generated/props/compact_car_painted_v2/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|vending_painted_v1|assets/generated/props/vending_painted_v1|AI|assets/generated/props/vending_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|
|bicycle_rack_painted_v1|assets/generated/props/bicycle_rack_painted_v1|AI|assets/generated/props/bicycle_rack_painted_v1/PROVENANCE.json (prompt)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-26|local visual QA; final user acceptance pending|yes|

|store_exterior_backdrop_v1|assets/generated/backgrounds/store_exterior_backdrop_v1|AI|assets/generated/backgrounds/store_exterior_backdrop_v1/PROVENANCE.json (prompt)|built-in image_gen (image-generation subagent)|OpenAI generated output; project use|2026-10-27|composite background candidate; final user acceptance pending|yes|

|store_exterior_backdrop_v2|assets/generated/backgrounds/store_exterior_backdrop_v2|AI|assets/generated/backgrounds/store_exterior_backdrop_v2/PROVENANCE.json (prompt)|built-in image_gen (image-generation subagents)|OpenAI generated output; project use|2026-10-28|tall-tree rear V vegetation; user review pending|yes|

|area_a_roadside_v1|assets/generated/backgrounds/area_a_roadside_v1|AI|assets/generated/backgrounds/area_a_roadside_v1/PROVENANCE.json (prompt)|built-in image_gen (image-generation subagent)|OpenAI generated output; project use|2026-10-28|combined parking apron candidate; entrance crossing excluded; user review pending|yes|
|ground_texture_seamless_v1|assets/generated/backgrounds/ground_texture_seamless_v1|AI|assets/generated/backgrounds/ground_texture_seamless_v1/asset.json (generated_prompt; PR #165)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-29|local visual QA (docs/qa/exterior-area-a/RESULTS.md); final user acceptance pending|yes|
|outer_sidewalk_strip_v1|assets/generated/backgrounds/outer_sidewalk_strip_v1|AI|assets/generated/backgrounds/outer_sidewalk_strip_v1/asset.json (generated_prompt; PR #165)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-29|local visual QA (docs/qa/exterior-area-a/RESULTS.md); final user acceptance pending|yes|
|rear_greenbelt_group_v1|assets/generated/backgrounds/rear_greenbelt_group_v1|AI|assets/generated/backgrounds/rear_greenbelt_group_v1/asset.json (generated_prompt; PR #165)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-29|local visual QA (docs/qa/exterior-area-a/RESULTS.md); final user acceptance pending|yes|

| roadside_landscape_v1 | assets/generated/backgrounds/roadside_landscape_v1 | AI | prompt: roadside flowerbed trees lamp on magenta background | image_gen | OpenAI output | 2026-10-27 | provisional visual review | yes |

| roadside_sidewalk_v1 | assets/generated/backgrounds/roadside_sidewalk_v1 | AI | assets/generated/backgrounds/roadside_sidewalk_v1/PROVENANCE.json (prompt) | built-in image_gen (image-generation subagent) | OpenAI generated output; project use | 2026-10-28 | projected side strip; final user acceptance pending | yes |

|roadside_greenery_v2|assets/generated/backgrounds/roadside_greenery_v2|AI|assets/generated/backgrounds/roadside_greenery_v2/PROVENANCE.json (prompt)|built-in image_gen (image-generation subagent)|OpenAI generated output; project use|2026-10-28|dense full-length side planting; review pending|yes|

| exterior_hvac_v1 | assets/generated/props/exterior_hvac_v1 | AI | prompt: isometric outdoor condensers and electrical equipment, transparent background | image_gen | OpenAI output | 2026-10-27 | provisional visual review | yes |
|fridge_dessert_2d_pilot|assets/generated/fixtures/fridge_dessert_2d_pilot|AI|assets/generated/fixtures/fridge_dessert_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|fridge_drink_2d_pilot|assets/generated/fixtures/fridge_drink_2d_pilot|AI|assets/generated/fixtures/fridge_drink_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|shelf_bread_2d_pilot|assets/generated/fixtures/shelf_bread_2d_pilot|AI|assets/generated/fixtures/shelf_bread_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|shelf_general_2d_pilot|assets/generated/fixtures/shelf_general_2d_pilot|AI|assets/generated/fixtures/shelf_general_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|shelf_noodle_2d_pilot|assets/generated/fixtures/shelf_noodle_2d_pilot|AI|assets/generated/fixtures/shelf_noodle_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|shelf_onigiri_2d_pilot|assets/generated/fixtures/shelf_onigiri_2d_pilot|AI|assets/generated/fixtures/shelf_onigiri_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|shelf_snack_2d_pilot|assets/generated/fixtures/shelf_snack_2d_pilot|AI|assets/generated/fixtures/shelf_snack_2d_pilot (prompt_*.txt / generation logs in each candidate folder; PR #161)|built-in image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-28|local visual QA only; candidate, runtime_approved false, not shown in game|yes|
|urban_grove_dense_candidate_v2|assets/generated/backgrounds/urban_grove_dense_candidate_v2|AI|assets/generated/backgrounds/urban_grove_dense_candidate_v2/PROVENANCE.json; grouped planting prompt from image-generation subagent|OpenAI image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-29|actual Godot 4.7.2 captures at three footprints and panned/zoomed view; runtime candidate, user approval pending|yes|
|urban_grove_detailed_candidate_v1|assets/generated/backgrounds/urban_grove_detailed_candidate_v1|AI|assets/generated/backgrounds/urban_grove_detailed_candidate_v1/PROVENANCE.json; grouped planting prompt from image-generation subagent|OpenAI image_gen (model identifier not exposed)|OpenAI generated output; project use|2026-10-29|actual Godot 4.7.2 captures at three footprints and panned/zoomed view; runtime candidate, user approval pending|yes|
