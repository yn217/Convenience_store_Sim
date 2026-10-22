# 仕様レビュー記録 — 2026-10-22

対象: [GAME_DESIGN_SPEC](GAME_DESIGN_SPEC.md), [IMPLEMENTATION_TASKS](IMPLEMENTATION_TASKS.md), MVP Issue #1〜#25。
分類: **P0** = 実装前に解消必須、**P1** = MVP完成前に必要、**P2** = 将来拡張。
本レポートは**仕様書とIssueのレビュー**。ゲーム実装/実機性能のレビューではない。

## 指摘・対応
|重要度|指摘|判断・対応|参照|
|---|---|---|---|
|P0|2.5Dの128×64投影とBlenderカメラの一致が曖昧|2:1菱形（ゲーム用ディメトリック）と校正条件、4方向・anchor・座標回転を規格化|ASSET_PRODUCTION_SPEC / Issue #4 #8|
|P0|背の高い什器やガラスと客/商品の前後合成が不足|本体・商品・ガラス等を分離、必要ならレンダーセグメント、目視テスト|ASSET_PRODUCTION_SPEC / Issue #9 #12|
|P0|在庫に応じて実商品が増減する画像合成方法が不明|SKU×回転×数量を全焼込み禁止、slot overlay＋LODによる更新|ASSET_PRODUCTION_SPEC / Issue #12|
|P0|空店舗にレジ無しだがレジ経路が設置必須の矛盾|レジ未設置でも建設可能、営業開始時だけレジ到達必須|SIMULATION_ECONOMY_SPEC / Issue #6 #7|
|P0|複数顧客予約、廃棄、会計時の競合規則が曖昧|lot予約、期限切れ優先、会計確定時原子反映、冪等event ID|SIMULATION_ECONOMY_SPEC / Issue #13 #15 #17|
|P0|広告の当日/翌日変更が曖昧で二重請求リスク|翌日設定、日開始1回請求、seed固定の再現性|SIMULATION_ECONOMY_SPEC / Issue #18|
|P1|什器ごとの寸法/パーツ/レンダー処理・商品種が不足|10種類の制作カタログと24SKU表を新設|ASSET_CATALOG / Issue #22|
|P1|価格による需要、品揃え、評判のゲーム上の意味が不足|仮の需要・評判・品揃え計算ルール追加|SIMULATION_ECONOMY_SPEC / 新Issue|
|P1|経営の目標、初回導線、失敗時の回復策がない|チュートリアルと営業開始条件/支払不能UIを規定|GAMEPLAY_UX_SPEC / 新Issue|
|P1|保存中の会計/広告日境界、回帰・画面テスト不足|安全tick/予約/日次イベントIDを保存、16本のQAシナリオ|SIMULATION_ECONOMY_SPEC, QA_ACCEPTANCE_PLAN / Issue #20 #25|
|P1|外部素材やAI画像の利用条件の追跡方針が無い|ASSET_CREDITSを台帳として作成、商標類似チェックをルール化|ASSET_CATALOG / 新Issue|
|P2|複数店舗、配送遅延、員工シフト、天候、フランチャイズ|MVP非対象、拡張候補として維持|GAME_DESIGN_SPEC|

## 基本設計の維持
- Godot 4 + GDScript、実行時2Dスプライト、制作時Blender、固定カメラ、論理直交タイルの方式は継続。
- MVP 8カテゴリ×3SKU、初期什器10種、16×12店舗、ローカル保存、時間速度切替を継続。
- 仮値と確定契約を明確化。価格・初期資金・高さ・sprite pixel anchorはバランス/アセット検証まで仮。
- 本レビューではコード実装・ゲーム実行・実機ベンチは未実施。

## 維持管理のルール
- [GAME_DESIGN_SPEC](GAME_DESIGN_SPEC.md) を総合仕様の入口とし、新規各文書を**詳細仕様の規範**として参照する。
- 詳細仕様と既存Issueの記述が競合する箇所（例：レジ経路チェック）は、後からの詳細仕様を優先し、対応Issueへ加筆する。
- 仕様の増築により検証できない巨大Issueを作らない。P0は既存の関係するIssueの完了条件へ明示的に反映する。
- 新Issueを作ったら [IMPLEMENTATION_TASKS](IMPLEMENTATION_TASKS.md) と親Issue #1をリンク付きで更新する。
