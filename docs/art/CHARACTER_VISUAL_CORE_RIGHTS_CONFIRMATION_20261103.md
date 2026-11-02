# コア11件の採用・権利確認（2026-11-03）

ユーザーから、コアパイロット11件について次の明示確認を受領した。

- ゲーム内へ採用してよい
- 小春六花および使用LoRAの利用条件を確認済み

対象は `data/presentation/character_visuals_v1.json` の `core_pilot_ids` に列挙された次の11件だけとする。

`title_background_pilot`, `fullbody_dynamic_201`, `functional_layout_guidance`,
`functional_business_greeting`, `reaction_discovery`, `reaction_deadpan`,
`reaction_first_sale_joy`, `functional_low_stock`, `functional_sold_out`,
`functional_queue`, `event_hot_day`

承認ツールで視覚QA・権利確認・対象IDを検証した後、上記11行のみを
`runtime_approved:true` として通常ランタイムへ接続済みである。元画像は変更せず、
全身画像のバストアップ化は表示時のクロップで行う。

334候補の残り、パイロット台帳の残り39件、その他の小春六花・LoRA素材はこの確認の対象外であり、
引き続きレビュー専用・`runtime_approved:false` とする。これは商用公開や再配布に関する法的判断ではなく、
このゲームの現在の採用範囲を記録するための確認である。

## 通常経路の実画面確認

- `build/title_core_normal_1280.png`: デバッグ用の `--visual-variant` や手動cueなしで、承認済みタイトル背景を表示。背景内の小春六花と独立 `TitleRikka` の二重表示なし。
- `build/title_core_normal_1600.png` / `build/title_core_normal_1920.png`: 1600×900と1920×1080でも、タイトル背景内の小春六花とGodot UIの配置・可読性を確認。
- `build/event_hot_day_core_normal_1280.png`: `--event=evt_hot_day` の発生中だけ、イベントCGと承認済み `event_hot_day` 立ち絵を表示。通常アシスタントとの重複なし。
- `build/event_hot_day_core_normal_1600.png` / `build/event_hot_day_core_normal_1920.png`: 1600×900と1920×1080でも、イベントCG・イベント立ち絵・経営ウィンドウの配置と二重表示なしを確認。
- `build/character_core_normal_1280.png`: 通常画面のアシスタント枠で、元の `1024x1536` 全身PNGを変更せず、表示用のクリップ枠だけでバストアップ表示。吹き出しも左メニュー下の同じ表示レイヤーに収まり、下部メニューと接触しない。
- `build/character_core_normal_1600.png` / `build/character_core_normal_1920.png`: 1600×900と1920×1080でも、表示時クロップ・吹き出し・下部メニューとの間隔を確認。

いずれもGodot 4.7.2のCLIキャプチャで確認し、元の全身PNGは変更していない。
