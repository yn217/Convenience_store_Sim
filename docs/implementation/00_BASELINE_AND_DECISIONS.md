# Implementation Baseline v1.0 — 凍結するMVP設計契約
更新: 2026-10-22 / 対象: Godot 4.7.2-stable + GDScript / ゲーム本体未実装

## 0. この文書の使い方
**本書および implementation/01〜05 と JSON Schema がMVP実装の規範（normative）**。既存の概念仕様は上位目的/背景として参照。
矛盾した場合の優先順:
1. docs/implementation/00_BASELINE_AND_DECISIONS.md（決定・単位・非対象）
2. docs/implementation/01_ENGINE_CONTRACT.md、02_GRID_AND_ASSET_CONTRACT.md、03_ECONOMY_AND_SIMULATION_CONTRACT.md、04_UI_SAVE_QA_CONTRACT.md、05_IMPLEMENTATION_HANDOFF.md
3. docs/schemas/*.schema.json の同名フィールド形式/必須条件
4. docs/GAME_DESIGN_SPEC.md と従来の詳細文書
5. GitHub Issue。矛盾したIssueは修正してからPRを実装。
**実装で不明な所を黙って任意決定しない**。定数はconfig定義へ集約、変更は設計差分＋回帰テスト。

## 1. 合意している製品の境界
- 2.5D、**固定30°仰角・45°方位の2:1菱形画面**、ゲーム実行時はSprite2D等の2D描画（厳密な等角投影とは異なる）。
- Godot 4.7.2-stable/GDScript。Windows向けデスクトップ、マウス/キーボード、日本語UI、単店舗、ローカル保存。
- シーン描画とDomain計算の分離。ソース3DアセットはBlender Pythonで生成し、ゲーム内はPNG RGBA/2D sprite。AIは原則架空商品パッケージ、POP。
- 16×12タイル、論理1tile=1.000m×1.000m、初期24SKU/8カテゴリ、初期10什器タイプ。4方向(0,1,2,3)回転。
- ゲーム起動は空店舗。客が使える販売棚とレジが揃うまで営業開始不可。固定入口のみ最初から存在する。
- MVP非対象: 自由回転3Dカメラ、複数店舗、リアル物流配送、店員雇用管理、実在ブランド、本格税/償却/フランチャイズ、天候/通信、ネット対戦。

## 2. 初期定数 — **v1.0暫定バランス値を実装デフォルトとして固定**
テストの想定値として実装し、後日データ/バランス調整は別Issue。
|キー|MVP default|備考|
|---|---|---|
|store_width_tiles|16|x=0..15|
|store_height_tiles|12|y=0..11|
|tile_meters|1.0|ワールド実寸|
|tile_screen_px|128×64|ゲームズーム1.0、画像sourceは2倍|
|target_window_px|1920×1080|UIは縮小対応|
|zoom_min/normal/max|0.5 / 1.0 / 2.0|連続ズーム|
|starting_cash_yen|500000|新規ゲームのみ|
|starting_reputation|50|0..100|
|store_entrance_tiles|(0,5),(0,6)|西側外壁の扉、ゲーム座標|
|initial_register_count|0|構造としてレジ設置必須ではない|
|initial_fixture_count|0|店内設備無し|
|opening_schedule|24時間営業|「営業開始」後。MVPは営業時間帯閉店なし|
|game_seconds_per_real_second|60|1×。1ゲーム日=24実時間分、4×=6分|
|simulation_step_game_seconds|2|固定ステップ。1×=30step/s、4×=120step/s|
|game_speed_options|0,1,2,4|停止、通常、高速|
|base_potential_visitors_per_day|100|需要の基準期待値。初日は待機が長い場合高速化可能|
|customer_walk_tiles_per_game_second|0.6|1タイル約1.67ゲーム秒、見た目の移動は補間|
|checkout_duration_game_seconds|30|レジ会計1客|
|max_active_customers|30|同時描画/シミュレーション上限。超過入店はlost_customerに計上|
|reputation_min/max|0/100|初期50|
|initial_ad_budget_yen_per_day|0|翌日変更適用|
|ad_budget_tiers_yen|0,1000,2000,5000,10000|倍率は1.00,1.10,1.18,1.30,1.40|
|purchase_price_min_yen|1|ゼロ/負の値付けは禁止|
|daily_fixed_cost_yen|1000|仮のゲーム内日次費用。初日は営業開始時に費用発生|
|electricity_cost_yen_per_day|各什器マスタの値を合計|停止・撤去に応じ請求は日境界で1回|
|backroom_capacity|無制限|MVPのみ|
|render_benchmark|16×12、什器20、可視客30、1920×1080、ズーム1.0、速度1×|60fpsは目標、測定前に達成と宣言しない|

### 2.1 初期店舗の幾何
- ストア内セルは全て床。建物壁は**外周edge**であり、外周セルを壁で塞がない。西側edgeの(0,5),(0,6)だけ入退店口。
- 入口は**固定構造**でプレイヤーが移動/撤去できない。外側の客生成ノードは画面上表示のみで論理店内タイルを占有しない。
- 背の高い外壁は正面視界を塞がないよう店舗西/南の壁をカットアウェイ表示する。壁当たり判定は残る。
- 什器設置/移動は営業停止中だけ。通常ビューと建設中のゲーム時計は停止する。

## 3. 用語・意味を固定
- ProductSKU: 商品種類。商品写真/容器形状と価格定義を持つ。
- StockLot: 同一SKU・仕入原価・期限を持つ物理在庫集団。ロットが棚/バックヤード間に分割される時は`lot_segment_id`を付ける。
- PhysicalQty: 物理在庫、ReservedQty: 客に予約された未決済数、AvailableQty=PhysicalQty−ReservedQty。
- StoreCash: 現金残高。収益や在庫評価額と混同しない。
- SalesRevenue: 会計確定済みの売上、COGS: 販売品の仕入原価、GrossProfit=SalesRevenue−COGS。
- OperatingProfit: GrossProfit−WastageCost−AdCost−FixtureElectricity−FixedCosts。
- CapitalExpenditure: 什器購入費（損益計算から除き、現金から控除）。
- StoreReputation: 0..100 のプレイ評価。単日の需要係数を介して効果を発揮する。
- 日付境界は**ゲーム時刻の00:00**。非営業時には経済/顧客シミュレーション時刻を停止、配置操作はできる。

## 4. 実装時の未確定を無くす運用
- 例示の数値を上記のデフォルトとして扱い、全て`res://data/balance/mvp_v1.json`相当に置く。
- 仕様のうち視覚主観（ガラスの反射量等）は数値化できないため、**3種の基準アセットと目視承認**を唯一の残る制作判断とする。
- 正式アートの品質、難易度の面白さ、ハードウェア性能は実装後に測定・調整が必要であり、仕様完成と実装検証完了は別。
- この契約はテストで定量化可能な工程を対象に「実装準備完了」を目指すもので、ゲームを作成済みと意味しない。

## 5. 2026-10-23 契約補完
- 初期エンジン版は**Godot 4.7.2-stable**に固定（4.8 betaを採用しない）。変更する場合はバージョン更新Issueと検証を要求。
- `business_state`とゲーム速度は別状態。[08 営業/停止/コマンド契約](08_RUNTIME_STATE_AND_COMMANDS.md)の`SETUP/OPEN/CLOSING/PAYMENT_BLOCKED`を採用。
- [09 乱数・来店・価格・会計・保存契約](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)が決定論的アルゴリズムと入力順の正本。
