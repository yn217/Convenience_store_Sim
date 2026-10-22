# 実装前の固定テスト入力・期待出力 v1.0
2026-10-23。MVPの「コードの存在」ではなく、別々の担当が**同じ観測結果**を出せるか判定する正本。
想定: [00](00_BASELINE_AND_DECISIONS.md)、[02](02_GRID_AND_ASSET_CONTRACT.md)、[08](08_RUNTIME_STATE_AND_COMMANDS.md)、[09](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)。

## A. タイル投影と回転のゴールデン値
画面原点 (1000,200), zoom1:
|入力|screen_u|screen_v|
|---|---:|---:|
|cell (0,0),z0|1000|200|
|cell (1,0),z0|1064|232|
|cell (0,1),z0|936|232|
|cell (2,3),z0|936|360|
|cell (0,0),z1m|1000|121.61632823|

1×2, r0, origin(4,5): occupancy (4,5),(4,6); front E のアクセス候補は (5,5),(5,6)。
r1(90°), origin(4,5): occupancy (4,5),(5,5); front S のアクセス候補は (4,6),(5,6)。
r2(180°), origin(4,5): occupancy (4,5),(4,6); front W のアクセス候補は (3,5),(3,6)。
r3(270°), origin(4,5): occupancy (4,5),(5,5); front N のアクセス候補は (4,4),(5,4)。
検証: 4回転して元向きに戻る、全占有は整数タイル・他設備と重複しない、見た目の基準縮尺は変えない。

## B. 寸法・アート校正
- 1tile=1.0m, source diamond 256×128、Blender投影 +X 1m=(+128,+64)、+Y1m=(−128,+64)、+Z1m=(0,−156.76734354) source px。
- 1×2冷蔵庫 = 幅0.92/奥行1.92/高さ2.00m、front=E。最大メッシュbbox幅 <=0.92m、奥行<=1.92m、高さ2±0.01m。
- 2×2アイス=1.92×1.92×1.00m、front N/E/S/W。PNGキャンバスの幅/高さが冷蔵ケースと異なってもPASS。**個別scale調整したらFAIL**。
- 4方向それぞれ全描画レイヤーがcrop/anchor/canvasを共有。接地ズレがzoom1で1 screen px以内、source校正X/Y各±1px、Z±2px。
- 商品/画像はまだないのでこの項目は**実装後**にPASS/FAILを記録する。ドキュメントのサンプルPNG参照だけでPASSにはしない。

## C. 時間停止と営業停止
|操作|初期|期待結果|
|---|---|---|
|PLACE棚|business=SETUP,speed=0,cash500000|成功、ゲーム時刻不変、現金−設備購入額|
|START|SETUP、レジなし|失敗、現金不変|
|START|SETUP、レジ1、到達可棚1、棚在庫1|成功、OPEN、speed1、当日費用1回|
|SET_SPEED=0|OPEN|OPENのまま時間停止|
|PLACE棚|OPEN+speed0|拒否、現金/在庫/配置不変|
|REQUEST_CLOSE|OPEN+顧客1予約1|CLOSING、入店なし、顧客と予約を保持|
|顧客退出|CLOSING+顧客0予約0|SETUP、speed0|
|START|当日再開（同日の費用課金済）|当日固定費/広告の追加請求なし|

UI commandは時計停止中でも処理される（tick処理だけ止める）。一度のUndoで設備購入の支出と棚占有が元に戻るが、発注後のCtrl+Zでは元に戻らない。

## D. 仕入れ・在庫・会計
初期現金500000円。初期レジ等の設備購入/固定費を**このケースに含めない**独立Domainテスト:
1. 緑茶SKU cost75円 ×10仕入 → cash499250、backroom10、棚0、revenue0、COGS0。
2. 6個補充→backroom4、棚6、cash499250。
3. 150円への売価変更→予約前ならこの額を適用。1個予約→physical6/reserved1/available5。
4. その1個を会計→physical5/reserved0、revenue150、COGS75、cash499400、gross75。
5. 同じtransaction ID再送→変化0。別の顧客が同じ1個を二重予約できない。
6. 期限付き別Lot単価100円×3個を仕入→そのLotのみ期限失効、wastage300、COGSは増やさずcashも失効時には変化しない。
7. 注文`command_id`をSAVE→LOAD後に再送→現金・在庫変化0。`applied_command_ids`と`applied_event_ids`は異なるキー。
8. SAVE→LOAD後、active reservationの物理数と予約合計が一致し、customer ID参照が成立。
9. 経済指標: `gross_profit=Σrevenue−Σcogs`、`operating_profit=gross−wastage−ad−fixed−electricity`、`cash`は仕入/設備/広告支払を別集計して計算。

## E. RNGと客数
- LCG32(seed=1)最初のstate: 1015568748。
- hour raw weight24時間分を平均1へ正規化し、全時刻の合計24.0±1e-9。
- category_preference全て1.0、fixture appeal1.0、stocked_category_countは到達可能な陳列カテゴリのdistinct数。
- 値札default_price=150、設定300の`price_factor=0.5`、`purchase_probability=0.40`。同商品を100に値下げしたとき`price_factor=1.5`、`purchase_probability=0.95`（clamp）。
- 同じゲームtick数・同じRNG state・同じコマンドID/順序なら売上履歴・来店数・現金・評判が一致する。
- ビジュアル補間やFPSが増えてもarrivals/purchasesのstateが変わらない。

## F. セーブ失敗
- unknown schema_version、未知fixture_type、reserved_qty≠予約合計、重複transaction ID、破損JSON、負のphysical_qty → LOAD拒否、現ゲーム状態不変。
- temp書込失敗・rename失敗では既存slotの直近成功世代へ戻せること。
- OPEN+speed0をSAVE→LOADしてもOPEN+speed0。CLOSING+客/予約有りはその状態を維持。
- SETUP時にactive customer/reservationが残っている保存データは破損として拒否する。

## G. 完了の基準
- **仕様段階**: 上記入力/期待値とスキーマ、参照文書が整合し、曖昧な変数を実装者ごとの判断に委ねない。
- **コード段階**: Unit, headless, Scene screenshot/manual, crash-safe save, 全10什器の4方向画像投影校正、固定条件の性能試験。
- **リリース段階**: 初回5分チュートリアル→日次決算までプレイヤー操作で完遂。未完了の重要欠陥なし。
