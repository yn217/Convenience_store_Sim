# fridge_drink FULL/r0 — model_swap_v1

built-in image_genでケース本体・透明扉・棚・飲料商品をまとめた透過2D完成スプライトを2案生成しました。入力画像は両案ともcanonicalの `assets/generated/fixtures/fridge_drink/fridge_drink_0_body.png` のみです。商品を後貼りしていません。

| 案 | 陳列 | 長辺傾き | canonical bboxとの差（left, top, right, bottom） |
|---|---|---:|---:|
| A | 緑茶・炭酸・水の混合色 | −0.4915 | −1, −1, −2, +18 px |
| B | SKU色別のまとまり | −0.4906 | −3, −2, +6, +10 px |

候補画像はどちらも442×527px、r0、iso2x_v1です。anchorとsorting anchorは(285,380)。3段に緑茶・炭酸飲料・ミネラル水の500mlボトルを並べ、ガラスの反射は弱く抑えています。ラベルは架空の葉・柑橘・水の図柄とSKU色で見分けられます。商品カタログは `data/products/mvp_v1.json` で確認しました。

画像：`fridge_drink_full_r0_candidate_a.png`、`fridge_drink_full_r0_candidate_b.png`。原本は `original_a.png`、`original_b.png`（各1148×1370px）。正規化は画像全体の一様縮小と透明キャンバス配置のみで、クロップ、変形、商品ごとの合成、背景除去はしていません。

`comparison_same_scale.png` は左からcanonical、A、Bを442×527px・1:1で表示します。ピンクの十字はcanonical anchor位置です。チェッカー柄は比較画像だけの表示背景です。数値は `qa_metrics.json`、目視所見は `qa_visual.json`、生成条件と原本パスは `generation_manifest.json` と `generation_provenance.json`、プロンプト本文は `prompt_a.txt` と `prompt_b.txt` に保存しています。

生成画像は基準の投影角度に近い一方、alpha>8の全体bboxは基準から最大18pxずれています（Bは最大10px）。anchorメタデータは維持していますが、画像内の足元への厳密なランドマーク登録を保証するものではありません。QAは画像寸法・透過・傾きと目視に限定し、フルテストは行っていません。既存ファイルへの上書き、ゲーム組み込み、コミット、pushは行っていません。
