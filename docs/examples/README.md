# 実装用サンプルデータと検証の境界

## 入力データ（仕様と機械可読なサンプル）
|サンプル|中身|対応スキーマ|
|---|---|---|
|[mvp_v1.fixtures.json](mvp_v1.fixtures.json)|初期10種の什器マスタ（配列）|[fixture_definition.schema.json](../schemas/fixture_definition.schema.json) を**各要素**に適用|
|[mvp_v1.products.json](mvp_v1.products.json)|8カテゴリ×3SKU=24種類（配列）|[product_definition.schema.json](../schemas/product_definition.schema.json) を**各要素**に適用|
|[mvp_v1.balance.json](mvp_v1.balance.json)|ゲーム時間/集客/資金/広告のデフォルト|[balance_config.schema.json](../schemas/balance_config.schema.json)|
|[fridge_drink.fixture.json](fridge_drink.fixture.json)|単体什器定義の例|fixture_definition.schema.json|
|[drink_001.product.json](drink_001.product.json)|単体SKU定義の例|product_definition.schema.json|
|[fridge_drink.visual.json](fridge_drink.visual.json)|冷蔵ケース4方向・3段×8位置の**仕様サンプル**|[visual_manifest.schema.json](../schemas/visual_manifest.schema.json)|
|[empty_store.savegame.json](empty_store.savegame.json)|空店舗のセーブ形式例|[savegame.schema.json](../schemas/savegame.schema.json)|

### 運用
- 什器とSKUは上記配列をGodotの`res://data/fixtures/mvp_v1.json`/ `res://data/products/mvp_v1.json`へ**コピーまたはimport**し、マスタの重複手入力をしない。
- **JSON Schemaの構造検証とsemantic validationは別物**。schema検証に加え、10種×24SKUの参照、キャパシティ合計、4方向、画像ファイル存在、実Blender mesh bbox、画像投影校正を実装する。
- JSON Schema Draft2020-12。ローカル開発環境にはPythonの`jsonschema`パッケージ等の標準的validatorを使って良い。Godotランタイム側では読み込み時に必要な型/数量/参照/経路を同等にチェックする。外部Validatorライブラリをランタイムへ無理に同梱しない。
- `fridge_drink.visual.json`に書かれたRGBA PNG名、キャンバス、pivotは**データ構造と座標式の動作を説明するための例**であって、実PNGの生成結果ではない。Blender生成後に画像を計測し、manifestを再生成して置き換える。現時点で添付PNGは存在しない。
- 商品の`visual_id`も将来画像アセットへの参照予約名であり、現在画像が存在することを意味しない。
- マスタの自動生成結果とドキュメントのfixture寸法が食い違った場合は、[実装用アセット規格](../implementation/02_GRID_AND_ASSET_CONTRACT.md)を優先し、配列を修正してローカルテストを再実行する。
- **実装前のJSONと数値の静的整合性**はレビュー可能だが、レンダリング品質やスプライト縮尺の一致は本物のPNGを生成してGodotへ読み込むまで合格としない。
