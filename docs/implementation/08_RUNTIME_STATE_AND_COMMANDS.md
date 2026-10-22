# Runtime State / Commands — 実装契約 v1.0
**Normative**: 本仕様は `01_ENGINE_CONTRACT`, `03_ECONOMY_AND_SIMULATION_CONTRACT`, `04_UI_SAVE_QA_CONTRACT` の状態遷移の曖昧さを解消する。2026-10-23。

## 1. 2軸のゲーム状態
時間停止（speed_setting）と営業状態（business_state）を混同しない。

| business_state | 意味 | 新規来店 | 客の買物/会計 | 建設変更 |
|---|---|---|---|---|
| `SETUP` | 開店前/完全閉店、店内客0、予約0 | なし | なし | 可能 |
| `OPEN` | 営業中 | ゲーム時計進行時だけ発生 | 時計が進めば処理 | 不可 |
| `CLOSING` | 閉店要求後の客の退出処理 | なし | 時計が進めば処理 | 不可 |
| `PAYMENT_BLOCKED` | 費用支払不能 | なし | なし（店内客・予約は保持） | 不可 |

- `speed_setting`は`0,1,2,4`。**0は画面・シミュレーションの一時停止のみ**。OPEN+speed0は営業中の一時停止であり、建設許可ではない。Pキーは speed0 と前回の非ゼロ速度を切り替えるだけ。
- `SETUP`はシミュレーション時計停止（速度は0へ正規化）。プレイヤーは建設・移動・撤去・注文・棚補充ができる。
- `start_business()`: SETUP → OPEN, speed1 を設定。少なくともレジ1、商品入った有効棚1、入口→レジ/棚アクセス経路、現金で当日費用を支払えること。**当日の広告・固定費・設備電気代は既課金なら再請求しない**。
- `request_close_business()`: OPEN/一時停止中でも CLOSING に遷移。speed0なら直前の非ゼロ速度で再開（なければ1）。新規入店は禁止、既存客の予約は保持し、店内客が0かつ予約0になったtickでSETUPへ。閉店中に終業日次締めを行わず、日付境界でのみ締める。
- `PAYMENT_BLOCKED`: 支払不能額`unpaid_cost_yen`と費用認識は台帳に保存し、利用者にロード/新規ゲーム案内。MVPでは自動借入/資金付与をしない。将来救済ルールを作る場合は別Issue。
- `business_state`が`SETUP`以外なら設置/撤去/Undoは禁止。営業中の一時停止と閉店は別操作としてUIに表示。
- タイトル画面・ロード等で`speed_setting=0`を保持した`OPEN`状態を復元しても、`SETUP`へ勝手に戻さない。

### 1.1 コマンドをいつ実行するか
**UIコマンドは固定tickループ外でも処理できる**。シミュレーション停止中に建設ができない矛盾を防止。
- ユーザー操作は main-thread `CommandBus`のFIFOへ入り、UIイベント処理終了後の安全な**command phase**で、到着順に処理する。
- `speed_setting=0`でも command phase は毎画面更新で実行可能。ただしDomain clockは進めない。複数コマンドは`revision`を1つずつ進め、毎回最新状態を検証。
- tick実行中はcommandを割り込ませない。tick終了後のcommand phaseで処理し、読み書き一貫性を保持。
- `start_business`と`request_close_business`は一意のcommand_idを持つ。同じIDを再送したら以前の結果を返し、資金/状態変化を重複させない。
- UIプレビューは`validate_placement(proposal, snapshot_revision)`を呼ぶだけで状態変更しない。確定は常に最新revisionで再検証。

## 2. Command API（GDScriptインターフェース）
`CommandResult {ok:bool, code:StringName, message_key:StringName, event_ids:Array[String], new_revision:int}` とし、失敗は`ok=false`, `event_ids=[]`, `new_revision=old_revision`。
アプリケーション層は`GameCommands.execute(command:Dictionary) -> CommandResult`を公開。全commandに`command_id:String`と`kind:StringName`必須。payloadを以下の通り固定。

|kind|必須payload|成功イベント|失敗を起こし得る条件|
|---|---|---|---|
|PLACE_FIXTURE|type_id:String, x:int, y:int, rotation:int|FIXTURE_PLACED + FIXTURE_PURCHASE|範囲外、衝突、現金不足、経路塞ぎ|
|MOVE_FIXTURE|instance_id:String, x:int, y:int, rotation:int|FIXTURE_MOVED|OPEN、予約中、衝突、経路塞ぎ|
|REMOVE_FIXTURE|instance_id:String|FIXTURE_REMOVED|OPEN、予約中、レジ/入口塞ぎ|
|ORDER_STOCK|sku_id:String, qty:int (1..9999)|STOCK_PURCHASED|残高不足、未知SKU|
|RESTOCK|instance_id:String, slot_id:String, sku_id:String, qty:int|STOCK_MOVED|容量/カテゴリ/利用可能在庫不足|
|SET_PRICE|sku_id:String, price_yen:int (>=1)|SKU_PRICE_CHANGED|SKU不在、非整数|
|SET_NEXT_DAY_AD|tier_yen:int|AD_BUDGET_SCHEDULED|列挙額以外|
|START_BUSINESS|なし|BUSINESS_STARTED|レジ/在庫/棚/動線不足・費用不足|
|REQUEST_CLOSE|なし|BUSINESS_CLOSING_REQUESTED|SETUP時はNOOP、PAYMENT_BLOCKED不可|
|SET_SPEED|speed:int ∈{0,1,2,4}|SPEED_CHANGED|SETUP時に非ゼロ不可|
|UNDO_LAYOUT|なし|REVERSAL または LAYOUT_UNDONE|編集履歴無し/非SETUP|
|REDO_LAYOUT|なし|再適用イベント|資金/occupancy条件変化|
|SAVE_GAME|slot_id:slot_1..3|なし|ファイル失敗/検証失敗|
|LOAD_GAME|slot_id:slot_1..3|なし|未知版/破損/参照不整合|

- `CommandBus`は`command_id`で冪等。ロードして同command IDが存在すれば重複適用しない。不可逆commandは再送防止情報を保持。
- 経済的な差分（現金・在庫・予約・売上）は**一つのcommit unit**で適用し、途中失敗は全体ロールバック。Godotのメインスレッド直列でも部分更新を禁止。
- `REMOVE_FIXTURE`は予約0かつSETUP時のみ。棚在庫全てをバックヤードへ戻し、撤去返金0。レジ0台になってもSETUPは合法。
- `SET_NEXT_DAY_AD`は翌日請求予約の変更であり、変更した日に現金を引かない。
- クラス名・引数型はIssue #2でコード化するが、公開command payloadキーを無断変更しない。

## 3. UI状態との対応
UIの`observe/place/move/inspect/modal`は**UI相互排他の状態**で、上記`business_state`とは別。
- PLACE/MOVEモードへ入るのは`SETUP`のみ。OPEN+speed0では入れず「営業停止が必要」と表示。
- EscはUI操作をキャンセルするが、予約/客/経営を変更しない。
- モーダル中にロードするとUI stateをOBSERVEに戻し、古い什器参照を捨てる。
- 価格変更・広告予約・注文の可否は営業中でもDomainルールに従い許可する（建設とは区別）。棚補充はMVPではSETUP時のみ。
- キューのショートカットやHUD操作が下のワールドへ透過しない。
- `P`は停止/再開、`Space+Drag`はパン、Space単独は停止にしない。

## 4. テスト
1. SETUPでspeed0でもPLACEが実行され、time_secは進まない。
2. OPEN→P(0)→PLACE は NOT_IN_SETUP で拒否、既存予約は残る。
3. OPEN→REQUEST_CLOSE→CLOSING→客0→SETUPで初めて配置可能。
4. CLOSEと購入予約の競合、SAVE直後のLOADで状態・予約・費用が維持。
5. SETUP→START同日→CLOSE→START同日で固定費/広告請求が二重にならない。
6. 同command_id再送、同transaction_id再送でも現金/棚在庫が二重変化しない。
7. pause画面操作時にUIボタン押下が下のタイル配置を発生させない。

## 5. Command ID保存の必須契約
- `applied_command_ids`をsavegameに永続化する。保存/復元後に同じ不可逆command_idを受けても実行しない（同じ結果またはALREADY_APPLIEDを返す）。
- `applied_event_ids`は台帳の重複防止、`applied_command_ids`はUI/CommandBus入力の再送防止として**役割を分ける**。
- 受け入れ: ORDER_STOCKを一度成功→SAVE→LOAD→同command_id再送で在庫/現金不変、新しいcommand_idなら再発注できる。
