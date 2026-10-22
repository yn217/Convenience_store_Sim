# Deterministic Simulation / Save / Edge Cases v1.0
2026-10-23。既存 [03](03_ECONOMY_AND_SIMULATION_CONTRACT.md)・[04](04_UI_SAVE_QA_CONTRACT.md) の「実装者が別解を取りうる部分」を規範化。

## 1. 固定stepとRNG（再現可能性契約）
- Godot Engine **4.7.2-stable** を初期固定版とする。GDScript、Windows standard build。4.8 beta版は採用しない。
- 1 game step = 2 game seconds。speed0停止、それ以外 real delta を`accumulator += delta * speed * 60`し、`while accumulator >= 2`でstep進行・2減算。速度変更後もaccumulator残余を保持。長いフレームで処理できなければstep残を保持（**skipしない**）。
- この固定stepは経済・来店の**演算順と回数**を定める。描画は補間。性能不足で実時間より遅れてもイベントを飛ばして帳尻を合わせない。
- 乱数の実装互換を固定するため、ゲームDomain用にはGodotのglobal RNGを呼ばず、**LCG32** を独自実装:
```text
state: integer in [0, 4294967295]
next() => state = (1664525 * state + 1013904223) % 4294967296
uniform_0_1() => next() / 4294967296.0
```
  32bit stateの更新で64bit整数演算の範囲内。個々の固定seedは`arrivals=1234`,`purchases=5678`,`visuals=9012`（empty save例）。乱数を1回消費する場所を統合テストで固定する。UI表示/アートで`arrivals`と`purchases`を消費しない。
- 乱数seed=0でも正当。異なる描画FPS、実時間speed1/4でも**同じtick数・同じコマンド順→同じDomainイベントと会計結果**を満たす。

## 2. 顧客来店分布
- base=100 potential visits/day。ゲーム1日=43200steps。`hour_weights`: h0-5=0.5, h6-10=1.25, h11-13=1.75, h14-16=1.0, h17-20=1.5, h21-23=0.75。正規化は`normalized[h] = raw[h] / (sum(raw[0..23])/24)`で行う。
- 1stepの確率: `p=clamp(100*normalized[hour]*ad_multiplier*reputation_multiplier*assortment_multiplier/43200,0,1)`。これを1stepにつき**arrivals RNG 1回だけ**抽選。テストで`p=1`でも1回消費する。
- `reputation_multiplier=0.75+0.005*reputation` (reputation 0..100)。`assortment_multiplier=0.75+0.25*(stocked_categories/8)`、stocked_categoriesは**アクセス可能な什器に陳列されたqty>0のdistinctカテゴリ数**、0..8。
- ad_multiplierは当日確定した広告ティア（0/1000/2000/5000/10000→1/1.1/1.18/1.3/1.4）、同日の変更は翌日まで適用しない。
- potential visitorが抽選されても営業状態!=OPEN、上限30、入口アクセス不可なら実入店させず**来店希望数だけ計上**（営業停止中は抽選自体を実行しない）。数量の命名をpotential、entered、purchased、lostに統一。
- 開店中の0在庫は開店条件とは独立し、棚売切れ後もOPENを維持、顧客は品切れとして退出できる。

## 3. 商品選択と価格
- MVP顧客は1回来店で最大1SKU/1個。基準価格・在庫ありのときの**基礎購買確率0.80**（基準非購買率0.20）。**候補重みだけを価格で変えても総販売量は変わらない**ため、購入確率にも価格係数を掛ける。
- `category_preference`はMVPでは**全8カテゴリで1.0**（後からバランスJSONのカテゴリごと値へ差し替え可）。
- `fixture_appeal_factor`はMVPでは全10種で1.0。ProductDefの`demand_weight`は初期マスタで1.0。
- `price_factor=clamp(reference_sell_price/current_sell_price,0.3,2.0)`。売価1円以上。stock outなら重み0。
- `weight(sku,fixture)=availability(0/1)*accessibility(0/1)*category_preference*fixture_appeal_factor*sku.demand_weight*price_factor`。
- 同じSKUが複数の什器にある場合、候補`(sku_id,fixture_instance_id)`として別々に列挙。候補を`sku_id`→`fixture_instance_id`の辞書順で安定整列し、その相対重みから**purchases RNG 1回**の累積値抽選。予約に失敗したら品切れ/競合扱いで最大2回再選択。
- 候補があるとき、まず`purchases RNG 1回`で上記重みの候補SKU/什器を選択し、`purchases RNG 1回`で`purchase_probability=clamp(0.80 * price_factor(selected_sku),0.05,0.95)`を判定。失敗なら購入0で退出。候補ゼロのときは`purchases RNG 1回`を消費して退出。価格を上げたときに**SKU選択割合だけでなく、実際の購買率も下がる**。
- 客の`SELECT_SHELF`で価格を評価し、棚まで移動して予約可能か再検査。予約時に売価/仕入原価をsnapshotし、値札変更が会計額を書き換えない。

## 4. 顧客待機と会計
- `ACCESS_TILE`は什器ローカルの辺/回転から生成。A*探索は4近傍、歩行コスト1、同距離タイブレークは**北→東→南→西**の順。到達する棚アクセス候補は (distance, y, x) の昇順で選択する。
- レジの顧客サービス位置はE長辺に接する2セル（回転後は対応するface）から、入口到達可能な候補を探す。各候補について**什器front法線方向へ直線3タイル（サービスセルを含め最大3枠）**の連続walkable数を計算し、最大枠数→距離最短→(y,x)最小の順に一意選択。途中で壁/什器があればそこで列を打ち切る。0枠なら営業不可。回転0/1/2/3ではE/S/W/N法線で計算。満員時は待機timeout(120ゲーム秒)後に退出。
- 1レジ/人は30ゲーム秒。停止中は会計時間減少なし。期限切れが会計確定の同tickにあれば**先に失効予約を解除**し、販売0。ゼロ点なら無会計退出。
- 同じ棚のphysical_qty=1の2客競合ではavailable=1から予約できる1客のみ。単一コミット順でなく公正な同着順はMVPで要求せず、**stable customer_idの昇順**で同tickの更新を処理。
- レジ会計/レジ待機にいる客が既に入手予約した商品を持つ間は、営業者は什器の移動不可（OPEN/CLOSINGは全面禁止）。
- `request_close_business`後のCLOSINGは新規来店なし。買物中の客は会計を終え、客0でSETUPへ。販売価格や広告の予約変更はOPEN/CLOSING中も許可するが、什器の撤去/棚補充はSETUPのみ。

## 5. 収支、負債、広告・日境界
- ロット原価はpurchase時snapshot。売上原価は会計確定時だけ計上。発注支出を粗利/営業利益から二重控除しない。
- `event_id = day_index + ":" + event_kind`（day start/close/advertisement/fixed/electricity）を永久に記録し、save/loadやre-openで再請求しない。個別販売は unique transaction IDを使う。
- D日00:00にDの初回OPENが発生する場合、その日初回営業開始時に**当日広告費・固定費・電気代の請求処理**を1回だけ実行する（電気代は当日の有効設備から算出）。D+1日00:00でD日分報告を閉じ、OPEN/CLOSINGが続くなら新日の費用を課金する。SETUPで時間が止まる場合は新日まで進まない。
- **開店要求時の資金不足**：事前に同日未請求の広告・固定費・設備電気代を検証し、残高不足なら`INSUFFICIENT_CASH`で拒否する。**料金・未払額・stateは変えない**（08の契約を優先）。**営業中の新日付課金時の不足**：費用認識と現金支払を分離し、その時点の現金で払える部分を支払い、残額を`unpaid_cost_yen`へ積み上げて費用を1回だけ計上、stateを`PAYMENT_BLOCKED`にする。現金は負数にしない。再試行しても同日分を重複認識しない。MVPには返済コマンドを設けないため、UIから直近成功セーブ/新規ゲームへ戻す。
- 設備投資/設置UndoのREVERSALは本体の現金支出と帳尻を合わせる、ただし粗利/営業損益には算入しない。
- 日次レポートの`gross_profit_yen`と`operating_profit_yen`は負数もありえる。`unpaid_cost_yen`は`cash_yen`とは別項目。

## 6. セーブ処理
- v1の保存対象は business_state ∈ {SETUP, OPEN, CLOSING, PAYMENT_BLOCKED}、speed_setting (0,1,2,4)、および`rng_states`、全reservation、customer phase/route/remaining time、stock segment、price overrides、ledger、applied_event_ids、day reports。
- 保存はコマンドphaseと固定tick両方が終わった安全境界。JSON読み込みと参照/数量/経済不変条件の検査は**仮GameState**に対して実施。現状態への部分反映は禁止。
- crash-safe: 一時ファイルと旧保存バックアップを使う。可能なら同じファイルシステムでatomic rename; OS依存でatomicityを保証できない場合、**旧セーブに戻せる2世代の世代管理**をMVPで採用。
- `savegame.schema.json`は最低限の形/必須フィールド。別途 semantic invariant を検査: `reserved_qty==sum(active reservation.qty)`、全SKU/fixture参照存在、重複IDなし、レジと店状態整合、日付費用ID一意、帳尻。
- 負の金額, 負の在庫, 未知バージョン, 不明参照, 客と予約不整合は**読み込み拒否、現ゲーム状態を変えない**。
- 空店舗の例は SETUP+speed0、現金50万円、レジ0、在庫0、初期日開始マーカー未請求。

## 7. 最低限の固定ゴールデンテスト
1. PRNG: seed=1に対し、次のstateは1015568748。
2. hour_weightを24h平均1に正規化、加算したweightが24.0±1e-9。
3. 同一seed/同じtickとコマンド→同じ来店・販売トランザクション一覧（ビジュアル描画回数を変えても不変）。
4. OPEN+speed0で新しい配置コマンドが失敗して、顧客予約が維持される。
5. レジ0のSETUPは棚設置可能、STARTは失敗。レジと棚/商品/アクセスが揃うとSTART可能。
6. 一日内にCLOSE→OPENを繰り返しても広告費/固定費の一日分は1回。
7. 1個のstockを2人が同時予約→1成功、同ID checkout2回→1販売。
8. 期限切れ商品が同stepでcheckoutされようとしても売上0、廃棄が1回。
9. 破損save/未対応schemaで状態0変更、元保存は復元可能。

## 8. コマンド再送と保存の追加不変条件
- 永続化対象に`applied_command_ids`を含める。イベント冪等性とコマンド再送の冪等性の両方を検査する。
- `rng_states`の値はLCG32 stateの0..4294967295。保存から戻すときにエンジンのグローバル乱数で再seedしない。
