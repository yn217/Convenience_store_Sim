# 次回立ち絵レビュー候補（2026-11-03）

コア11件の次に確認しやすいよう、Issue #230の対応表で `P1`、かつ既存の
Godot表示ルートへ接続済みの未承認候補から11件を抽出した。

この一覧はレビュー順の提案であり、採用承認ではない。全行は現在も
`runtime_approved:false` のままで、通常ビルドには表示されない。

レビューシート: `build/character_pilot_remaining_contact_20261103.png`

| asset ID | kind | screen | trigger | 次に確認する理由 |
| --- | --- | --- | --- | --- |
| `functional_opening_checklist` | functional_pose | SCR-06 | `tut_07` | 開店前チェックのチュートリアル導線 |
| `functional_register_guidance` | functional_pose | SCR-06 | `tut_02` | レジ設置案内の基本ポーズ |
| `functional_restock_guidance` | functional_pose | SCR-06 | `tut_05` | 商品補充案内の基本ポーズ |
| `functional_order_help` | functional_pose | SCR-06 | `tut_04` | 仕入れ説明の基本ポーズ |
| `functional_expiry` | functional_pose | SCR-07 | `order_help` | 期限切れ通知の運用ポーズ |
| `functional_rival_store` | functional_pose | SCR-09 | `business_started` | ライバル店イベントの差分候補 |
| `functional_staff_short` | functional_pose | SCR-11 | `evt_snack_buzz` | スタッフ不足リアクションの専用立ち絵 |
| `functional_first_profit` | functional_pose | SCR-06 | `tut_07` | 初黒字・達成演出の立ち絵 |
| `functional_day_report` | functional_pose | SCR-11 | `evt_roadworks` | 日次決算の通常結果ポーズ |
| `functional_campaign` | functional_pose | SCR-12 | `ms_first_sale` | 販促キャンペーンの機能ポーズ |
| `event_roadworks` | event_image | SCR-11 | `evt_roadworks` | 日替わりイベント画像の代表候補 |

## 確認項目

- 白ブラウス、紺エプロン、双団子、靴まで欠落していないこと
- 手・指・手首・腕の接続に明らかな破綻がないこと
- 透過派生で袖・エプロン・髪・手の内部が抜けていないこと
- 生成画像内の文字・吹き出し・記号をゲームUIと二重表示しないこと
- 実画面で左メニュー、吹き出し、下部メニュー、操作領域を隠さないこと
- 小春六花・LoRAの利用条件を確認済みの採用範囲に含めること

視覚確認と権利確認が完了し、明示的な承認があるまで、台帳の
`approval_state` と `runtime_approved` は変更しない。

## 代表ルートの実画面キャプチャ

次の3ルートをGodot 4.7.2の非headless CLIで1280x720撮影した。

- `build/character_pilot_next_expiry_1280.png` — `expiry_notice` → `functional_expiry`
- `build/character_pilot_next_campaign_1280.png` — `seasonal_campaign_started` → `functional_campaign`
- `build/character_pilot_next_rival_1280.png` — `rival_opened` → `functional_rival_store`

3件とも `--inspect-pilot` で1024x1536のruntime texture選択、legacy表示なし、
イベント側の重複表示なしを確認した。未インポート小物を安全にスキップする
`PropSprites` の防御を追加したため、現在のfocused runtime testではloader warningは
発生しない。

## コア採用後の追加実画面確認

- `build/character_pilot_event_hot_day_screen_1280_latest.png` — `--screen=経営 --event=evt_hot_day`
  で、承認済み `event_hot_day` がイベント管理画面の専用枠に表示されることを確認。
- `build/character_pilot_business_opening_1280_fixed.png` — `--opening` で開店カットイン中の
  左下アシスタントを抑止し、中央の開店演出だけが表示されることを確認。
- `event_ui`: 4 tests / 51 assertions / 0 failures。
- `character_art`: 14 tests / 332 assertions / 0 failures。

開店カットインの重複抑止は `80372cf4`、未インポート小物の防御は `d4d0d7f0` に記録した。

## 追加レビューキャプチャ（2026-11-03）

次の未承認候補を、通常ビルドではなくCLIのレビュー用cueで確認した。

- `build/character_pilot_review_opening_checklist_setup_1280.png` — `--setup --pilot-cue=opening_checklist`
- `build/character_pilot_review_expiry_1280.png` — `--screen=商品 --pilot-cue=expiry_notice`
- `build/character_pilot_review_rival_1280.png` — `--pilot-cue=rival_opened`

3件とも `stage_visible=true`、指定した1024x1536の派生PNG、legacy立ち絵非表示、
操作領域を覆わない配置を `--inspect-pilot` で確認した。開店前チェックは `--setup` で
右上の「開店までの手順」と同時に確認し、期限切れ・ライバル店も左メニュー下のレビュー枠へ
収まることを確認した。これは視覚QAの記録であり、3件の `runtime_approved` は変更していない。

## 追加のイベントレビュー（2026-11-03）

- `build/character_review_event_roadworks_1280.png` — `--screen=経営 --event=evt_roadworks`

工事CGと未承認 `event_roadworks` 立ち絵が経営画面の専用行に収まり、イベント本文・操作UIを
隠さないことを確認した。これはレビュー専用キャプチャであり、`event_roadworks` の
`runtime_approved` は変更していない。

## 追加の日替わりイベントレビュー（2026-11-03）

- `build/character_review_event_after_work_1280.png` — `evt_after_work`
- `build/character_review_event_bread_feature_1280.png` — `evt_bread_feature`
- `build/character_review_event_cold_day_1280.png` — `evt_cold_day`

3件ともイベントCGと未承認立ち絵が経営画面の専用行に収まり、イベント名・効果・操作UIを
隠さないことを確認した。いずれもレビュー専用キャプチャであり、`runtime_approved` は変更していない。

## 通常営業3解像度の配置確認（2026-11-03）

- `build/character_core_normal_lowered_1280.png` — 1280x720
- `build/character_core_normal_lowered_1600.png` — 1600x900
- `build/character_core_normal_lowered_1920.png` — 1920x1080

通常営業の同一表示を3解像度で確認した。小春六花の表示時クロップとメッセージ枠は、左メニューの下から
下部メニュー直上までの表示域に収まり、下部メニューとの接触・重なりがない。元の全身画像ファイルは
変更せず、表示時だけ `AssistantPilotBustupCrop` で切り抜く仕様を維持している。

## 未承認39件の次回レビュー準備（2026-11-03）

- `build/character_pilot_remaining_contact_20261103.png` — 未承認39件の読み取り専用コンタクトシート
- 内訳: `functional_pose` 26件、`event_image` 10件、`bustup_reaction` 2件、`fullbody` 1件
- 一覧にはruntime画像、論理asset ID、kind、`approved=false`を併記している

コンタクトシートでは双団子・制服・全身枠の大枠を比較できるが、これだけで通常採用を確定しない。
次回の個別確認では、機能ポーズは手指・商品接触・腕の接続、イベント画像はイベント内容の視認性、
リアクションは顔の切れ・吹き出し記号の独立レイヤー化、全身画像は足元と表示時クロップを確認する。
このレビュー準備では、元画像・派生PNG・レジストリの承認状態を変更していない。

## 未承認39件の採用ゲート検証（2026-11-03）

`tools/assets/approve_character_pilot.py` を未承認39件へドライランで実行した。
全39件でruntime/source/derived/fallbackの参照検証が成功し、レジストリ変更なしで終了した。
実際の承認には、対象IDを明示した `--apply` と、目視QA・権利確認の両方が必要である。

## 機能イベントの追加レビュー（2026-11-03）

- `build/character_review_staff_short_1280.png` — `story_staff_short` / `functional_staff_short`
- `build/character_review_first_profit_1280.png` — `story_first_profit`（専用立ち絵と反応レイヤーの組み合わせ）
- `build/character_review_campaign_1280.png` — `seasonal_campaign_started` / `functional_campaign`

スタッフ不足、初黒字、販促提案の3画面で、立ち絵を下部メニュー直上の表示枠へ配置して確認した。
いずれもレビュー専用キャプチャであり、未承認候補の `runtime_approved` は変更していない。

## 日次レポート表示の回帰確認（2026-11-03）

日次レポートを開く直前に短時間の画面cueが残っている場合でも、日次レポート中は
`functional_day_report`（赤字時は `functional_day_end_review`）を優先するよう表示ルートを修正した。
focused runtime testでは、古い `functional_empty_handed` が残らないこと、日次レポートの
立ち絵とメッセージが表示枠を維持することを確認した。修正対象の候補は引き続き未承認である。

決定的な日次レポートキャプチャでは、営業開始カットインを後処理で終了させるよう
`tools/capture_screen.gd` も補正した。`build/character_review_day_report_1280_fixed2.png` で、
日次レポートカードと「今日もお疲れさまでした」のメッセージ、立ち絵が下部メニュー直上に
同時表示されることを確認した。

## タイトル背景の通常ルート確認（2026-11-03）

- `build/title_core_1280.png` — 1280x720、承認済み `title_background_pilot`
- `build/title_core_1920.png` — 1920x1080、承認済み `title_background_pilot`

タイトル文字・実ボタン・お知らせUIをGodot側で描画し、画像内のメニュー文字との二重表示がないこと、
背景に含まれる小春六花と別立ち絵を重ねていないことを確認した。

## 全50件の遅延ロード計測（2026-11-03）

`tools/measure_character_pilot_load.gd --all-pilot` をGodot 4.7.2の実レンダラーで実行した。

- 50/50件が読み込み成功
- 全身・イベント画像は1024x1536、リアクションは1024x1024、タイトル背景は1344x768
- 50件を順次ロードした合計時間: 6376.363ms
- 1件あたりの最大ロード時間: 1934.777ms（`event_bread_feature`）
- ビデオメモリ: 6.12MB → 最大29.96MB
- 承認状態は変更していない（`all_runtime_approved=false` は未承認候補を含む全件計測の結果）

これは全件を常駐ロードする実装ではなく、候補ファイルの欠落とロード負荷を測る読み取り専用計測である。

## 機能案内ポーズの追加レビュー（2026-11-03）

- `build/character_review_order_help_1280.png` — `order_help` / `functional_order_help`
- `build/character_review_restock_help_1280.png` — `restock_help` / `functional_restock_guidance`
- `build/character_review_register_1280.png` — `story_register` / `functional_register_guidance`

3件とも発注・補充・会計案内の実画面で、立ち絵と吹き出しが左メニュー下かつ下部メニュー直上に収まり、
管理画面の操作領域を覆わないことを確認した。レビュー専用キャプチャであり、
3件の `runtime_approved` は変更していない。

## 追加の日替わりイベントレビュー（続き、2026-11-03）

- `build/character_review_event_local_fair_1280.png` — `evt_local_fair`
- `build/character_review_event_sweets_spotlight_1280.png` — `evt_sweets_spotlight`
- `build/character_review_event_lunch_pick_1280.png` — `evt_lunch_pick`

3件ともイベントCGと未承認立ち絵が経営画面の専用行に収まり、イベント名・効果・操作UIを
隠さないことを確認した。いずれもレビュー専用キャプチャであり、`runtime_approved` は変更していない。
