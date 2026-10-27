# サブエージェント並列化分析

## 観測できること

- Agentのturn/sessionログにはturn開始・完了や一部 tool event が残る。該当turn durationはエージェント全体の壁時計区間で、コンテキスト読込・実作業・tool待ち・無活動を区別しない。
- Aの追加画像案はagentで生成されたが、親の最終回答で保存場所を確認できず、親側が別案を生成。これは並列化の成果受渡し失敗で、agent時間の総量や無駄時間は計測できない。
- BのHVAC二候補はImageGen時刻が重なる。並列実行は確認できるが、makespanの短縮率や候補統合コストは不明。
- Case Cの複数カテゴリはcommit履歴に複数callが並ぶが、同時性は記録されていない。commit時刻を実行時刻に読み替えない。
- 現状、agent別稼働時間・待機時間・再指示時間・統合時間・speedupはいずれも不明。

## Critical path

厳密なduration付き依存グラフは作れない。成果物依存から分かる定性的経路:

`仕様/参照の確定 → prompt・入力 → 生成 → 検査 → 必要時再生成/補正 → package → Godot統合 → capture → Visual QA → 採用`

別エージェントで独立並列化できるのは、参照/プロンプトlint、既存データ監査、カテゴリごとの独立画像案、画像処理スクリプトQAなど。ただし形状正本が未承認の棚でカテゴリ量産を並列化すると、誤った基準を複製し手戻りを増やす。#157 STOPに従い、新OPEN EMPTYの形状承認が先。

## 次サイクルの担当分離

1. **Spec/Reference**: Issue、正しい目標画像、形状ゲート、prompt禁止語を確定。
2. **Generation**: 形状ゲート通過後、run ID付きで一候補を生成。入力・prompt・出力ファイルを同一フォルダへ置く。
3. **Image QA**: generation担当から独立して参照正当性、投影、alpha bbox、密度を確認し、判定理由を記録。
4. **Integration**: 合格画像のみpackage/Godotへ。画像生成中に別コード・証拠整理を進める。
5. **Parent/integrator**: 統合・Issue/PR更新を追跡し、各依存の開始/完了をログに残す。

Agentごとに`agent_id`, `task_id`, `run_id`, `phase`, start/endを記録し、親のready/await、handoff開始/完了も記録する。時刻だけではactive effortが測れないため、待機理由・active intervalは別途記録する。継続稼働はツール/セッションの実状態に依存し、完了済みagentを常時保持できるとは限らない。新しい依頼では担当・成果物・前回run IDを明示して再開する。
