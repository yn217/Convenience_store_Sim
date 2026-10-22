# MVP 実装疑似コード・関数別契約 v1.0 (2026-10-23)

> 最終の「どの関数が何をするか」の定義。Godot 4.7.2/GDScriptを想定。**このファイルは仕様であり実装コードではない。**
> 正本: [00 Baseline](00_BASELINE_AND_DECISIONS.md)、[02 Grid/Asset](02_GRID_AND_ASSET_CONTRACT.md)、[08 Runtime](08_RUNTIME_STATE_AND_COMMANDS.md)、[09 Simulation](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)。
> 特に保存中のコマンドID/経済イベントID、OPENとpause、資金不足の費用処理は08/09の規則に従う。

## 1. 関数名・戻り値・副作用（ドメインはNode/GUIへ依存禁止）
|module / public function|入力|出力|副作用と失敗|
|---|---|---|---|
|`StoreGrid.cells_for(type,w,h,origin,rotation)`|fixture def, int x/y, r∈0..3|ordered Vector2i[]|なし。r0 1×2→(x,y),(x,y+1)、r1→(x,y),(x+1,y)|
|`StoreGrid.access_for(instance)`|fixture instance/def|sorted walkable Vector2i[]|なし。ローカルfrontをrotateし隣接セルを生成|
|`StoreGrid.validate_placement(snapshot, proposal)`|state, type,x,y,r|PlacementResult|なし。out-of-bounds/占有/固定入口/主要到達性を検査|
|`StoreGrid.commit_placement(state,proposal)`|state, valid proposal|updated state+events|資金減算と占有同時commit。不正は不変|
|`PathService.find(start,goal,grid_revision)`|Vector2i×2|path Vector2i[] or []|なし。4近傍、同点N,E,S,W。構造更新でcache invalidation|
|`Inventory.order(state,sku,qty,event_id)`|SKU,1..9999,unique command/event|Result+events|現金/lot同時commit。原価は仕入時snapshot|
|`Inventory.restock(state,fixture,slot,sku,qty)`|stock/slot/lot segments|Result|カテゴリー、slot capacity、available、FEFOを先に検証。失敗は不変|
|`Inventory.reserve(state,customer,segment,qty)`|customer,lot segment,qty=1|reservation_id/Result|physicalは減らさずavailable=physical−reservedを再検査|
|`Inventory.expire_at(state,time)`|game_time_seconds|events|予約解放→期限切れ数量廃棄→費用記録（1回のみ）|
|`Register.checkout(state,transaction_id,reservation)`|transaction ID+予約|receipt/Result|棚physical−/予約−/売上+/COGS+/cash+を単一commit|
|`Demand.arrivals(state,tick)`|day/hour, RNG arrivals state|0/1 hopeful visitors|有効営業中1stepで乱数を1回進める。draw RNDから独立|
|`Demand.choose(state,customer)`|stock,access,price,purchases RNG|candidate or none|安定ソート＋選択抽選＋購買確率、UI非依存|
|`StoreClock.tick(state)`|2 game seconds|events+new tick|expire→potential visitors→customers→checkout→day boundary順|
|`Advertising.apply_day(state,day)`|ad tier,day|events|課金・費用認識を1回のみ。再Openでは既課金を再適用しない|
|`Ledger.fold(events,from_snapshot)`|経済Event列|cash/revenue/cogs/expenses|EventIDの適用重複は拒否、数値は整数円|
|`SaveManager.encode(snapshot)`|immutable state|JSON bytes|副作用無し。schema/参照検証を事前実行|
|`SaveManager.persist(slot,bytes)`|3 slot IDs|Result|tmp生成、flush、検証、世代保存、replace。エラー時旧版保存|
|`SaveManager.decode(bytes)`|save JSON bytes|validated GameState or error|失敗時**現状態一切不変**|
|`CommandBus.execute(command)`|{command_id,kind,payload}|CommandResult|UI命令で実行。speed0でも動く。成功にのみstate revisionを進める|

## 2. CommandBus transaction の具体的順序
```text
execute(cmd):
    assert main_thread and not inside_tick
    if cmd.command_id in applied_command_ids: return ALREADY_APPLIED
    if not schema_valid(cmd): return INVALID_OPERATION
    candidate = copy_on_write(current_state)
    result = dispatch(candidate, cmd.kind, cmd.payload)
    if not result.ok: return fail_without_mutation
    assert validate_invariants(candidate)
    candidate.applied_command_ids.add(cmd.command_id)
    candidate.revision = current_state.revision + 1
    current_state = candidate               # single commit point
    emit immutable_snapshot and domain events
    return success
```
- `SAVE_GAME`、`LOAD_GAME`のファイル副作用は別Service境界で実行。**ロード時は適用済みID集合・時刻・全状態をセーブデータから復元し、ロードコマンドIDを復元済みゲームの不可逆経済イベントとして追加しない**。再ロード可能にする。
- UndoのREVERSALは元イベントを消さない。再開後のUndo履歴は空。経済/時間コマンド実行時はレイアウトUndo履歴を破棄。
- unknown command kind/payloadは副作用0、安定したエラーコード返却。単に既存モデルのプロパティをsetterで直変更しない。

## 3. 配置コマンドの実装順
```text
place(type,x,y,r):
    check business_state == SETUP
    check fixture_def exists and r in 0..3
    occupied_cells = rotated_dimensions/offsets(type,r)
    check all cells inside grid and buildable and unoccupied
    check entrance edges and passable register paths after proposed placement
    check sufficient cash for placement_cost_yen
    build new instance_id and prospective occupancy
    assert every REQUIRED register has access + entrance path, if register_count>0
    atomically commit fixture + occupancy + cash(-cost) + capex event
```
- レジ0台のSETUPで棚配置は可。レジを設置したら少なくとも1つのキュー位置と入口への経路が必要。
- 棚アクセスが現時点で0のときは、その什器設置を拒否（MVP規則）。通路が1tileでも到達可能なら警告付きで確定できる。棚の在庫が空でも設置可。
- `move`は元占有をprospective gridだけで外して同じ検証を実施し、最新revisionでcommit、移動費0。
- `remove`はSETUP/予約0で全stock segmentをbackroomへ返し、費用返金0。最後のレジ撤去はSETUPなら可。
- `access_for`は4方向ローカル辺とtile occupancyに基づき候補を求め、walkableでフィルタする。**スプライトの向きだけを変更してはいけない**。

## 4. Tickと日次イベントの実装順
```text
when realtime accumulator permits and business_state in {OPEN,CLOSING}:
    prev_time = game_time_seconds
    next_time = prev_time + 2
    expire_all_stock_and_reservations(next_time)  # deadline equals time: expiry first
    if OPEN: maybe_generate_one_potential_visitor(...)
    for customer in stable_sorted_customer_ids:
        step_customer(customer,2)
    for register in stable_sorted_register_ids:
        settle_due_checkout_one_at_a_time(...)
    if floor(prev_time / 86400) != floor(next_time / 86400):
        close_previous_day_once(...)
        if business_state in {OPEN,CLOSING}: charge_new_day_expenses_once(...)
    game_time_seconds = next_time
    game_tick += 1
    publish_snapshot()
```
- tickは**収益に関する処理順**も固定し、render loopのframe deltaはDomainへ直接渡さない。
- 当日初回STARTでは同日未請求費用を事前判定後、入金/広告/固定費とstate変更を1回のコミットで実施。前回START済ならchargeを繰り返さない。
- 新日経費不足は請求予定額を認識し、払える分だけ支払って`unpaid_cost_yen`を計上しPAYMENT_BLOCKED。ロード後に再課金しない。
- UIはdomain snapshotのchange setだけを読み、仕入/売上をレンダラ側から発生させない。

## 5. セーブの不変条件
保存・読込後の必須assert:
```text
0 <= cash_yen
0 <= physical_qty
0 <= reserved_qty <= physical_qty
reserved_qty == sum(active_reservations_by_segment)
all (sku_id, fixture_type_id, instance_id, segment_id, reservation_id,
     customer_id, transaction_id) references resolve
fixture occupancy does not overlap; each cell is within 16x12
business_state == SETUP => customers empty and reservations empty and speed=0
purchase price / lot unit cost / selling prices are integer yen
event IDs, command IDs and transaction IDs have no duplicates
daily charges are at-most-once for each day and category
stable replay reproduces same results from saved RNG states
```
- 保存形式の法的schemaは [savegame.schema.json](../schemas/savegame.schema.json)。ランタイムsemantic validatorは上記参照/算術を補完。
- **実在するPNGアセットはまだ未生成**。visual_manifestサンプルの画像名が実ファイル存在を示すと解釈しない。商品差し替え、前景/背後描画の合格は生成後に確認。

## 6. 具体的なIssue別の最初のテスト
- #3: fixture/product/schemaの有効例10/24件、無効反例（負数/容量超過/未知カテゴリ/ID重複）。
- #4: [10](10_TEST_VECTORS_AND_ACCEPTANCE.md)の投影XY/Z、4方向座標を固定値で照合。
- #6/#7: SETUPでは配置、OPEN+speed0では拒否。1×2 E側2セル、回転後S側2セル、入口/レジ到達性。
- #11/#13: FEFOとロット分割、期限切れと予約中の競合、棚qtyの負数防止。
- #14/#15: 2sec fixed-stepとLCG32; category候補順/購入確率を固定seedで検証。
- #17: 注文→補充→予約→会計、duplicate Eventで一度しか売上が増えない。
- #20: game paused save/load、OPEN+speed0、CLOSING途中、破損/旧版保存、command再送。
- #25: 上記goldenとGodot実画面/Blender4方向/固定ベンチの検証を行い、スクリーンショットと実測を残す。
