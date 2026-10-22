# 全18画面・実装詳細仕様 v1.0
更新日: 2026-10-23 / ターゲット: Godot 4.7.2 / 日本語 / Windows / 1920×1080 / リアル寄り2.5D。
**本書は画面・操作・表示状態の規範。** Gameplayルールの正本は `docs/implementation/00〜16` および `docs/schemas`。個別SVGは構図の例であり仕様の数値・状態を上書きしない。

## 0. 画面アーキテクチャ
- `Shell`: HUD（高さ64px）、左パネル（280px）、中央isometric viewport、右インスペクタ（320px）、下部時間・ショートカット。1920×1080を基準とし、狭い横幅時は左右パネルを折りたたむ。
- `Scene`は実際の画面遷移、`Panel`はShellの一部、`Modal`は明示した操作確定/キャンセル、`Banner`は非阻害の情報表示。**各画面を独立したGodot Sceneにしない**。
- モーダルは`ModalRoot`の子、UI入力はmodal/Controlで消費しViewportへ漏らさない。z-indexで透明な巨大Controlを重ねて操作領域を作らない。
- ゲーム時計（speed 0/1/2/4）と営業状態（SETUP/OPEN/CLOSING/PAYMENT_BLOCKED）は別。**OPEN+speed0は建設不可**。閉店後SETUPで建設可能。
- 値は`GameSnapshot`からread-only取得し、コマンドは`GameCommandBus`だけが発行。数値の二重管理禁止。ゲーム背景の描画が遅延しても財布/在庫はcommand/tickでのみ変わる。
- 色/文字サイズは[UI_DESIGN_TOKENS](UI_DESIGN_TOKENS.md)のGodot Themeへ移植。成功/失敗は色・文字・アイコンの3要素で示す。reduce_motionでも情報を消さない。
- SVG寸法は1600×900の構図参考。実装の寸法やペルソナ寸法には[02_GRID_AND_ASSET_CONTRACT](../implementation/02_GRID_AND_ASSET_CONTRACT.md)の1tile=1m、zoom1→128×64pxを使用する。**画面SVGに描いた小さい菱形を基準縮尺として使用しない**。

## 1. 画面一覧
|ID|画面名|形式|SVG|主に対応するIssue|
|---|---|---|---|---|
|SCR-01|店舗全景・通常営業|Shell|[01](mockups/01_store_overview.svg)|#5,#21|
|SCR-02|建設・レイアウト|Shell Mode|[02](mockups/02_layout_editor.svg)|#6,#7,#21|
|SCR-03|商品一覧・価格|Shell Panel|[03](mockups/03_inventory_management.svg)|#10,#21|
|SCR-04|日次収支・履歴|Shell Panel|[04](mockups/04_daily_report.svg)|#19,#21|
|SCR-05|タイトル・新規ゲーム|独立Scene|[05](mockups/05_title_new_game.svg)|#2,#20,#28|
|SCR-06|初回8段チュートリアル|Shell Overlay|[06](mockups/06_first_day_tutorial.svg)|#28,#32|
|SCR-07|仕入れ発注|Modal|[07](mockups/07_purchase_order.svg)|#11,#21|
|SCR-08|棚補充・什器在庫|Modal|[08](mockups/08_shelf_restock.svg)|#11,#12,#21|
|SCR-09|営業開始チェック|Modal|[09](mockups/09_opening_checklist.svg)|#17,#21,#28|
|SCR-10|営業終了/客退出待ち|Shell Overlay|[10](mockups/10_closing_in_progress.svg)|#15,#16,#21|
|SCR-11|日替わりイベント|Banner＋詳細Modal|[11](mockups/11_daily_event_festival.svg)|#21,#30,#31|
|SCR-12|初会計・実績通知|Banner＋非阻害Overlay|[12](mockups/12_first_sale_achievement.svg)|#17,#30,#32|
|SCR-13|日末まとめ|Panel＋任意Modal|[13](mockups/13_day_end_summary.svg)|#19,#30,#32|
|SCR-14|支払不能の復旧案内|Full-screen Modal|[14](mockups/14_payment_blocked.svg)|#17,#20,#21|
|SCR-15|通行量・在庫・混雑表示|Shell Mode Overlay|[15](mockups/15_store_heatmap.svg)|#24,#25|
|SCR-16|セーブ/ロード/設定|Modal＋Tabs|[16](mockups/16_save_load_settings.svg)|#20,#21|
|SCR-17|翌日広告予算|Modal|[17](mockups/17_next_day_advertising.svg)|#18,#21|
|SCR-18|実績・日替わり目標|Shell Panel|[18](mockups/18_milestones_and_challenges.svg)|#21,#32|

## 2. 画面別入出力・失敗状態・完了条件

### SCR-05 タイトル / title
- 表示: `新規ゲーム`, `続きから`, `設定`, `終了`。保存無しなら「続きから」をdisabled。保存スロット数は3。**ゲームオーバー/従業員雇用/現金報酬は追加しない**。
- `新規ゲーム`: 保存スロットを勝手に上書きせず`ScenarioFactory.new_game`を生成しSETUP/speed0でSCR-01＋SCR-06へ。
- `続きから`: SCR-16のLoadタブを表示。CRC/Schema/semantic検証済みの状態のみ差し替え、無効/旧版はエラーを示す。ゲーム内の`state`は破損ロードで変えない。
- `設定`: マスター/BGM/SFX/reduce_motion/表示設定。 `終了`: OS終了確認。新規操作前にsaveが存在するときは保存データ保護に注意。
- 試験: 初回起動/3slot満杯/破損save/設定保存/タイトルへの復帰。

### SCR-06 チュートリアル
- `tutorial_step_index`に基づく8段階（[15](../implementation/15_PROGRESSION_STORY_AND_SCENARIOS.md)が正本）。全画面乗っ取りを避け、店舗が見える案内とタイル/ボタンの強調を併用。
- STEP01観察、02レジ、03売場、04発注10個、05棚補充、06初開店、07初売上、08初日レポート。進行はDomain state/eventから判定、UIクリックだけでは進まない。
- `スキップ`は`tutorial_skipped=true`として進行状況を保存。戻して表示できる。STEP08はゲーム1日の締めであり、最初の5実分以内の完了を保証しない。
- 試験: レジを置く前に進まない、ロード後同step、途中スキップ/再表示、後段を先に満たす場合は正しく追いつく。

### SCR-07 発注Modal
- 商品24SKUをカテゴリ/検索/並び替えで表示、仕入単価はProductDefの`purchase_cost_yen`、売価はcurrent price override、在庫は`backroom`と`shelf`の物理数量を分ける。
- 数量は整数1..9999、確定するまで編集用draftのみ。合計仕入額=`Σ qty_i×purchase_cost_i`を整数円で表示。複数SKU発注はMVPで個別`ORDER_STOCK`コマンドを順に確定するが、**画面上は全行一括発注を装って部分失敗を隠さない**。確定前に総費用/残高で検証し、複数行一括コミットが必要なら新規Batch commandを設計してから提供。MVP推奨は1SKUずつ確定。
- UI: 対象行選択→数量入力→`発注`→成功数量/残高表示→必要なら次SKU。Esc=入力取り消しのみ。支払不能・未知SKU・qty0・上限超過は日本語エラー。
- 試験: 75円×30個=2250円、余剰注文防止、失敗時現金0変化。

### SCR-08 棚補充Modal
- 必須: fixture_id、slot_id、sku_id、バックヤードのFEFO在庫、棚slot容量/合計物理数量/予約数量、有効期限。ゲーム中はSETUPのみ補充可能。
- 最大補充量=`min(available backroom for sku, slot free units / sku.slot_units, fixture free units / sku.slot_units)`、qtyは1..最大、失敗時ロット部分移動を禁止。
- `補充する`→`RESTOCK`、成功時ShelfStateと商品表示slotを更新。棚不足/期限切れ/カテゴリ違い/営業中は実行不可理由を出す。
- 試験: 現金不変、ロット期限保持、予約中はロット移動不可、在庫を越える入力拒否、ガラス/商品表示とphysical一致。

### SCR-09 営業開始チェック
- 表示項目: レジ有無、到達可能な棚＋物理在庫>0、入口→レジqueue/棚アクセス経路、当日広告・固定費・電気代の未請求額、現金。条件を満たす場合のみ`START_BUSINESS`。
- 失敗時は`MISSING_REGISTER/MISSING_SHELF/MISSING_STOCK/UNREACHABLE_ACCESS/INSUFFICIENT_CASH`等のテキストと修復先へのナビゲーション。
- 同日OPEN→CLOSING→SETUP→OPENでもその日の請求を二重計上しない。OPEN開始はspeed1。
- 試験: レジ無し/棚無し/アクセス不可/資金不足ではDomain無変更、正常開始は一度だけ費用支払。

### SCR-10 営業終了/退出待ち
- `REQUEST_CLOSE`後の`CLOSING`を表示。新規入店0、既存客と予約は維持し、店内客0かつ予約0でSETUP/speed0へ。**「閉店ボタン=強制消去」ではない**。
- 警告: 現客数/予約数、閉店待機中のレジ・商品。一時停止と区別し、PによるOPEN+speed0では建設不可。
- 試験: 3客2予約→CLOSING→客0予約0→SETUP、残予約の二重解除無し。

### SCR-11 イベント通知
- Day0は発生しない。Day1以降、EventDirectorが一日最大1件を確定。Banner→必要なら詳細Modalで名称・効果・開始/終了時刻・対象カテゴリを示す。倍率は当日の確定`GameplayEventState`から表示。
- 本SVGの祭りは12イベントのうちの一例。**固定seedのDAY1で祭りが出るという意味ではない**（固定seed検証例は`evt_after_work`）。
- closeしても効果は継続。既読は保存され、LOAD後に開始効果・音・抽選を再実行しない。
- 試験: 期間中だけ需要倍率1回、0在庫でも在庫を作らない、reduce_motion時は静的Bannerを表示。

### SCR-12 初売上と実績
- トリガーは`SALE_COMMITTED`であり、予約/商品取得時点ではない。売上表示は取引から、初回実績は`ms_first_sale`のMilestoneTrackerで一意に確定。
- 褒賞はバッジ/称号のみ。金銭・評判・在庫を演出側から変更しない。演出をskipしても実績は保持。
- 試験: checkout ID再送で二重売上/二重実績にならない、音欠落でも会計成功。

### SCR-13 日次振り返り
- 00:00で`DAILY_CLOSED`確定後のread-modelから売上、COGS、粗利益、廃棄、広告、固定費、電気代、営業利益、現金増減、来店/購入客数、当日イベント/チャレンジを表示。
- これは**日付更新の通知**で、レポートを開かなくてもDomainの翌日の計算は進む。Modal表示中の明示的pauseが必要ならspeedを0に変更するがbusiness_stateはOPENのまま。
- `翌日の経営へ`はパネルを閉じるだけ。表示から直接翌日経済を再実行しない。
- 試験: 赤字は赤/マイナス符号/説明を伴う、設備投資はoperating profitに混ぜない。

### SCR-14 支払不能
- `business_state=PAYMENT_BLOCKED`のとき、`unpaid_cost_yen`,未払経費の根拠、日付、最新正常保存スロットを表示。**ゲームオーバー演出にしない**。
- 操作は直近正常セーブの安全なロード、タイトルへ戻る、新規ゲーム開始。MVPは未払いを解消する経済コマンドを持たない。再実行して現金を生成しない。
- 試験: ロードエラーで元のPAYMENT_BLOCKEDゲーム状態を壊さず警告、未払を二重認識しない。

### SCR-15 分析Overlay
- 通行量/混雑/在庫不足/売場アクセス不可をタブで切替。可視化はGameSnapshot/集計read-modelで計算し、**店舗グリッドのwalkableや現金を変更しない**。
- 各heat zoneはlegendと数値を持つ。色盲対応でテキスト/アイコンを併記、遮蔽物の選択補助とオーバーレイクリック透過制御を行う。
- テスト: OPEN中でも表示可能、zoom/panで地図座標が棚/歩行セルからずれない、切替だけでsimulation PRNGを消費しない。

### SCR-16 セーブ/ロード/設定
- SLOT1〜3限定、未使用slotの`ロード`disabled。既存slotの保存は上書き確認、ロードは現ゲーム進捗の破棄確認。不正save/旧schema/途中書込は既存ゲームと直前正常保存を保持。
- セーブ書込は安全なtick/command境界で実行。顧客・予約・rng・event・progressionなどsave v1の必須値を含む。
- 設定: Master/BGM/SFX、reduce_motion、画面スケール、操作ヘルプ。保存スロットJSONにUI設定を混ぜず、`user://settings.json`の別ファイルへ。
- テスト: 3枠/上書き/キャンセル/旧データ読み込み拒否/時間pause/入力がviewportへ透過しない。

### SCR-17 広告・販促
- **MVPは翌日広告予算の5ティアのみ**：0円×1.00、1000円×1.10、2000円×1.18、5000円×1.30、10000円×1.40。SNS広告・チラシ等の個別キャンペーンを複数積み上げるシステムは実装しない。
- 今日の確定予算と翌日の予約額を分離。クリック中はpreview値だけ変更、`SET_NEXT_DAY_AD`成功で予約を保持。今日の現金・広告費は操作直後に変化しない。
- 試験: 2回の予算変更は最後の予約値だけが翌日有効、当日広告費を重複請求しない。

### SCR-18 実績/チャレンジ
- 12 Milestoneと3パターンのDaily Challenge。進行率のデータソースはledgerの一意SALE event、日次レポート、stocked categories、reputation。reward=badge_only。
- チャレンジの当日選択は日番号mod3で確定し同日LOADで不変。既達成IDを再通知しない。店舗バッジ/称号はUI表示のみ、架空の現金/商品報酬や未実装設備unlockを描かない。
- テスト: 1 sale→ms_first_saleを一度だけ達成、day1/2/3の各チャレンジを条件別に検証。

## 3. QA合格ゲート
1. 18 SVGの存在とリンク、対応するScreenID・Issue・Stateが画面仕様と一致する。
2. 画面遷移は[SCREEN_NAVIGATION_AND_STATE_MATRIX](SCREEN_NAVIGATION_AND_STATE_MATRIX.md)に準拠し、モーダルの背後にクリックが通らない。
3. 1920×1080/1280×720で主要ボタンが全て可視、文字切れ・余剰透明Controlの誤操作無し。
4. ストア各画面は2.5D世界の1m:128×64pxに対応。SVGは原寸ではないため世界縮尺検証に使用しない。
5. **発注失敗/棚補充失敗/開店不可/LOAD破損/支払不能**の否定シナリオを実機操作し、Domain不変とUI文言を同時に検査。
6. Animation/Audio/reduce_motion有無で同seed同tickの経済値が変わらない。
7. モックアップにない画面状態が実装時に必要となった場合は先に本書へ仕様追加、Issueへ受入条件を追記する。
