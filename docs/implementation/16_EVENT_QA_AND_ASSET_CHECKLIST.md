# 演出・イベント・進行の固定受入テスト仕様 v1.0
2026-10-23。データ正本: [イベント12件](../examples/mvp_v1.gameplay_events.json)、[Cue15件](../examples/mvp_v1.presentation_cues.json)、[実績12件](../examples/mvp_v1.milestones.json)。素材未制作/ゲーム未実装を前提に設計段階の検証と実装後の検証を区別する。

## 1. EventDirectorのゴールデン値
- RNGはLCG32。seed 345678の次stateは**877959509**。
- 評判50でeligible=11件（`evt_neighbor_mentions`だけ評判60未満のため除外）、イベント11件×weight7 + none_weight30=**107**。
- event候補の`event_id`を**ASCII辞書順**（大小文字混在不可、lower snake_case）に並べる。`roll=877959509%107=6`。
- 最初のIDは`evt_after_work`、weight7なので**最初の抽選結果はevt_after_work**（18:00〜23:00、traffic×1.20）。
- `last_selected_day=-1`、DAY0は抽選せずRNG不変。DAY1最初のOPENで1回のみ上記を抽選。LOAD→同日CLOSE→OPENではイベントID・event_rng_state不変。
- DAY1に`evt_after_work`が有効なのはゲーム日内[18:00,23:00)。境界17:59:58→18:00:00でEVENT_STARTEDが1回、22:59:58→23:00:00でEVENT_ENDED1回。翌日の同イベントが再抽選された場合は新しいIDを使う。
- OPEN+speed0なら境界到達しない、事件の効果と開始/終了通知は前後のゲーム時間に従う。4×でイベント抽選・開始/終了を飛ばさない。
- Day1最初のOPENが23:30ならイベントは`SKIPPED_WINDOW`として記録（同日再抽選・翌日持越し無し）。

## 2. 固定シナリオ Given/When/Then
|ID|Given|When|Then|
|---|---|---|---|
|EV-01|DAY0/初回SETUP|START|ランダムイベント0、基本チュートリアルが表示|
|EV-02|DAY1, reputation50, event RNG345678|最初のOPEN|選択evt_after_work、RNG877959509|
|EV-03|DAY1選択済みイベント|同日CLOSE→OPEN、LOAD|抽選結果・乱数・倍率は同一|
|EV-04|18:00直前の有効event|2秒tick進行|EVENT_STARTED1件、交通需要×1.20|
|EV-05|23:00直前の有効event|2秒tick進行|EVENT_ENDED1件、需要係数1.0へ|
|EV-06|有効カテゴリ人気イベント|対象SKU在庫0|売場に商品が出現せず、実在庫/現金0変化|
|EV-07|active 交通イベント ×1.25、広告tierが1.1|需要計算|既存来店率の積に1.25を**1回だけ**掛ける（1.25²にしない）|
|EV-08|OPENでpause(speed0)|UI通知/設定変更|イベント時計止まる。通知は読める。経済は停止|
|EV-09|CLOSING（客あり）|イベントstart境界|新規客を生成しない。先に確定済み客の会計のみ続行|
|EV-10|ロード直後、すでにEVENT_STARTED済み|最初のPresenter snapshot描画|上部バナーは現在状態を表示、開始音/紙吹雪の重複再生無し|
|EV-11|SFXファイル無し|SALE_COMMITTED|売上は確定、UI数値と控えめ文字通知は表示|
|EV-12|reduce_motion ON|EVENT_STARTED/MILESTONE_REACHED|点滅/紙吹雪を省略、情報と利益計算はそのまま|
|EV-13|客30、同tick 15件イベントCue|表示|最大toast3、浮上売上6、particle80、音声同時8の制限を超えない|
|EV-14|同fixtureのSTOCK_LOWが30ゲーム秒内に5件|通知|重複バッジ1件へまとめる、在庫計算は各イベントで正確|
|EV-15|初会計1件|売上確定|ms_first_sale一度達成、会計のduplicate再送では二度目無し|
|EV-16|店内客予約中|商品pick-upアニメが終わらない|Domainの会計/商品期限は固定tickで進み、アニメでブロックされない|
|EV-17|DAY1 challenge_sales_3|SALE_COMMITTED 3 unique ID|達成通知1回、現金/評判ボーナス0|
|EV-18|DAY2 challenge_stock_2|到達可能2カテゴリ以上をOPEN中に満たす|challenge_stock_qualified記録、CLOSE/LOADしても同じ|
|EV-19|DAY3 challenge_no_waste|廃棄0、販売0でDAILY_CLOSED|未達成（販売1件以上必要）|
|EV-20|イベント・チャレンジ・実績があるSAVE|LOAD→PLAY→SAVE|当日event ID/既読通知/RNG/達成済ID/チャレンジを維持|
|EV-21|DAY1 reputation59|イベント抽選|evt_neighbor_mentionsは候補に入らない|
|EV-22|DAY1 reputation60|イベント抽選|evt_neighbor_mentionsを候補へ追加|
|EV-23|4方向3種キャラ・商品/レジ|ズーム0.5/1/2|靴底anchor一致、建築と前景/背後の重ね順が正しい|
|EV-24|昼→夕→夜の時刻変化|同seedでFPS変更|ライト/BGMだけ変化、客の来店・販売履歴同一|

## 3. データ検証ゲート
- MVP events=12、IDsはユニーク、すべての時間窓が0 <= start < end <= 24、weight>=1、traffic0.70..1.40、カテゴリ倍率1.0..1.80、カテゴリーは既存8カテゴリのみ。
- CueDefs=15、IDs/トリガーは妥当、SFX keyは一覧の音源アセットの**制作予定キー**。実ファイルの存在は制作後のasset validatorでチェックし、欠落は警告/代替通知へ落とす。
- MilestoneDefs=12、metricは既存のstate/ledgerから判定可能、reward.kindはbadge_only、無料の実在庫・現金の付与は禁止。
- `savegame.schema.json`に`rng_states.events`, `gameplay_event_state`, `progression_state`が必須、空店舗サンプルが適合しロード時の参照/重複semantic checkを通過すること。
- source画像/音声が存在しない現段階では**データ構造検査の合格≠アート/演出受入完了**。

## 4. テスト・受入の進め方
- Pure domain unit: daily event selection, reputation eligibility, category bonus, price multiplier interplay, RNG one draw, persistence and reload.
- Contract: JSON Schema 3種＋Save v1、イベントとCueのID参照、Asset IDの存在、時間窓とユニーク性。
- Scene/UX: 音・通知・UI、EVENT_STARTED重複なし、低在庫/売切れ、動きの軽減、速度切替、ドアベル制限。
- Scenario E2E: DAY0初日売上、DAY1イベント、イベント中/後の集客数、実績とチャレンジ、再開後の履歴。
- 既存固定性能ベンチ（16×12、什器20、可視客30、1920×1080、ズーム1.0）は**変更しない**。イベント演出を有効/無効にした場合の追加コストは別条件として記録。平均 FPS とp95 frame timeを報告。
- UIスクリーンショット、イベントログ、Replay input/seed、Godot minor版、git commitをIssueへ記載。演出の「面白さ」の承認はゲームプレイで別途行う。

## 5. 生成が必要なアセット・作業リスト
- [ ] 客3バリエーション×4方向：歩行各6frame、待機各2frame、商品選択各4frame（モデル共通骨格、Blender生成元を残す）
- [ ] POSレジ: LED、会計時の点灯、透明レイヤー
- [ ] ドア開閉: 0.35秒、座標軸/ドア接地と一致
- [ ] 背景照明: 通常・夕方・夜間プリセット
- [ ] POP: 12イベントのアイコン/ラベル（共通テンプレートで差替可能）
- [ ] 粒子VFX: milestone紙吹雪、レジ発光、売上文字、廃棄/低在庫バッジ
- [ ] BGM: 準備中/昼/夕/夜/日次まとめの5ループ
- [ ] 環境音: 冷蔵・空調/来店ドア/任意の雨の3系統
- [ ] SE: ドアベル/レジ/商品選択/補充/UI確認/エラー/称号の7系統
- [ ] 全素材の権利/出典台帳記載と日本語UIの文字判読テスト
