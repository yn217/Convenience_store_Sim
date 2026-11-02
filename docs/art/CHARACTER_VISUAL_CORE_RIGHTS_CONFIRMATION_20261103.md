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
