# Inventory / Customers / Economy Algorithm Contract v1.0
参照: [00_BASELINE](00_BASELINE_AND_DECISIONS.md), [01_ENGINE](01_ENGINE_CONTRACT.md)。

## A. 時計と1回の固定step
- `game_time_seconds`は整数のエポック相対秒。日=86400秒、開店日に0から開始。1 real second=60 game seconds at 1x。
- `step_game_seconds=2`。1xは30step/s、2xは60step/s、4xは120step/s。ゲーム表示フレームのdeltaをそのまま経済・客AIに掛けない。
- render時間が不足してstepが遅れた場合、イベントを間引かず未処理stepとして残し、負荷警告を記録。**処理不足によりゲーム速度が遅くなっても決済・広告イベントをスキップしない。**
- `paused`時はstepを進めない。翌ゲーム日00:00のイベント順は、前日23:59:59までの会計→日次集計確定→新日広告/固定費請求→新日客発生。

## B. 1 stepの処理順（**この順番はテストの前提**）
1. 受け取ったUIコマンドをevent ID付で検証し適用（建設はpause中のみ）。
2. 予約タイムアウト/期限切れの棚・バックヤード在庫を処理し、先に予約解除・購入予定から除外してから廃棄。
3. 有効在庫とアクセス可能売場のsnapshotを生成。
4. 来店希望を生成、入口混雑/上限なら失客に計上。
5. 客の経路、棚選択、移動、予約、行列入り、離脱を更新。
6. レジ会計を確定。会計が一意の売上イベントを発生。
7. ゲーム日時境界を進め、経済イベント（締め/翌日広告/固定費）を処理。
8. immutable read-model/snapshotをPresenterへ発行。

## C. 在庫/仕入/数量トランザクション
- `stock_segments[segment_id]`: SKU、元lot_id、unit_purchase_cost_yen、expiration_at_sec or null、physical_qty >=0、location {BACKROOM or (fixture_id,slot_id)}。
- 客の`reservation`はsegmentへのID参照であり、`reserved_qty=Σvalid reservation.qty`。available=physical-reserved。
- 仕入時: `qty`は1..9999、支出=qty*unit_cost。残高>=支出なら現金を1回減算してbackroomにstock segment追加。失敗時は変更無し。
- 補充時: 対応カテゴリ、SKU slot定義、残容量を検査。複数segmentをFEFO順に移動する。移動先segmentは**新segment_id**で元lot_idと原価/期限を維持し、元segmentの数量を減らす。予約中のsegmentは移動不可。
- 棚slot容量は`sum(slot_units*physical_qty)<=capacity_units`。1slot=1SKU、棚全体の`sum`も超えてはならない。スロット数はマスタ定義、容量不足時は補充全体拒否（部分成功を禁止）。
- 撤去はpausedかつreservation無き什器限定。棚stockをbackroomへ移動し、fixture占有を解除する。返金0円（デフォルト）。
- 期限切れ時刻`time>=expiration_at`で該当segmentの未販売全数廃棄（予約を先に解除）。`wastage_cost_yen = physical_qty*unit_cost_yen`を一度だけ費用へ。負数不可。
- sku/categoryはcatalogから検査、店内display用visual slotと保有数量は異なる。

## D. 客の行動ステートマシン
```text
SPAWN (入口)
 → SELECT_SHELF (需要から買うSKU候補)
 → WALK_TO_ACCESS (A* route)
 → INSPECT (選択/予約)
 → WALK_TO_REGISTER
 → QUEUE (列に並ぶ)
 → CHECKOUT (30ゲーム秒/人)
 → EXIT (外扉)
```
- 達成不能・品切れ→他の選択候補最大2回→無ければ買わず退出。
- 一度の来店につき**1SKU×1個**の購入をMVP基準とする（商品カート/複数商品はMVP後）。複数予約対応のdata modelは将来拡張のため残す。
- `walk_speed_tiles_per_game_sec=0.6`、4方向A*、交差不可セルを使う。通常経路はグリッドを辿い、座標は演出上なめらかに補間。客同士の微細な衝突回避はMVP非対象、レジ待ち行列は専用ステートで排他。
- レジ1台の会計時間30ゲーム秒。Queueが埋まっていたら最大120ゲーム秒待ってから離脱。予約品を放棄し売上無し。
- 店内可視顧客上限30、上限超過の潜在客は失客として計上。カメラや描画LODで購買モデルを変えない。

## E. 予約→決済の原子プロトコル
```text
reserve(segment_id,customer_id,qty=1)
  pre: available>=1, not expired, selling_price>=1
  post: new reservation with price snapshot/cost snapshot; physical unchanged

checkout(transaction_id, reservation_id)
  pre: unprocessed transaction_id, reservation valid, lot not expired, register active
  commit atomically:
    physical_qty -= qty
    remove reservation
    ledger.revenue += sell_price_snapshot*qty
    ledger.cogs += cost_price_snapshot*qty
    ledger.cash += sell_price_snapshot*qty
    mark transaction_id as applied
  on any failure: commit nothing, release reservation on customer cancellation only
```
- 全ての経済イベントは`event_id`による冪等性を要求し、二度実行しても数量・現金・費用を増減させない。ゲームがシングルスレッドでも重複イベント防止を実装。
- 価格変更後も予約時売価に従う（予約時点で値札価格固定）。原価は仕入ロットの原価。仕入元のマスタ原価変更で既存在庫の原価を変えない。
- 期限切れは同tickの会計より優先する。棚物理数1に客2人の予約が成立することを禁止。

## F. 需要・客数・価格・評判（MVPの決定可能な計算）
- 基礎potential visitors=100/日。1日の86400秒を2秒stepで43200slot。
- 時間帯重み`hour_weights`（0-5時=0.5、6-10=1.25、11-13=1.75、14-16=1.0、17-20=1.5、21-23=0.75）をhour単位に展開し、24時間の**平均が1**になるよう正規化。
- `traffic_multiplier = ad_factor * (0.75 + 0.005*reputation) * (0.75+0.25*stocked_category_count/8)`。
- 各step potential event確率`p = clamp(100 * traffic_multiplier * normalized_hour_weight / 43200, 0, 1)`。seedを固定したPRNGで`random_uniform()<p`。1step最大来店希望1人（MVP）。
- `reputation`初期50。日次更新`delta = clamp(round(2*(purchase_rate-0.5)-2*queue_abandon_rate - stockout_rate), -3,+3)`、次日reputationを0〜100にclamp。率の分母0は0とする。基礎需要とは別の表示指標。
- SKU選択重み`category_preference * price_factor * display_appeal * accessibility`。stock available=0 または到達不能→0。価格係数`clamp((reference_sell_price / current_sell_price)^1.0,0.3,2.0)`。referenceはProductDefのdefault_sell_price。display_appealはfixture appeal_factor×ProductDef demand_weight（それぞれ1を標準）、accessibilityは到達可能なら1、不可なら0。相対重みから1SKUを乱数抽選。
- 客の購買しない確率は**0.20**の基準値（仮のゲーム調整値）。候補抽選に失敗した場合は0件購入で退出。閉店/買物導線なしなら営業開始できない。
- ad tier →倍率: (0,1.0),(1000,1.10),(2000,1.18),(5000,1.30),(10000,1.40)。翌日から適用、当日の請求1回。今日の予算変更は現金を即減らさない。
- 時間帯/客数/売上はランダムでも**same seed + same orders + same simulation ticks => same results**。来店/需要/アートのRNGは分離。

## G. 会計/日次締め・資金不足
- `revenue_yen=Σpay_confirmed(sell*qty)`, `cogs_yen=Σsold(unit_cost*qty)`; `gross_profit=revenue-cogs`。
- `operating_profit=gross_profit - wastage - ad - electricity - fixed_cost`（人件費はMVPでは0円）。
- `cash = initial_cash + sales_in - stock_orders_out - fixture_capex_out - ad_out - electricity_out - fixed_cost_out`。
- 設備購入は現金支出、営業損益から引かない。資金は常に>=0。費用を払えない場合は営業を停止して`PAYMENT_BLOCKED`を記録し、負債を隠さず表示（MVPの損益報告には未払額を別記）。ゲームオーバーなし。
- Fixed cost: 1ゲーム日あたり1000円。電気代は現時点有効な什器のマスタ額を日ごと合計し、日境界で1回請求。
- **日付Dの処理**: D日00:00で予算を適用し広告費/固定費を課金→営業/販売→D+1日00:00でDのレポートを締め、D+1日の費用を課金。新規プレイ時は初回営業開始まで費用請求しない。
- 売上件数と来店数、購入顧客数、逸失客数を別集計。0除算時は「—」。
- 費用請求・日次締めは`event_id=day_index:event_type`を使い二重適用を禁止。
- 売価やbalance変更が過去確定売上を変えない。

## H. 外部/内部境界テスト
1. 100円×10個仕入 → cash −1000, backroom +10、費用/COGS 0。
2. 5個を棚に補充 → backroom5, shelf5, cash変動0。
3. 150円で3個売る → revenue450/cogs300/gross150/cash +450、棚2。
4. 残り2個が期限切れ → wastage200, cash変動0, gross150, operating−50（広告/固定費なし）。
5. 同IDでcheckout2回 → 1回分のみ反映。
6. stock physical1 を同時2予約 → 成功1、失敗1。
7. 広告変更5000→1000同日に実施 → 翌日1000だけ適用、当日広告費1回。
8. 初期レジ0台で合法棚配置は成功、営業開始は`MISSING_REGISTER`相当の理由で拒否。
9. 4×速度と1×速度で同じstep数を進めると同じ結果。
