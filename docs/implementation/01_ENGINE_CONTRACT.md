# Engine / Scene / API Contract v1.0
依存: [00_BASELINE_AND_DECISIONS](00_BASELINE_AND_DECISIONS.md), [02_GRID_AND_ASSET_CONTRACT](02_GRID_AND_ASSET_CONTRACT.md), [03_ECONOMY_AND_SIMULATION_CONTRACT](03_ECONOMY_AND_SIMULATION_CONTRACT.md)

## 1. 固定ディレクトリ構造
```text
project.godot
addons/                         # 必要な時だけ。エンジン標準を優先
scenes/main/Main.tscn
scenes/store/StoreWorld.tscn
scenes/store/FixtureView.tscn
scenes/characters/CustomerView.tscn
scenes/ui/{HUD,BuildPalette,FixtureInspector,ManagementPanel,SaveDialog}.tscn
scripts/domain/{store_grid,placement_rules,fixture_catalog,product_catalog,inventory,ledger,customers,advertising,clock,events}.gd
scripts/application/{game_state,game_commands,simulation_runner,save_manager,scenario_factory}.gd
scripts/presentation/{iso_projection,store_world,fixture_presenter,customer_presenter,ui_input_controller}.gd
data/{fixtures,products,balance,scenarios}/
assets/source/blender/fixtures/
assets/source/textures/packages/
assets/generated/fixtures/
assets/generated/products/
tools/assets/
tests/{unit,contract,scenario,scene,performance}/
docs/implementation/
docs/schemas/
```
ファイル名はsnake_case、class_nameはPascalCase、保存用IDはsnake_caseの安定文字列。autoloadは`AppRoot`のみに抑え、Global Mutable SingletonからDomainへ書き込まない。

## 2. シーン構成/責務
```text
Main (Control)
├─ AppRoot (Node; boot, dependency injection)
├─ GameHUD (Control; UI event handler)
├─ MainArea (HBoxContainer)
│  ├─ BuildPalette (Control)
│  ├─ StoreViewport (SubViewportContainer)
│  │  └─ StoreWorld (Node2D)
│  │     ├─ FloorLayer (Node2D, static)
│  │     ├─ ArchitectureLayer (Node2D)
│  │     ├─ ObjectSortRoot (Node2D, y_sort_enabled)
│  │     │  ├─ FixturePresenter (Node2D instances)
│  │     │  └─ CustomerPresenter (Node2D instances)
│  │     └─ SelectionOverlay (Node2D, drawn after world)
│  └─ FixtureInspector (Control)
├─ ManagementPanel (Control)
└─ ModalRoot (Control)
```
UI座標は画面、店舗座標はworld。Node2Dの描画/物理補間はDomainの`GameSnapshot`を読込む**read-only presenter**。実際のUI操作は`GameCommandBus.execute(command)`だけに送る。

## 3. Domainデータ契約
|構造|主キー/基本フィールド|owner|
|---|---|---|
|StoreState|store_id, width,height, entrance_edges[], fixture_instances{}|StoreGrid|
|FixtureDef|type_id, footprint, access_edges, capacity_units, placement_cost_yen, visual_id|FixtureCatalog|
|FixtureInstance|instance_id,type_id,x,y,rotation,stock_slot_ids[],enabled|StoreGrid|
|ProductDef|sku_id,category,purchase_cost_yen,default_sell_price_yen,expiry_seconds?,slot_units,visual_id|ProductCatalog|
|StockSegment|segment_id,lot_id,sku_id,location,physical_qty,reserved_qty,unit_cost_yen,expires_at?|Inventory|
|Reservation|reservation_id,customer_id,segment_id,qty,sell_unit_yen_snapshot,cost_unit_yen_snapshot|Inventory|
|CustomerState|customer_id,phase,position,route,cart_reservation_ids[],patience_remaining|CustomerSim|
|EconomyState|cash_yen,applied_event_ids,ledger_transactions[],daily_reports[]|Ledger|
|GameState|schema_version,time_sec,day,random_states,store,customers,economy,ad_*|Application|

JSONキーの表現と型は`docs/schemas/`および`03_ECONOMY_AND_SIMULATION_CONTRACT.md`を優先。数値は表示だけ丸め、内部で浮動小数円を使わない。

## 4. コマンド/結果とイベント
**全更新をCommandBusで逐次実行**。命令処理結果の形:
```text
CommandResult { ok: bool, code: StringName, message_key: StringName, event_ids: Array[String], new_revision: int }
```
- `place_fixture(type_id,x,y,rotation)` — cost/occupied/path validation → instance_idとcapital ledgerを確定。
- `move_fixture(instance_id,x,y,rotation)` — 元占有をトランザクション中一時除外、全検査→一度だけ更新。買い直し料金なし。
- `remove_fixture(instance_id)` — 停止中、予約なし、在庫をバックヤードへ移動してから撤去。返金率はbalance設定（初期0円固定）。
- `order_stock(sku_id,qty)` — 現金チェック、購入イベント、バックヤードにStockSegment作成。
- `restock(instance_id,slot_id,sku_id,qty)` — 対応カテゴリ/容量/availableを検査→ロット移動。
- `set_sell_price(sku_id,new_price_yen)` — 価格更新、予約済取引のsnapshotは変更しない。
- `set_next_day_ad(tier_yen)` — 翌日適用、現金の請求は日境界で一度だけ。
- `start_business()`, `request_close_business()`, `set_speed(speed)` — 営業状態と時間停止は別の状態遷移。[08](08_RUNTIME_STATE_AND_COMMANDS.md)を正とする。
- `save(slot_id)`, `load(slot_id)` — 別のServiceだが、進行中tickの安全境界で実行。
```
EventEnvelope { id: string, tick: int, type: string, payload: Dictionary }
```
UIは直接 Domain.reset/qty update/cash modification を呼ばない。`CommandResult.code` enum:
`OK, NOT_PAUSED, OUT_OF_BOUNDS, OCCUPIED, NON_BUILDABLE, ENTRANCE_BLOCKED, REGISTER_BLOCKED, UNREACHABLE_ACCESS, INSUFFICIENT_CASH, INVALID_SKU, INCOMPATIBLE_PRODUCT, CAPACITY_EXCEEDED, STOCK_UNAVAILABLE, RESERVATION_ACTIVE, SAVE_INVALID, MISSING_REGISTER, MISSING_STOCK, MISSING_SHELF, PAYMENT_BLOCKED, INVALID_OPERATION`。
見た目とゲームの事実を同じeventに結合しない。イベント反映後は`revision`が単調増加する。

## 5. Boot sequence
1. balance/constants読込・検証。
2. fixture/productマスタのschema検証、stable ID重複検査。
3. sprite manifestを読込（missing assetsはテストではFAIL、開発中は明示的プレースホルダー）。
4. new-game 初期Factory またはsave loader→Domain不変条件検査。
5. Scene Presenterへ最初のSnapshotを渡し、カメラ全体表示。
6. UIと入力制御を接続後、ユーザー操作を許可。シミュレーションは初期pause。

## 6. UI/Domainの更新方式
- 経営計算は`SimulationRunner`の固定時間ステップでのみ更新。Rendering FPSに依存しない。
- 初期値はGameState revision=0。最新のimmutable snapshotを取り出してpresenterを更新。
- 各UI操作/Domainイベントの`change_set`を発行し、変更された什器/在庫/顧客だけビューを更新。ズームの度に全画像を再生成しない。
- スプライト描画の生成オブジェクトとインベントリ実数を混合しない。
- SaveManagerはGameStateの安全なスナップショットを直列化。読み込んだ状態の厳密検査を行ってから稼働状態へ差替える。

## 7. 独立テストと開発依存順
A. `GameState/Schema` と配置判定の純粋テスト → B. 床レンダラ → C. FixtureRenderer仮画像 → D. Blender production pipeline → E. Inventory → F. Customers/Ledger → G. UI/Save → H. End-to-end。
- DomainはGodot SceneTree/Node/UIを参照しない。Unit testはheadlessで数値確認可能。
- アセット担当はマニフェスト契約のみ共有し、経営計算ファイルを変更しない。
- コードはIssue単位で分割、1PRに複数のスキーマ変更を黙って混ぜない。

## 8. 保存とCatalogの追加契約
- `GameState`は**store_reputation**と**product_price_overrides{sku_id:int yen}**も保持する。値付け時は上書きマップを更新し、ロットのpurchase costを変更しない。
- `SaveManager`は[savegame.schema.json](../schemas/savegame.schema.json)の厳密なCustomerState/LedgerTransaction/DailyReport構造に従う。任意Dictionaryで全てを通すことは禁止。
- カタログJSON配列はfixture/product schemaを**各要素に**適用し、意味検証でID参照と棚slot capacityを照合する。

## 9. 2026-10-23 実行順の補完
- [08_RUNTIME_STATE_AND_COMMANDS](08_RUNTIME_STATE_AND_COMMANDS.md)のFIFO command phaseは**speed0でも稼働**。固定tick loop外から配置・仕入・UI変更をコミット可能とする。
- 顧客/会計/売上だけを[09_DETERMINISTIC_SIMULATION_AND_SAVE](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)の固定step・LCG32で更新。Node2Dの_processに会計を置かない。
- `business_state`はSETUP/OPEN/CLOSING/PAYMENT_BLOCKED、`speed_setting`は0/1/2/4で独立。OPEN+speed0中の建設は禁止。
