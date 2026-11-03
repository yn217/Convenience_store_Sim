# Gameplay UI mockups — 小春六花 / Issue #143 #137 #133 (2026-10-31)

このフォルダは **1画面1枚** のゲームUIモックアップ（デザイン検討用）です。実装済みの画面や動作の証拠ではありません。画像に描かれた数値・操作・店舗状態はサンプルです。

## Images

| PNG | 関連Issue | 画面の狙い |
| --- | --- | --- |
| [staff_fatigue_rest.png](staff_fatigue_rest.png) | [#143](https://github.com/yn217/Convenience_store_Sim/issues/143) | 店員ごとの疲労、担当作業、控え室の利用、休憩指示 |
| [promotions_bundle_coupon.png](promotions_bundle_coupon.png) | [#137](https://github.com/yn217/Convenience_store_Sim/issues/137) | おにぎり・飲料等のセット割、クーポン、粗利・販促条件の操作案 |
| [lifestyle_hygiene_section.png](lifestyle_hygiene_section.png) | [#133](https://github.com/yn217/Convenience_store_Sim/issues/133) | 衣料品・生活雑貨・衛生用品の売場追加案 |

3点とも元画像のまま保存（1672×941 px PNG）。小春六花のキャラクター案内と2.5D店舗を共通UIの基準とし、右側に各機能の操作パネルを置いています。

## Review notes

- **#143**: 実際の職務割当・疲労/休憩ルール、控え室S/M/Lに整合させる。対象機能は未実装の場合がある。
- **#137**: セット割・複数商品購入は [#128](https://github.com/yn217/Convenience_store_Sim/issues/128) に依存。会計・粗利・クーポンは概念図であり、未実装の取引を実装済みとみなさない。
- **#133**: 初期対象は衣料品・衛生用品。OTC医薬品販売を許可・人員・法規の確認なしに描写・実装しない。
- 採用前に現在のGodot実画面と同じ解像度で比較し、可読性、操作領域、重なり、HUDの整合性を評価する。
- 既存画像・実装・アセットは変更しない。モックアップの正式採用・mainマージ・実装は別途レビューする。
