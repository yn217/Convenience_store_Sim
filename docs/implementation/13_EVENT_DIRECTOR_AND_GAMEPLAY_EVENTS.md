# イベントディレクター・日替わりゲームイベント実装仕様 v1.0
更新日: 2026-10-23。**実装に用いる規範**。既存01/03/08/09/12に追加し、これらのコマンド/在庫/会計/保存不変条件は変更しない。

## 1. MVPのゲームらしさ
- プレイヤーが観測できる変化 = 来店→買物→決済の演出、時間帯の照明/音、日替わり出来事の通知、達成と結果のフィードバック。
- **PresentationCue（演出だけ）**と**GameplayEvent（需要に影響）**と**Milestone（目標）**を異なる型として実装。見た目の再生に遅延/失敗があっても売上・在庫は変わらない。
- MVPの客は1訪問で最大**1SKU・1個**、従業員管理・泥棒・万引き・返品・警察・停電で在庫消失・商品配送遅延・ガチャ課金等は対象外。
- 日替わり出来事はゲーム性に変化を作るが、現金/商品を直接生成・減算するイベントは**MVPでは作らない**。商品の希少化は通常需要/在庫減による。
- 基本の広告・評判・価格・時間帯需要に**追加の決定論的係数を合成**し、既存ロジックを複製しない。数字は初期チューニング値として外部JSON化する。

## 2. 構成
```text
data/events/mvp_v1.json                # GameplayEventDef[] — schemaで検査
data/presentation/cues_v1.json          # CueDef[] — event→画面/SFX/anim対応
data/progression/milestones_v1.json     # MilestoneDef[] — 改善目標
scripts/domain/gameplay_event_director.gd
scripts/domain/milestone_tracker.gd
scripts/application/presentation_event_bridge.gd
scripts/presentation/cue_player.gd
scenes/ui/{EventBanner,NotificationStack,MilestonePanel}.tscn
assets/generated/vfx/ ; assets/generated/audio/{bgm,sfx,ambience}/
tests/{unit,contract,scenario,scene}/
```
- Domain EventDirectorは`evaluate_daily`と`effects_at`だけを公開、Godot Sprite/AudioPlayerへ依存しない。
- ApplicationのPresentationEventBridgeは既存`EventEnvelope`をread-only受信して`CueRequested`へ変換する。Presentation側CuePlayerは資金・在庫・客ステートを更新しない。
- `GameEventState {last_selected_day, selection_event_id, active_event_id?, event_start_sec?, event_end_sec?, completed_event_ids[], shown_notice_ids[], event_rng_state}`をセーブに保存。セーブSchema拡張仕様は本書9節。
- 一日のイベントは**最大1件**。イベント無し抽選も記録。確定したイベントは当日中にコマンド/ロード/広告予算変更で再抽選しない。

## 3. deterministic日次抽選アルゴリズム
選択の実行点: **ゲーム内day_index ≥1（2日目以降）の、その日最初にOPENになった安全なcommand phase**、またはOPENのまま日境界を越えた直後。DAY0はチュートリアル専用でランダム事件無し。

1. `last_selected_day == today`なら何もしない（レジューム/同日再開含む）。
2. 必要なイベント条件（店舗レイアウト/Stockカテゴリ/評判など）を当日開始時点のsnapshotに対して評価し、条件を満たすGameplayEventDefを候補にする。ID昇順ソート。
3. 候補総weightに、**none weight=30**を加える。`next(event_rng_state)`を**厳密に1回**実行し`roll=next() % sum_weights`。昇順event候補を累積比較し、最後をnoneとして処理。選択処理が0件候補でも1回消費する。
4. `selection_event_id = "daily:"+day_index`、当日選択/noneを保存し、`shown_notice_ids`とイベントログに追跡。
5. 選ばれたeventの`start_hour`と`end_hour`を当日game timestampに展開。**その日の最初のOPENがend時刻以降なら発生期限切れとして記録し、選び直さない**。
6. start前なら予約状態。startを跨ぐtickで`EVENT_STARTED`を1回発行。endを跨ぐtickで`EVENT_ENDED`を1回発行。終了後は係数を1.0へ戻す。
7. `SETUP`ではゲーム時間が止まる。CLOSINGは新規来店がないのでイベントによる新規来店効果はなし。イベントタイマーはゲーム時刻に従い進行し、OPEN再開時は保存されたday/indexと有効区間を使って復帰。PAUSE (speed0) はイベント時間を進めない。
8. `EVENT_STARTED`等のIDは`daily:day_index:event_id:started|ended`。同IDを2度replayしない。

### RNGの分離
- [09](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)のLCG32と全く同じ更新式`state=(1664525*state+1013904223)%4294967296`を使用。
- `rng_states.events`初期値`345678`、他のarrivals/purchases/visualsと**完全に独立**。BGMの切替・再生失敗/画面FPSがevent選択や売上乱数のstateを消費しない。
- イベント抽選結果が来店確率に影響するのは**ゲームプレイ上の意図的差分**であり、同event seed/同command列なら同じ結果になる。

## 4. 効果の適用方法（数式）
既存来店確率は[09](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)の原式に以下を**1箇所だけ**追加：
```text
potential_probability =
 clamp(100 * normalized_hour_weight(hour)
       * ad_multiplier * reputation_multiplier * assortment_multiplier
       * gameplay_event.traffic_multiplier(game_time)
       / 43200, 0, 1)
```
- event有効でなければ`traffic_multiplier=1.0`。
- SKU候補重み`weight(sku,fixture)`に`gameplay_event.category_weight_multiplier(category)`を乗算。該当しないカテゴリは1.0。**価格による購入確率0.8*price_factorは既存規則通り**、イベントが勝手に購入量を2個へ増やさない。
- MVPは交通倍率`0.70〜1.40`、カテゴリ重み`1.0〜1.80`にschema制限。価格/広告/評判/固定費を直接改変しない。日中の既購入/予約価格は変更しない。
- `active event`が対象カテゴリ未入荷の状態で発生したら**イベントは通知されるが需要向上の利益が出ない**。仕入れ・陳列を改善する動機として案内する（自動で商品は増えない）。
- 時間帯の需要原式に昼ピークは既にあるため、「昼の繁忙」演出は**追加乗数なしの表示Cue**。同じ理由でゲーム内24h/曜日計算を重複計上しない。
- 今日の広告効果をイベント倍率として二重計上しない。「チラシ反響」の発生条件に広告を使う場合も`ad_multiplier`自体は1回だけ。

## 5. 日替わりイベントの種類（初期MVP 12件）
**実データは[events seed JSON](../examples/mvp_v1.gameplay_events.json)が正本**、下表は意図の説明。

|ID|出来事|時間|条件|効果|見た目|
|---|---|---|---|---|---|
|evt_local_fair|地域のお祭り|17-22時|通常|traffic×1.35|近所の賑わい通知|
|evt_roadworks|近隣の工事|9-14時|通常|traffic×0.75|工事アイコン、注意トースト|
|evt_hot_day|暑い日の人気商品|11-17時|飲料/アイス在庫の有無を問わない|飲料×1.6, アイス×1.6|陽射しと冷たい商品POP|
|evt_cold_day|寒い日の人気商品|8-13時|通常|おでん×1.6, カップ麺×1.4|湯気・温食品POP|
|evt_sweets_spotlight|甘いもの特集|13-19時|通常|デザート×1.7|デザート棚のバッジ|
|evt_snack_buzz|おかしが話題|12-18時|通常|菓子×1.7|新着バッジ/軽いスパークル|
|evt_neighbor_mentions|口コミで話題|10-18時|評判60以上|traffic×1.25|口コミカード（架空）|
|evt_quiet_street|静かな通り|7-13時|通常|traffic×0.85|落ち着いた街の環境音|
|evt_lunch_pick|手軽な昼食が人気|11-14時|通常|おにぎり×1.5,パン×1.3|お昼おすすめPOP|
|evt_drink_pick|飲料まとめ買い気分|14-20時|通常|飲料×1.75|飲料棚のハイライト|
|evt_bread_feature|焼きたて気分|7-11時|通常|パン×1.65|パン棚の小演出（実際の製造なし）|
|evt_after_work|仕事帰りの人流|18-23時|通常|traffic×1.20|夕景＋会社帰りの客|

- 「まとめ買い気分」は**個々の客が1商品だけ買う**既存MVPの販売数に矛盾しない表示コピー。アニメだけで同時多数購入を見せない。
- 日照/気温/騒音アイコンは**演出用**。実際の天気予報・気象シミュレーションはMVPに追加しない。
- 効果が負（例：工事）のイベントはプレイヤーに「品揃え改善で乗り切ろう」等の説明と、終了時刻を見せる。罰だけ与えない。
- EventDirectorはイベント効果以外に固定経費/現金を変化させない。純損益への影響は自然な売上数量の差分だけ。

## 6. シーン演出へのイベント配送
既存Domain event→PresentationCue対応（exactly once visual best-effort）：
- `CUSTOMER_ENTERED` → `customer_enter`: 入店ドアベル、軽いドア開閉、顔向き更新。
- `CUSTOMER_RESERVED_ITEM` → `product_pickup`: 棚へ手を伸ばす/商品シルエットが商品表示から取置き表示へ変化（**棚の物理在庫は会計まで減らさない**）。
- `SALE_COMMITTED` → `checkout_success`: レジ電子音/売上+¥、決済演出、在庫表示更新。
- `CUSTOMER_EXITED_NO_PURCHASE` → `empty_handed`: 軽い肩落とし/小さな吹き出し。誇張しすぎない。
- `STOCK_LOW` → `low_stock_notice`: 棚輪郭+小さな低在庫タグ、画面右通知。
- `STOCK_EXPIRED` → `expiry_notice`: 廃棄注意と損失がわかる通知（現金が再減算されたように見せない）。
- `QUEUE_TOO_LONG` → `long_queue`: レジ前の小さい不満吹き出し、行列警告。
- `EVENT_STARTED` → `daily_event_start`: 上部banner＋適用時間＋倍率/対象カテゴリ表示。
- `EVENT_ENDED` → `daily_event_end`: 終了表示、効果を次tickから1.0へ戻す。
- `DAILY_CLOSED` → `daily_recap`: レポートへ自然に遷移するアニメ。
- `MILESTONE_REACHED` → `milestone_celebrate`: 小さな紙吹雪とリボン、次目標。

**Cueはゲームの事実ではない**。通知の取りこぼし・skip・60FPSからの低下があっても金銭・在庫・来店客数は変えない。

## 7. 頻度/通知優先順位・アクセシビリティ
- `priority`: critical（会計不能/費用）、important（日替わり/目標）、normal（売切れ/初回会計）、ambient（来店SFX/歩行）。1フレームでの優先: critical > important > normal > ambient。
- 通知スタック最大3、同一type・fixture IDはゲーム時刻30秒以内の重複を1件へ集約。売上+¥は画面に同時最大6件、ドアベルは1実時間秒に最大1再生。
- `skip_animations=true`,`reduce_motion=true`で動きと紙吹雪を抑制、通知テキスト・数字は残す。ミュートでも情報を失わない。
- 1×/2×/4×で**顧客の移動/手に取る演出/ゲーム内オブジェクト**はゲーム時間に同期。HUD toasts/BGMフェードは実時間を使う。pause中でもUI操作の短い確認演出だけは再生できる。
- 演出が経済ロジックを待たせない（await animationで会計停止禁止）。サウンドは別レイヤー。
- 敏感な点滅は避ける（フラッシュ光なし）。色だけで失敗/成功を伝えない。設定で演出を無効化可能。

## 8. 仕様の拡張と非対象
- MVP以降: 店員の感情・会話、強盗/万引き、複雑な冷蔵故障、キャンペーンの発注原価変更、複数商品バスケット、季節カレンダーと年次行事、リアル天候、配送/サプライチェーン。
- 季節/祭日表現を導入する際も、保存済みのイベントID/ゲーム日とtimestampの規約を変えずversionを上げる。
- EventDirectorと販売ロジックを密結合しない。追加可能なのはeffect typeの明示的列挙のみ。

## 9. Save/schema拡張（実装前のv1契約）
- `rng_states.events`（LCG32 uint32）を追加。
- `gameplay_event_state`: `last_selected_day:int`(-1=未抽選), `selection_event_id:string|null`, `selected_event_id:string|null`, `event_start_sec:int|null`,`event_end_sec:int|null`,`started:bool`,`ended:bool`, `shown_notice_ids:string[]` を追加。
- **`event_id`と`selection_event_id`は別**。イベント開始効果は時刻で求め、通知はevent_envelope IDで一回だけ。
- ランタイムコードがまだ未実装なのでsavegame `schema_version=1`に追加する。ただし**既に作成済みの旧例/他branchの同versionファイルとは非互換**となるため、必ずcode reviewerがこの契約の採用を確認し、実装時の移行不要をリリース前に検証する。初回リリース後に同versionの破壊変更をしない。
- 保存/ロード後も選択済みイベントは当日再抽選しない。TIME変更/再開時に過去の`EVENT_STARTED`を画面で重複演出しない。
- データ検証: `docs/schemas/gameplay_event.schema.json`、`docs/schemas/savegame.schema.json`。パス/カテゴリ/IDの意味検証はruntime validator。
