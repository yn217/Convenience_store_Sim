# MVP受入結果（QA_ACCEPTANCE_PLAN S-01〜S-16）

更新: Issue #25。自動試験は `tools/run_tests.ps1`（headless、固定seed）。**実機で人が操作するE2Eは未実施**で、
下表の「手動」欄は未確認として残している。

## S-01〜S-16

|ID|内容|自動試験（tests/ 配下）|画面・手動|
|---|---|---|---|
|S-01|レジ無しで棚は置ける・営業開始は不可|unit/test_placement_commands::test_no_register_is_still_buildable、scene/test_business_ui、scenario/test_mvp_loop|未実施|
|S-02|1×2棚の90°回転|unit/test_placement_commands::test_1x2_rotates_to_2x1、unit/test_paths_access::test_rotated_shelves_report_their_front_tiles、contract/test_visual_manifests|スクリーンショットで確認（tools/screenshot.gd demo）|
|S-03|通路を塞ぐ配置は拒否|unit/test_paths_access::test_blocking_the_only_corridor_to_the_register_is_refused、scene/test_build_ui::test_corridor_block_is_red_with_a_reason|未実施|
|S-04|補充でバックヤード→棚、現金不変|unit/test_stock_commands、scenario/test_mvp_loop（補充後の現金一致）|未実施|
|S-05|3個×150円の会計（売上/原価/粗利/在庫/現金）|unit/test_sales_ledger::test_cost_100_sell_150_five_units_reconciles、test_green_tea_golden_sequence|—|
|S-06|在庫1個を2人が取り合う|unit/test_customer_ai::test_two_customers_one_unit_only_one_reserves、unit/test_expiry_fefo::test_duplicate_transaction_and_double_reservation|—|
|S-07|期限切れの予約付き食品|unit/test_expiry_fefo::test_checkout_in_the_expiry_step_sells_nothing_and_wastes_once|—|
|S-08|日次締めで二重減算しない|unit/test_daily_report、scenario/test_mvp_loop（現金=台帳合計）|—|
|S-09|今日1000円・翌日2000円の広告|unit/test_advertising::test_new_day_charges_once_whatever_the_speed、scenario/test_mvp_loop|—|
|S-10|行列の待機断念|unit/test_register_queue::test_waiting_past_the_timeout_releases_the_reservation、unit/test_demand_factors::test_queue_giveups_and_stockouts_are_counted_separately|—|
|S-11|保存→再開で一致|unit/test_save_load、scene/test_save_ui、scenario/test_mvp_loop（ロード後の再生が一致）|—|
|S-12|4方向配置・前後に客移動|unit/test_draw_order、scene/test_fixture_sprites、scene/test_customer_sprites|スクリーンショット（build/shot2.png 相当）で確認|
|S-13|パレット操作で背後の店舗が反応しない|scene/test_ui_integration::test_panels_do_not_pass_clicks_to_the_store、scene/test_shell_camera_input::test_ui_panels_do_not_leak_input_to_the_store|未実施|
|S-14|性能（16×12・什器・客30・1920×1080）|tools/perf_bench.gd（下記）|下記|
|S-15|資金不足の拒否と理由|scene/test_onboarding::test_shortage_is_explained_and_nothing_is_taken、scene/test_build_ui::test_not_enough_cash_is_refused、unit/test_stock_commands::test_order_rejections_change_nothing|—|
|S-16|チュートリアル1日目の通し|scene/test_onboarding::test_first_five_minutes_within_the_starting_money|初見プレイは未実施|

## 統合シナリオで見つけた不具合（修正済み）
- **セーブ読込不能（Critical）**: 日次締め後のセーブは、JSONで整数が小数として戻るため daily_reports の検証に落ち、読み込めなかった。
  `DailyReport.errors` を整数値の小数も許す判定に直し、回帰テスト（test_save_load::test_a_closed_day_survives_a_trip_through_the_file）を追加した。
- **性能**: 客30人で約9FPSだった。客AIの毎ステップ再計算（レジ計画・通行不可セル・到達判定・行列枠・予約照会）と描画順ソートがO(n³)だった点を直した（下表）。

## S-14 性能測定（固定条件）
- 条件: 16×12、**什器16基**（20基の配置計画のうち導線/重なりで置けたもの）、店内客30人、(1920, 1080)、ズーム1.0、各速度で600フレーム（ウォームアップ120）、固定seed
- 環境: Windows 10.0.19045 / Intel(R) Core(TM) i9-10900F CPU @ 2.80GHz / NVIDIA GeForce RTX 3090 / Godot 4.7.2-stable (official) / renderer gl_compatibility
- コマンド: `Godot_v4.7.2-stable_win64.exe --path . --resolution 1920x1080 --script res://tools/perf_bench.gd -- docs/qa/perf_result.json`

|速度|FPS 中央値|FPS p95(最悪側)|frame ms 中央値 / p95|draw calls|
|---|---|---|---|---|
|×1|60.0|59.6|16.7 / 16.8|600|
|×2|60.0|32.3|16.7 / 31.0|628|
|×4|60.0|45.9|16.7 / 21.8|628|

- シミュレーション1ステップ: 2.49 ms（客30人・行列待ち主体）、スナップショット生成 1.24 ms、VRAM 117 MB。
- 統合ブランチ(UI/描画最適化をまとめたもの)での実測。走行ごとのばらつきは大きい(同条件で中央値57〜75FPS)。
- 公開のたびに床・壁を全面再描画していたのが p95 スパイクの主因だった(公開フレームで約9ms)。入力が変わったときだけ再描画に変更。中央値はvsync(60FPS)に張り付く。
- 客AIの経路探索をキャッシュ(シミュレーション1ステップ 2.6→1.7 ms)。×1 は p95 16.8ms で目標(16.7ms)にほぼ到達。
- **60FPS（16.7ms）の製品目標は ×1 の p95 でほぼ到達、×2（p95 31ms）・×4（p95 21.8ms）は未達**。走行ごとのばらつきが大きく、×2 の悪化は原因未調査。（×1: 中央値74.6FPS / p95 37.6FPS）。中央値は×1で目標超え、×2・×4は未達。QA計画どおり基準値として記録し、p95の達成とは主張しない。
- 商品スロット座標の事前計算で什器描画 4.9→1.7 ms。presenter の _draw は 約8.4→5.0 ms（compose 2.1 / 客 1.0 / 什器 1.7）。
- 残る主なコスト: compose（描画順ソート）約2ms、p95を押し上げるスパイク（シミュレーション・公開処理の周期的な重さ）。

## ×2 の p95 悪化の調査メモ(未解決)
- 3回走行で ×2 の p95 は 30.1〜33.4 ms(×1 は 17.6〜24.0、×4 は 22.0〜25.1)。再現性あり。
- スナップショット公開フレームに集中(×2 で公開フレームの17%が25ms超、その他は約1%)。速度0では遅いフレームなし。シミュレーション1ステップは約1.1ms、公開呼び出し自体は約3msで、重さは公開後の描画側にある。
- 試して効果がなかった案: CanvasModulate/進行ラベルの書き込みガード、UI更新だけを5Hzに落とす(店ビューは20Hz維持)。
- 追加調査(3回走行、×2 p95 = 27.0 / 33.2 / 28.5 ms): 描画の提出は約9.5ms、描画コール(約620)とオブジェクト(約1430)は遅いフレームと通常フレームで同じ。遅いフレームは全て公開フレーム(ただし全体の約29%が公開フレーム)で、増えるのは process〜描画前のフェーズ(通常5.8ms→公開フレーム11.9ms、公開処理そのものは約3.3ms)。UIコントローラ1つあたり0.3〜1ms、全部外しても11.9→9.5ms。LightGlow/OverlayLayer/SelectionOverlay の再描画は影響なし。
- 最大の継続コストは FixturePresenter(×2で毎フレーム約3.1ms: compose 1.4 / 客 0.7 / 什器 0.8)。非表示にすると process が7.8→4.5ms。
- p95 は vsync 周期(16.7/33.3ms)に量子化されるため、1フレーム落ちるだけで 31ms 台になる。同条件でも 28 と 33 ms に割れ、計測機のバックグラウンドアプリの影響も否定できない。
- 次の一手: 描画コール(約620)と compose の並べ替えを減らし、同一プロセス内プローブで再計測する。
- 試して却下: 同じ什器の隣接セグメントを1回の描画にまとめる案は、かえって遅くなった(什器 0.78→1.0 ms)。さらに、隣り合う列ストリップが半タイル分重なっており、現状の描画は半透明レイヤーをその帯で二重にブレンドしていることが分かった(まとめると 775〜835 ピクセルが変わる)。見た目の既知差として記録。同一ブランチでの別走行では ×2 p95 が 15.7〜15.8 ms の日もあり、計測のばらつきが大きい。

## 再計測(2026-10-24、統合ブランチ 3575c16)
- ×2 の p95 は 3 回走行で 20.65 / 21.75 / 19.68 ms(平均 20.7)。以前の 27〜33 ms は再現せず、計測機の負荷(他アプリ)で変わる可能性が高い。目標 16.7 ms にはまだ届かないが、差は約 3〜5 ms。
- 公開処理を3フレームに分割する案(世界→UI前半→UI後半)は、p95 が 20.7→18.9 ms(ばらつき 2〜4 ms の範囲内)で、有意とは言えず不採用。パッチは保管のみ。
- 結論: p95 目標の判定には、他アプリを止めた静かな状態での複数回計測が必要。
## スクリプトによる初見プレイ通し(実描画, 2026-10-24)
- `tools/e2e_firstplay.gd`(Godot --path . --resolution 1920x1080 --script res://tools/e2e_firstplay.gd -- build/e2e)。空の店 → レジ/棚/冷蔵ケース設置 → 発注 → 補充 → 営業開始 → ×4で1日目を通す → 翌日。
- 結果: 全コマンド成功、1日目に36人が購入し日報1件、翌日(DAY 1)へ。段階ごとのスクリーンショットを `build/e2e/` に出力(06 夜、07 翌日など)。在庫が午前中に尽き、低在庫カードが出る様子を確認。
- これは人手の初見プレイや Windows 実機での確認の代わりではない(それらは未実施のまま)。

## 既知の問題
- 図形は箱ベースの仮アセット（#12 で差し替え予定）。モックアップとの見た目の差は、別途比較して調整する。
- 人手による初見プレイ・Windows実機の通しE2Eは未実施。
- BGM・環境音は未実装。効果音はコード合成で、初期状態はミュート。

## 正面出入口（南壁）への移動と計測条件の変更(2026-10-24、feature/m12-front-entrance)
- 新規ゲームの出入口を西壁(0,5),(0,6)から南壁(8,11),(9,11)へ移動。保存データは各自の出入口を保持するため、旧セーブはそのまま読める。
- 正面は低い切り欠き型: 腰壁(0.45 m)・窓枠(1.0 m まで)・薄い看板帯(1.0〜1.2 m)のみ。出入口は開口、マットあり。
- 計測用の什器配置の変更(tools/perf_bench.gd, tools/capture_screen.gd のみ。ゲームデータは変更なし): 出入口の前の (7,11) にあった shelf_snack を (12,11) へ移動し、出入口前の列を通路として空けた。什器数(20)・客数(30)・解像度・速度は従来どおり。
- x1 の計測(1920x1080, 600フレーム, 3回ずつ、同一マシン):
  - 移動前(a64213d, 西壁): median 20.9 / 18.1 / 17.7 ms, p95 36.2 / 30.5 / 30.0 ms
  - 移動後: median 17.4 / 17.4 / 20.5 ms, p95 29.0 / 37.4 / 35.4 ms
  - 同一コードでも走行差が大きく(median 17.7〜20.9 ms)、差は計測ノイズの範囲内。
- テスト: tests/run_all.gd で tests=472, failures=0, SCRIPT ERROR 0。

## 計測用レイアウトの変更(sample_store_v1, feature/m13-sample-layout)
- 計測・スクリーンショットの配置を、ハードコードの PLAN から `data/layouts/sample_store_v1.json` に変更(tools/sample_layout.gd が読む。ファイルが無ければ旧 PLAN にフォールバック)。ゲームデータ・初期状態・経済は変更なし。
- **注意: 配置数と位置が変わった。** 旧配置は 20 基のうち **16 基しか置けていなかった**(上の S-14 表の「什器16基」)。新配置は 20 基すべて置ける(tests/unit/test_sample_layout.gd で検証、全アクセスタイルが入口から到達可能)。したがって新旧の結果は厳密には比較できない。新配置は条件「什器 20 基・客 30 人」を初めて満たす。
- 設計意図とマップ: docs/design/SAMPLE_STORE_LAYOUT.md。スクリーンショット: docs/qa/screens/sample_layout_normal.png, sample_layout_z16.png (--hour=12 --calm)。
- 計測条件: 16×12、什器 20 基(fixtures_placed=20)、客 30 人前後(customers_in_store 29〜30)、1920×1080、ズーム1.0、600フレーム(ウォームアップ120)、×1/×2/×4。走行結果は docs/qa/perf/sample_layout_v1_run{1,2,3}.json。

| 走行 | ×1 median / p95 (ms) | ×2 median / p95 (ms) | ×4 median / p95 (ms) | sim 客 | VRAM |
|---|---|---|---|---|---|
| 1 | 26.1 / 44.9 | 26.3 / 39.1 | 42.0 / 63.4 | 30 | 130.9 MB |
| 2 | 23.4 / 45.6 | 22.7 / 35.9 | 33.7 / 47.4 | 29 | 130.9 MB |
| 3 | 18.6 / 30.0 | 24.7 / 40.9 | 32.0 / 42.7 | 30 | 132.9 MB |

- FPS 中央値: ×1 38.3 / 42.7 / 53.8、×2 38.1 / 44.1 / 40.5、×4 23.8 / 29.7 / 31.3。
- 走行差が大きく(×1 の median 18.6〜26.1 ms)、目標 16.7 ms(60FPS)には未達。p95 目標の判定には静かな環境での複数回計測が必要。
- 本計測は 16 基配置の旧結果と条件が異なるため、前後比較の結論は出さない。
