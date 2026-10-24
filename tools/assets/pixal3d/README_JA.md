# Pixal3D による残り什器アセット生成 — Codex への引き継ぎ（2026-10-25）

## 1. 状況
- Pixal3D（画像1枚 → 色付き3Dモデル、MIT ライセンス）が WSL の Ubuntu-F で動く状態になった。
- 試作3点の結果
  - ATM（S01）：採用。
  - コピー機（S02）：採用。
  - ホットスナックケース（C00）：不採用。形が歪んでいる。
- ATM とコピー機をゲームの什器として組み込む作業は、Claude が担当する（ブランチ `feature/m16-pixal3d-fixtures`）。
- **Codex の担当：残りの設備・什器アセットを、同じ手順で生成すること。**

## 2. 環境（構築済み・再構築は不要）
- WSL：`Ubuntu-F`、ユーザーは `inayut`。C: 側の `Ubuntu` は起動しない。
- Python 環境：`~/.local/envs/pixal3d`（Python 3.10、torch 2.6.0+cu124、GPU は RTX 3090 24GB）。
  - 拡張モジュールはビルド済み：nvdiffrast、cumesh、flex_gemm、o_voxel、natten 0.21.0（cmake は pip で導入）、einops。
- 重み（Linux 側にコピー済み。`/mnt/f` から直接読むと非常に遅いので、必ずこちらを使う）
  - `~/pixal3d-models/Pixal3D`：単視点用 ckpts、23GB。
  - `~/pixal3d-models/dinov3-vitl16-pretrain-lvd1689m`：ユーザーが用意した公式 DINOv3。
  - `~/pixal3d-models/torch/hub`：NAF（Apache-2.0）。
- Pixal3D のソース：`/mnt/f/WSL/Pixal3D-upstream`。改変していない。
- Blender：`~/apps/blender-4.5.3-linux-x64/blender`。`LD_LIBRARY_PATH=~/.local/envs/pixal3d/lib` が必要。

## 3. 手順（作業フォルダ `F:\WSL\pixal3d-pilot`）
1. **入力を透過 PNG にする**：`python -I scripts/cutout.py <元画像> input/<名前>.png 18`（Windows 側の Python）
   - 背景を消す RMBG-2.0 は非商用ライセンスなので、使用禁止。runner 側でも読み込まないように止めてある。
   - cutout.py は、無地の明るい背景を縁から塗りつぶして消し、床の影も外す。
   - 実行後、マゼンタ背景で合成して目視確認する。ゴミ・欠け・影の残りがないこと。
2. **3D 生成**：`wsl -d Ubuntu-F -u inayut -- bash /mnt/f/WSL/pixal3d-pilot/run.sh --low_vram input/A.png input/B.png ...`
   - 複数枚を1回で渡すこと。モデルの読み込みは1回だけで済む（初回は約20分、以降は1点あたり5〜12分）。
   - `--low_vram` は必須。付けないと NAF の段階で `CUDA driver error: unknown error` で落ちる。
   - 結果は `out/<名前>.glb`。所要時間とピーク VRAM は `out/report.json` に記録される。
   - カメラの FOV は 0.2 rad 固定。MoGe は入れていない。
3. **ゲームの投影で描画**：`wsl ... bash /mnt/f/WSL/pixal3d-pilot/render.sh <名前> <高さm>`
   - ゲームと同じ投影（iso2x_v1：正射影、仰角30°、181.02 px/m）で、4方向と正面・側面を描く。
   - `upright()`：写真の撮影角度のせいでモデルが傾くので、最小の外接箱になる向きを探してまっすぐ立てる。
   - `drop_fragments()`：床の影から生じたゴミや、浮いた細かい破片を消す。
   - 一覧画像は `python -I scripts/sheet.py <名前>`、ゲーム画面への仮合成は `scripts/composite.py` で作る。

## 4. 合否の基準（ユーザー判断の実例）
- 不採用：形の歪み（C00 は複数機器の連結で、比率と輪郭が崩れた）。
- 採用：単体で箱型の機器（ATM、コピー機）。ゲームの表示サイズで細部が読めること。
- 背面と側面は単視点なので、ぼやける。壁際に置く前提なら許容する。前面の向きが正しいことは必ず確認する。
- 複数の機器を連結した画像や、細かい商品が並ぶ棚は不向き。棚は Hunyuan3D でも NO-GO だった。
  - 連結物は1台ずつの画像に分けてから入力する。

## 5. 残りの対象（ユーザー提供 `convenience_remaining_asset_images_20261024.zip`）
- 高解像度の単体画像（`01_original_full_resolution`）
  - 有力：F03 アイスクリームケース、F01 冷凍ウォークイン・ガラス扉、A01 日用品棚、A02 文具棚、A03 書籍・雑誌棚。
  - 棚系は商品が潰れる恐れがあるので、1点試して目視してから進める。
- 低解像度の切り出し（`02_additional_crops_review_only`）は、README で「高解像度入力に使わない」と指定されている。
  - 例：C01〜C05 のホット系単体、F02 冷凍チェスト、X01 台車とクレート、X02 ポスト。
  - 使う場合は、高解像度の単体画像を作り直してから入力する。
- C00 の代わりにホット系を作るなら、C01 フライヤーケース、C02 コーヒーマシン、C03 中華まん、C05 おでんを1台ずつ作る。
- 未生成のもの（電子レンジ、傘立て、季節棚、バックヤード棚、宅配ラック）は、入力画像を作るところから始める。

## 6. 権利・配布
- Pixal3D と NAF のコードと重みは MIT / Apache-2.0。DINOv3 は Meta の DINOv3 License（ユーザーが入手済み）。
- 入力画像にある実在ブランド風のロゴ・文字・価格は、ゲームに採用する前に架空のデザインへ置き換える。
- 生成した GLB と描画結果はローカルに置く。リポジトリに入れるのは、ゲームに採用したスプライトだけにする。
- 出所の記録（入力画像、seed 42、resolution 1024、fov 0.2、スクリプト）を `out/report.json` と `renders/*_info.json` に残す。

## 7. ゲームへの組み込み（参考。ATM とコピー機で Claude が手本を作る）
- 什器の定義：`data/fixtures/mvp_v1.json`（寸法、footprint、access_edges、visual_id）。
- 見た目：`assets/generated/fixtures/<type>/<type>_a.visual.json` と、回転ごとの body と shadow の PNG。
  - `tools/assets/validate_manifests.py` と `tests/contract/test_visual_manifests.gd` で検査する。
- 回転の規則：r0 の前面を access edge にし、r が1増えるごとに N→E→S→W と回る。
  - 描画側の yaw は `180 - 90*r`（前面が Blender の −Y を向く場合）。
- 生成物は `runtime_approved:false` のまま出し、ユーザーがゲーム画面で確認してから採用する。
