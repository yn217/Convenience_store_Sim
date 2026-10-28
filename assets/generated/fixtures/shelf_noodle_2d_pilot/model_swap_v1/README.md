# shelf_noodle FULL/r0 — model_swap_v1

image_genによる透過2D完成スプライトの新規2案。棚と商品を一体で生成した平面RGBA画像で、3Dモデルではありません。既存ファイルの置換、ゲームへの組み込み、コミット、pushは行っていません。

## 最終候補

| 案 | 画像 | 陳列 | 段数 | 長辺傾き Δy/Δx |
|---|---|---|---|---|
| A 修正版 | `shelf_noodle_full_r0_candidate_a_refined.png` | 赤・黄・緑の自然な混在 | 5 | -0.509445 |
| B 修正版 | `shelf_noodle_full_r0_candidate_b_refined.png` | 隣接する味ごとの色ブロック | 5 | -0.520390 |
| canonical empty | `canonical_empty_reference.png` | 空棚・投影ガイド | 棚板5枚 | -0.505925 |

画像はいずれも1202×1308px。最上面1段と下側4段に、側面ラベルが見えるカップ麺を陳列しています。背景の実透過を計測済み。輪郭外のアルファは0で、alpha>8の画素はキャンバス外周に接しません。余分な囲い箱は追加されていません。

**生成候補として保存。canonicalの寸法への厳密一致は未確認で、採用済みではありません。** 棚の傾きは先行パイロットの診断範囲[-0.53,-0.47]に入りましたが、これは厳密な寸法・全頂点一致の証明ではありません。Aが角度としてはcanonicalに近い候補です。画像全体のbboxには最上段商品が含まれるため、空棚bboxとの縦横比差を棚自体の寸法差と同一視できません。

## 生成と改善

1. 現在の作業ツリーには先行パイロットがなかったため、ローカルに存在する`origin/codex/combined-shelf-2d-pilot`の既存記録だけを参照してcanonicalを特定。ブランチ切替・既存候補の復元は実施していません。
2. canonical empty bodyを直接参照してA初回を生成。側面ラベルは良好ですが、最上面が空き4段でした。
3. 実画像を確認し、B初回では最上面への陳列を明示。最上面は埋まりましたが下段が1枚減り、4段・角度不一致となりました。
4. A初回を編集対象にし、canonicalも再入力。下側4段を維持したまま最上面にカップだけを追加し、A修正版で5段化を確認しました。
5. A修正版の5段構成を維持し、味の色を隣接グループ化してB修正版を生成。5段を確認しました。

すべての初回原本・修正版・プロンプトを保存しています。生成原本に対して切り抜き・背景除去・回転・剪断・非一様拡縮・形状補正を行っていません。比較画像と検査用JPEGの表示に限り、一様縮尺と背景合成を使っています。生成された内部アルファは主に252〜254で、原本のまま保持しています。

## 保存ファイル

- 最終画像2点：`shelf_noodle_full_r0_candidate_{a,b}_refined.png`
- 初回画像2点：`shelf_noodle_full_r0_candidate_{a,b}.png`
- プロンプト4点：`prompt_a.txt`、`prompt_b.txt`、`prompt_a_refined.txt`、`prompt_b_refined.txt`
- 最終比較：`comparison_canonical_a_b_final.png`（左canonical、中央A、右B。比較用の一様縮尺）
- 初回比較：`comparison_canonical_a_b.png`
- 最終数値QA：`qa_metrics_final.json`、最終目視QA：`qa_visual_final.json`
- 初回QA：`qa_metrics.json`、`qa_visual_initial.json`
- 入力参照コピー：`canonical_empty_reference.png`
- 生成の追跡情報：`generation_manifest.json`、`session.json`、`iteration_notes.md`
- A修正版の確認画像：`candidate_a_refined_inspection.jpg`（背景付きの確認専用画像）
- QA再現手順：`python measure_and_compare.py --refined`。画像の寸法・透過・傾き・ハッシュと比較画像だけを生成するローカルQAです。
- ファイルハッシュ：`SHA256SUMS.json`

独立レビュー・Issue対応・ゲーム全体のテストは行っていません。最終候補の画像確認と限定した画像QAだけを実施しました。
