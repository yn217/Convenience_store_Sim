# UI / Save / Acceptance / Performance Implementation Contract v1.0
依存: [00_BASELINE](00_BASELINE_AND_DECISIONS.md), [01_ENGINE](01_ENGINE_CONTRACT.md), [03_ECONOMY](03_ECONOMY_AND_SIMULATION_CONTRACT.md)。

## 1. UI scene contract
- `Main.tscn`画面構成: top HUD height 64px、左build palette width 280px、右inspector width 320px（いずれも1920×1080のデフォルト）、中央StoreViewportが残り領域。管理ダイアログは独立overlay。高さ/幅はtheme resourceから調整。
- 幅<1280pxではパレット/インスペクタをタブ切替で一度に一方のみ展開。中心store可視領域の最小幅640pxを目安に保つ。タイル選択計算はzoom/pan/viewport clipping後の実座標から逆投影。
- UI表示文字は日本語、通貨は`¥123,456`、数量は`12個`、日次レポートは`売上`・`売上原価`・`粗利益`・`営業損益`・`現金の増減`を混同せず表示。
- タブ: 建設/仕入れ/価格/広告（翌日予約）/日次レポート/保存/設定。HUD: 所持金, 本日の売上, 本日の粗利, 現在店内客, ゲーム日付/時刻, 速度, 営業状態。
- UIはdomain snapshotの購読者。**GUI自身がcash/stock/customerを書き換えない**。

## 2. ユーザー入力ステートマシン
```text
OBSERVE → PLACE_PREVIEW → PLACE_COMMIT → OBSERVE
OBSERVE → MOVE_PREVIEW → MOVE_COMMIT → OBSERVE
OBSERVE → SELECTED → INSPECT_PANEL → OBSERVE
OBSERVE/SELECTED → MODAL → return previous state
```
- 操作状態は`UiInteractionMode`列挙: `observe, place, move, inspect, modal`。異なるmodeを同時有効にしない。
- left click: 通常選択/preview確定、right clickまたはEsc: 操作キャンセル、R: プレビューを時計回り90°、Delete: 選択什器の撤去確認、mouse wheel: pointer-centred zoom、middle drag or Space+left drag: viewport pan。
- F: 全店舗フィット表示、**Pのみ**時計のpause toggle。Space単独には操作を割り当てず、Space+ドラッグはパン。OPEN+Pは**営業停止ではなく時計の停止**で、建設不可。建設するには営業終了操作で客が退出しSETUPへ戻る必要がある。
- Ctrl+Z / Ctrl+Y: 店舗の**停止中の建設編集履歴だけ**対象。売買/会計/在庫/時間経過のUndo禁止。
- 機能パネル/ダイアログが入力を受け取ったpointer eventは店舗viewportへ伝播させない。モーダル時viewportの入力を無効にする。
- 選択した棚と背景に客が重なるときは、論理occupancyのinstance_idを選択候補に含め、クリック/タブで選択を切り替え可能。
- install failedは`CommandResult.code`を日本語へマッピング。赤/黄/緑だけに依存せず「入口を塞ぐため設置できません」等のテキストを出す。
- 「営業開始」disabled理由: レジ無し / レジへの到達不可 / 販売棚無し / 商品未補充 / 顧客アクセス不可 / 支払不能。
- 対象店舗初回はチュートリアル目標を表示。達成はUIクリック履歴ではなくdomainイベント/状態から判定。新規ゲームを作り直さずに再表示できる。

## 3. プレビュー/確定トランザクション
- PLACE_PREVIEWはDomainの不変な`PlacementProposal`を取得し、選択予定セルをハイライト。**プレビュー中に現金を引かない**。
- COMMITの瞬間に最新版StoreState revisionで再検査。元プレビューを信頼せず衝突/資金不足を再判定。成功ならEvent1回を登録。
- 途中キャンセルで状態変更0。MOVE_PREVIEW中は元の什器を当たり判定では「移動中」として除外するが、**他のコマンドにとって占有はまだ存在**。失敗時完全ロールバック。
- 什器移動の費用は0円、撤去返金は0円（実装デフォルト）。撤去時に棚ロットをバックヤードへ返す（予約中は拒否）。
- Save/Loadは建設プレビュー未確定ならキャンセルし、安全step境界で実行。モーダルからは終了・再開しても入力は不整合にならない。

## 4. Savegame v1 exact boundary
- 保存スロット`slot_1, slot_2, slot_3`の3つをMVP固定。`user://saves/<slot>.json`を使用。 `schema_version:1`。
- 必須トップフィールド: `schema_version`, `save_id`, `saved_at_utc`, `game_tick`, `game_time_seconds`, `speed_setting`, `business_state`, `rng_states`, `store`, `store_reputation`, `product_price_overrides`, `fixture_instances`, `inventory_segments`, `reservations`, `customers`, `economy`, `advertising`, `daily_reports`, `applied_event_ids`。正確な構造は`docs/schemas/savegame.schema.json`。
- 保存はtick処理終了後の不変GameSnapshotを作成→JSONエンコード→同じディレクトリのtemporary filenameへ書込/flush→ロード再検証→元ファイルが存在すればbackupへ切替→atomic replacement（OSのrename失敗は警告し元保存を保全）。
- 再開はすべての参照（fixture,lot,sku,customer, event）と数量不変条件を**新しいGameState**上で検証し、全検査成功後に既存状態を入れ替える。読み込みエラーは現状態を変更しない。
- 保存中の客/予約をそのまま復元（**予約を黙って解放しない**）。`rng_states`は客/需要/描画の独立seed状態。`applied_event_ids`と締めマーカーで再起動直後の二重決済/二重請求を防ぐ。
- 旧`schema_version`はMVPで自動移行しない。不明/古い/未来版の場合メッセージを出して読み込み拒否。上書きする前に明示的な確認。
- セーブ内に画像やキャッシュした商品LODを保存しない。ロード時にSKU/什器メタデータから復元する。

## 5. Config / JSON Schema / backwards compatibility
- Catalog types: `docs/schemas/fixture_definition.schema.json`, `docs/schemas/product_definition.schema.json`, `docs/schemas/visual_manifest.schema.json`。Schema Draft2020-12。
- 起動時はすべてのマスタJSONにvalidationを適用。開発中はエラー一覧を出し、リリースでは致命的データ破損なら起動失敗画面へ。
- Schemaの形式/必須条件の変更時は`schema_version`を上げ、保存済みサンプルとJSON Schemaを同PRで更新。単に見た目のspriteを変えるだけならsave schemaの変更は不要。
- master definitionはres://data配下に置き、ゲーム中のInstanceはmaster id参照を使う。master定義のパス/IDを変更してsaveを壊さない。

## 6. QA ゲート（詳細テストの正本）
[QA_ACCEPTANCE_PLAN](../QA_ACCEPTANCE_PLAN.md) S-01〜S-16を全件満たす。さらに以下を必須とする。
|Test ID|入力|期待値|
|---|---|---|
|ASSET-01|1×2棚/4方向|0°の1×2は90°で2×1、sprite pivotズレ<=1 screen px|
|ASSET-02|Blender world 1m 校正|source X step (+128,+64)、Y step (−128,+64) ±1px|
|ASSET-03|高さ1mの基準棒|source投影Z方向−156.767px ±2px|
|ASSET-04|10種設備のmesh bbox|footprint−0.08m以内、最大高さ誤差±0.01m|
|ASSET-05|冷蔵庫空→補充→会計→期限切れ|slot overlay状態変更と物理在庫一致|
|DOMAIN-01|physical=1、顧客2人|1人しか予約できず在庫>=0|
|DOMAIN-02|会計event ID再送|金銭/商品数が一回分だけ変化|
|DOMAIN-03|販売と期限切れが同tick|期限切れ優先、売上0|
|DOMAIN-04|広告日境界→セーブ/ロード→同tick|広告/固定費が再請求されない|
|DOMAIN-05|発注/棚補充/3品販売/廃棄|現金/売上原価/廃棄原価に二重控除無し|
|UI-01|BuildPaletteボタン上クリック|背後の店舗の設置/パンが起きない|
|UI-02|レジ0台、棚のみ配置|設置は可能、営業開始は理由付き拒否|
|SAVE-01|顧客予約中save/load|active reservationが再開後一致し売上重複無し|
|SAVE-02|保存書込中断・不正JSON|元のセーブを失わない|
|SCENARIO-01|初期資金50万円/初期店|棚＋レジ＋商品仕入→初売上→日次決算まで完走|

## 7. 性能
- 描画ベンチは**16×12 / 什器20 / 可視客30 / 1920×1080 / ズーム1 / 速度1x**で統一。render FPS平均・median frame・p95 frame、sprite draw calls、simulation step処理時間、VRAM/CPU使用を分離して記録。
- 目標60FPS（約16.67ms/frame）は**製品目標**。達成判定は環境/commit/試行回数/計測結果を添えてから。
- アセット1種類追加のために場面全体をレンダーし直さない。建設/在庫変化のときだけ該当sprite合成を更新。商品組合せ爆発を避ける。
- 実装完了の条件は単体テストのPASSだけではなく、シーン実画面で配置・回転・スプライト合成が破綻しないこと。

### 4.1 Save v1の厳密な入れ子要素
- customers[]: customer_id/phase/position/route/route_index/reservation_ids/patience_remaining_sec/target_fixture_id/checkout_remaining_sec。
- economy: cash_yen, ledger_transactions[] (event_id/event_type/day_index/time_sec/現金・売上・原価・費用差分), unpaid_cost_yen。
- daily_reports[]: day_index, revenue/cogs/gross/wastage/ad/electricity/fixed/operating profit/cash delta/cash balance/reputation/客数と販売個数。
- store_reputation 0..100, product_price_overrides{sku_id→販売価格円}。これらを省略すると保存・ロード完了としない。JSON上の構造は[savegame.schema.json](../schemas/savegame.schema.json)を正とする。
- jsonschemaで表現できない在庫reservation参照・`reserved<=physical`や売上明細整合はDomain validatorで追加確認する。

## 8. Undo/Redo と現金台帳の厳密な関係
- Undo対象は**一続きの配置編集セッション**だけ。`start_business`、`order_stock`、`restock`、`checkout`、`save/load`、日付tickなどの非配置コマンドが走った時点で編集履歴を消去する。
- `place_fixture`のUndoは占有解除と**購入時と同額の設備投資支出の逆仕訳**を原子的に行う（売上/営業利益には含めない）。Redoは配置/現金条件を最新Revisionで再検証して再購入する。
- `move/rotate`は現金0の可逆操作。Redo時も占有衝突チェックを実行する。
- `remove_fixture`のUndoは撤去前のfixtureとstock segment配置を同一セッション内だけ復元し、バックヤード戻しを取り消す。保存/購入/補充/客予約が挟まれば復元不可。
- ledgerの履歴は削除せず、巻き戻しは`REVERSAL`として一意event IDで記録する。cashの純増減は正しく相殺し、冪等性は保持。
- 不可逆の販売/仕入/日次費用を`Ctrl+Z`で戻せない。「元に戻す」の対象外であることをUIツールチップに表示。
- テスト: 9万円のレジ設置→Undoで現金/占有が元通り→Redoで再び9万円支出、続けて仕入操作後はUndo不可。二重返金や負の残高を発生させない。

## 9. 2026-10-23 保存・営業状態の確定
- `business_state`は SETUP/OPEN/CLOSING/PAYMENT_BLOCKED とし、`speed_setting=0`は**時計だけの停止**。
- OPEN+speed0の保存をOPEN+speed0として復元する。CLOSINGは客/予約の状態をそのまま復元して閉店継続。SETUP時には客0/予約0を検証。
- 保存・画面操作・コマンドphaseの詳細は[08](08_RUNTIME_STATE_AND_COMMANDS.md)。LCG32と需給・イベント順は[09](09_DETERMINISTIC_SIMULATION_AND_SAVE.md)。
