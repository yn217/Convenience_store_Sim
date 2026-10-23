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
|×1|60.0|50.8|16.7 / 19.7|597|
|×2|60.1|38.1|16.7 / 26.2|619|
|×4|50.9|32.7|19.6 / 30.5|629|

- シミュレーション1ステップ: 2.49 ms（客30人・行列待ち主体）、スナップショット生成 1.24 ms、VRAM 117 MB。
- 統合ブランチ(UI/描画最適化をまとめたもの)での実測。走行ごとのばらつきは大きい(同条件で中央値57〜75FPS)。
- 公開のたびに床・壁を全面再描画していたのが p95 スパイクの主因だった(公開フレームで約9ms)。入力が変わったときだけ再描画に変更。中央値はvsync(60FPS)に張り付く。
- **60FPS（16.7ms）の製品目標は p95 では未達**（×1 p95 19.7ms=50.8FPS。×2・×4 はさらに悪い）（×1: 中央値74.6FPS / p95 37.6FPS）。中央値は×1で目標超え、×2・×4は未達。QA計画どおり基準値として記録し、p95の達成とは主張しない。
- 商品スロット座標の事前計算で什器描画 4.9→1.7 ms。presenter の _draw は 約8.4→5.0 ms（compose 2.1 / 客 1.0 / 什器 1.7）。
- 残る主なコスト: compose（描画順ソート）約2ms、p95を押し上げるスパイク（シミュレーション・公開処理の周期的な重さ）。

## 既知の問題
- 図形は箱ベースの仮アセット（#12 で差し替え予定）。モックアップとの見た目の差は、別途比較して調整する。
- 人手による初見プレイ・Windows実機の通しE2Eは未実施。
- BGM・環境音は未実装。効果音はコード合成で、初期状態はミュート。
