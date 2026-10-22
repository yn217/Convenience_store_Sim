# 2.5D アニメーション・音・VFX・UI演出実装規約 v1.0
日付: 2026-10-23。MVP画風は**リアル寄りの固定2.5D・2:1菱形**。ゲーム画像としての透過PNGは未制作。

## 1. プレゼンテーションの時間・順序
- お店全体のアニメーションは`PresentationEventBridge`がDomain EventEnvelopeから発行する`CueRequested`で始動する。**AnimationPlayerやTweenの終了を待って在庫/会計を確定しない**。
- 物理在庫減少のタイミングはCHECKOUT確定時のみ。購入演出中もUIのphysical_qtyは正確な整数。手に取った演出は人物側の**仮の描画商品**で、棚の表示physicalはまだ減らさない。
- `clock = game_time`: 客歩行、レジの処理進捗、時間帯照明、店内BGM条件。speed0なら静止。2×/4×でもアニメの見かけが延々遅れないよう`anim_time=game_time_seconds`からステートを求める。
- `clock = real_time`: ボタン押下アニメ、トースト出入、音量フェード（PauseでもUI反応する）。キャラクターや会計の**再生完了をdomainイベントの条件にしない**。
- CLOSINGではBGMを静かな退店待ちへ、SETUPは建設BGMへ。通常営業は時間帯変化。PAYMENT_BLOCKEDでは音量を落として警告表示（不快なアラーム連打禁止）。

## 2. 客キャラ/商品/設備のアニメ基準
|cue_id|トリガー|映像/動き|再生の長さ|経済的副作用|
|---|---|---|---|---|
|customer_enter|CUSTOMER_ENTERED|ドア2枚の軽い開閉＋足元揺れ|0.35実秒|なし|
|customer_walk|CustomerState WALK_*|4方向スプライトwalk6フレーム/方向、同じworld anchor|1サイクル0.75ゲーム秒|なし|
|customer_idle|INSPECT/QUEUE|2フレーム呼吸/姿勢差|1.2ゲーム秒|なし|
|product_pickup|CUSTOMER_RESERVED_ITEM|棚前で腕を上げる＋小さい商品アイコン|0.45ゲーム秒|なし|
|checkout_success|SALE_COMMITTED|レジのLED発光＋「+¥xxx」浮上＋電子音|0.5実秒|なし|
|empty_handed|CUSTOMER_EXITED_NO_PURCHASE|小さな残念アイコン/肩落とし|0.7ゲーム秒|なし|
|low_stock_notice|STOCK_LOW|選択棚の低在庫バッジ＋HUD通知|表示は継続、重複30ゲーム秒で抑制|なし|
|expiry_notice|STOCK_EXPIRED|棚に廃棄アイコン、日次損失を通知|1.5実秒|なし|
|long_queue|QUEUE_TOO_LONG|レジ上に「待ち時間増」バッジ|2実秒|なし|
|daily_event_start|EVENT_STARTED|イベント名・対象/期間・倍率の上部通知|3.5実秒|なし|
|daily_event_end|EVENT_ENDED|イベント終了小バナー|2実秒|なし|
|daily_recap|DAILY_CLOSED|店舗全景→日次レポートへスライド|0.45実秒|なし|
|milestone_celebrate|MILESTONE_REACHED|フラッグと小紙吹雪（画面内限定）|1.2実秒|なし|

- 顧客ルックは**成人の一般的な来店客**、衣服の色・髪型は無作為でも商標や特定実在人物は不要。MVP初期で最低3バリエーション（シルエット/色）。
- **キャラsource画像も家具と同一投影**`iso2x_v1`、1m=sourceの投影XY(+128,+64)等。人体model身長約1.65m、base pivot=靴底world(0,0,0)。歩行4方向/各6フレーム、待機各2、選択購入各4、レジ各4、退店各2を制作可能なmanifestとして分割。初期は6fps〜8fps相当の節約型。
- 映像のバリエーション追加は単純2Dミラー禁止（左右の衣服ロゴ/バッグ持ち手が入れ替わる）。4方向キャラ作成時は世界回転してからレンダー。
- カウンター/レジLED、扉、冷蔵照明は非破壊overlayとして実装。棚本体をリアルタイムの3Dへ置き換えない。
- 時間帯照明: 06-17時通常、17-20時夕景、20-05時夜間。ゲーム時計を参照したPresentationだけの光量・色変更（通常営業の時刻weightは別で保持）。朝/夕/夜のパレットは画面可読性を優先し、店内の商品は常に識別できる。

## 3. シーン/アセットの格納
```text
assets/source/blender/characters/customer_base.blend   # または生成py
assets/source/blender/fixtures/{register_basic,fridge_drink,...}/
assets/source/textures/packages/<sku_id>/
assets/generated/characters/customer_a/{0,1,2,3}/{walk,idle,inspect,checkout,exit}/
assets/generated/fixtures/<type_id>/<direction>/{body,shadow,glass_front,fixture_front}.png
assets/generated/vfx/{checkout_glow,low_stock,confetti,steam}.png
assets/generated/audio/bgm/{setup,day,evening,night,daily_recap}.ogg
assets/generated/audio/ambience/{store_hum,door_street,rain_optional}.ogg
assets/generated/audio/sfx/{door_chime,register_beep,stock_move,ui_confirm,ui_cancel,warning,milestone}.ogg
data/presentation/cues_v1.json
scenes/ui/{EventBanner,NotificationStack,MilestonePanel}.tscn
```
- MVPでは音声素材自体をAI生成したりGit管理したりしていない。音源のライセンス・制作者/生成方式・音量統一を`docs/ASSET_CREDITS.md`に記録してから同梱。
- SFX: 1ファイルあたり原則mono 48kHz / OGG またはWAV、ピーク−1dBFSを上限目安。BGMはloop可のstereo 48kHz OGG。ファイルのサイズ/長さ/音量はインポート検査。
- Audio Bus: Master, BGM, Ambience, SFX, UI。MVPはMaster/BGM/SFX音量を設定で保存。ミュートでも同等の字幕/通知を必ず提供。
- ゲーム素材とデザインモックアップ`docs/design/mockups/*.svg`は用途が異なる。SVGの立体風図形を本番スプライト代わりに無検証流用しない。

## 4. Presentation Cue data
- [seed](../examples/mvp_v1.presentation_cues.json)が初期CueID、イベントsource、anim、SFX、priority、duration、dedupeキー、rate limitの正本。
- CuePlayerは同時演出上限：粒子最大80、画面売上フロート最大6、通知最大3、AudioStreamPlayer 8個まで。超過したnormal/ambientは順序保持を諦めてもよいがcriticalは文字通知を残す。
- 画面shake禁止（MVP）。高頻度点滅と視覚疲労につながるフラッシュ禁止。成功/失敗は色だけでなくアイコンと文字。
- `reduce_motion`では紙吹雪0、浮上演出を省き、通知は静止表示。音量設定やビジュアルの省略は売上/来店PRNGを変えない。
- 0.5xズームでも重要なイベントは画面上部HUDへ文で出す。World上の演出はLODで間引ける。GPUが遅いから顧客数や来店需要を減らしてFPSを偽装しない。

## 5. EventEnvelopeと再生の冪等性
- Domainイベントは`EventEnvelope{id,tick,type,payload}`。cueは`source_event_id`を参照して再生し、同じ再生成snapshotで二重発火しない。
- データ永続化対象は**重要な既読通知と有効イベント選択のみ**。音声の途中再生位置、紙吹雪粒子の状態、歩行の一時補間座標は保存しない。
- LOAD後に`EVENT_STARTED`を再生しない。HUDには**現在のイベント状態**を表示してから新しいイベント開始を待つ。
- 画面表示/Audio/SFXの例外をcatchしてスキップ可能。イベント終了通知が欠けてもevent effectの期限判定には影響しない。
- 浮上「+¥」は会計確定の現金増減に紐付き、手に取っただけでは出さない。

## 6. 受入テスト
- 顧客20人以上が同時移動しても、口座/経路/商品数量が演出の再生速度に依存しない。
- 4方向全て歩行/待機/商品選択のサイズ・足元anchorが一致する。
- 開店中に10件連続会計しても売上イベントは10件、レジ電子音は制限に従い再生。
- reduce_motionを切り替えても同seed同tickなら来店客数・売上・在庫/現金は同じ。
- 音声ファイル欠落でも会計動作を続行し、critical文字通知は消えない。
- 同じEVENT_STARTEDを二度受信してもトーストは一回。セーブ→ロード→再Openでも費用/イベント倍掛けしない。
- 夜間/昼間とも棚SKUとUIテキストが読める。
