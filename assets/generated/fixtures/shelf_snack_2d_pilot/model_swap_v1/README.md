# shelf_snack FULL/r0 — model_swap_v1

image_genで棚と商品を一体生成した2案。入力画像は指定のcanonical空棚1枚のみ。SKUカタログのポテトスナック・板チョコ・グミを参照し、袋・薄い包装を描画。商品カードの後置き合成や商品3Dモデルは使用していません。

## 提出物

- A: `shelf_snack_full_r0_a_delivery.png`（初回Aを選択）
- B: `shelf_snack_full_r0_b_delivery.png`（4段陳列の初回Bを選択）
- 比較: `comparison_delivery.png`（左canonical、中央A、右B。背景格子は比較画像のみ）
- 原本: `a_generated_raw.png`, `b_generated_raw.png`。除外ラウンドの原本も保存。
- プロンプト: 最終Aは `prompt_a.txt`、最終Bは `prompt_b.txt`。全試行のプロンプトを保存。
- 数値QA: `qa_metrics_delivery.json`、目視QA: `qa_visual_delivery.json`、輪郭比較: `qa_overlay_a_delivery.png`, `qa_overlay_b_delivery.png`
- 入力・生成来歴: `canonical_contract.json`, `sku_reference.json`, `generation_manifest.json`

## QA

両案442×465px RGBA。指定anchorは(285,318)。全体を一様に縮小・移動し、canvasと下端を合わせています。**画像内容の棚寸法・全棚板座標・world anchorの厳密一致は未達で、本番採用を承認した画像ではありません。**

| 案 | 陳列段数（目視） | 長辺角度Hough | canonicalとの差 | bbox幅差 | bbox高さ差 | 完全透明率 | 外周alpha最大 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 4 | -25.705° | +0.860° | -9px | +0px | 42.31% | 0 |
| B | 4 | -26.874° | -0.309° | -8px | +0px | 43.47% | 0 |

canonical長辺角度は-26.565°、bbox(alpha>=128)は364×432px。Hough値には商品・包装の線も含まれるため、棚全体の投影一致や長さの証明にはなりません。bbox差も棚板の長さそのものではありません。実際の棚板高さや下部空間の差は比較画像・QA overlayに残っています。商品の大きな文字と絵柄は識別できますが、縮小時の細部文字の正確さは保証しません。

幾何再指定Aは4段を維持したものの幅差が-24pxに拡大したため選外。幾何再指定Bは輪郭が近くても最下段が空となったためFULL条件で除外。さらに4段を強調したBも商品が3段となったため除外し、4段陳列を維持した初回Bを選択。計5回の生成原本を保存。除外画像は比較用の試行記録です。

既存ファイルと入力原本は変更していません。ゲームへの接続、フルテスト、commit/pushは行っていません。`SHA256SUMS*.json`は各時点の記録、最終一式は`DELIVERY_SHA256.json`で検証できます。
