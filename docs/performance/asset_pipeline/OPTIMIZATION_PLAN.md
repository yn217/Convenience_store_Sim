# 高速化計画（品質ゲートを維持）

期待短縮値は未測定のため数値を置かない。最初の改善サイクルでbaselineと比較する。

## P0 — 低コスト・先に適用

| 対策 | 対象 | 方法 | コスト/リスク |
|---|---|---|---|
| 工程タイマーとrun ID | 全T01–T16 | 付属measurement loggerで開始/終了、agent、結果をJSONL化。ImageGenは要求から完了までとし、内部推論時間を推測分解しない。 | 低。入力漏れは残る。 |
| Generation前の仕様 lint | T01/T02/T03 | 目標/正本/geometry_versionを確認し、#157 ambient gondolaでは屋根付きreference/cap promptをHard stop。 | 低。誤った基準の再生成抑止。 |
| 生成直後の自動検査 | T04/T05/T07 | alpha bbox threshold、投影傾き、canvas/anchor、行数、透明ノイズを自動で早期検査。閾値は品質仕様に従う。 | 低〜中。自動PASSだけで視覚採用しない。 |
| 出力受渡し契約 | T16 | run directory、prompt、source、output path、SHA256、採否を成果報告に必須化。 | 低。agent重複生成を避ける。 |
| captureを独立計時 | T11/T12 | 起動、ready待ち、撮影・保存を別イベントにする。 | 低。過去プロセスの混在を解消。 |

## P1 — baseline後に実施

- 同一入力で画像処理だけの小規模反復を計時し、Python package/normalizer/QA時間を確認。
- package、manifest、比較sheet作成を一つの再実行可能なCLIにまとめ、既存出力hashが一致すれば再生成を省く。
- 再生成理由を角度/構造/alpha/画風/欠落・受渡し等に分類し、原因別prompt/reference変更を記録する。
- Godot capture runnerのプロセス全体をready/import/capture/saveに分ける。フルテストは行わず、対象画像・対象sceneに関係する限定検証だけ。
- Agent担当は成果物が互いに依存しない範囲で並列化。形状正本が承認される前のカテゴリ量産は行わない。

## P2 — 大きな変更

- アセットrun manifestから生成→処理→Godot QA→PR evidenceを追跡するpipeline orchestrator。
- QA合格後の状態画像派生を本体固定マスクから生成し、全状態の棚本体再生成を避ける。ただし最新の#157形状承認後に限定。
- 複数assetの同一Godot session内captureによる起動コスト共有。並列化との競合・メモリ使用を測定してから採否判断。

## 改善効果の報告ルール

各対策のBefore/Afterを同じasset class、同一QA条件で測定する。測定前に短縮率を確定値として約束しない。品質NG率または欠陥数が悪化した場合、速度改善として採用しない。
