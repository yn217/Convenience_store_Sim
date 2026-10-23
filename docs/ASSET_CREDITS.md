# 素材・AI生成アセット出典台帳

生成済みアセットの出典を、生成スクリプトと出力マニフェストに対応付ける台帳。第三者素材の利用条件は確認できていないため、再配布可否が未確認の行をリリース承認済みとして扱わない。

|asset_id|asset_path|source_type (Blender/AI/third-party)|source_link_or_local_path|model_and_version|license_or_usage_terms|generation_date|human_review|redistribution_allowed|
|---|---|---|---|---|---|---|---|---|
|fixtures-v1|assets/generated/fixtures/**|Blender procedural|tools/assets/render_fixtures.py + tools/assets/build_sprites.py; manifest: assets/generated/fixtures/PROVENANCE.json|Blender 2.91.0 / EEVEE / iso2x_v1|プロジェクト作成スクリプト由来。第三者素材なしをコード上で確認。リポジトリのライセンス条項との照合待ち|PROVENANCE記録|未実施（#9残件）|要確認|
|characters-v1|assets/generated/characters/**|Blender procedural|tools/assets/render_customers.py + tools/assets/build_customers.py; manifest: assets/generated/characters/PROVENANCE.json|Blender 2.91.0 / EEVEE / iso2x_v1|プロジェクト作成スクリプト由来。第三者素材なしをコード上で確認。リポジトリのライセンス条項との照合待ち|PROVENANCE記録|未実施|要確認|
|products-shapes-v1|assets/generated/products/**|Procedural Pillow|tools/assets/build_products.py; per-shape manifests and assets/generated/products/PROVENANCE.json|Pillow / RGBA source sprites / iso2x_v1|架空ラベルのみ。第三者画像・実在ブランドなし。リポジトリのライセンス条項との照合待ち|生成時に記録|未実施|要確認|

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
