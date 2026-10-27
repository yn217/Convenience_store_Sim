# 統合スプライト生成記録

商品を一つずつ配置せず、棚と商品を含む一枚の透過画像として生成した試作品。FULL v3を入力としてHALF二案とEMPTYを生成し、`states_v3_comparison.png` に同じ442×449キャンバスで並べた。生成画像は候補であり、ゲームへの組み込みや採用はしていない。

- FULL: `shelf_general_full_generation_v3.png`
- HALF: `shelf_general_half_from_full_v3.png`、`shelf_general_half_from_full_v3_alt.png`
- EMPTY: `shelf_general_empty_from_full_v3.png`
- 各 `*_contract_fit.png` は水平反転、アルファ閾値8、外形枠への正規化を適用したプレビュー。
- 正規化後のキャンバスは442×449、アンカーは(285,302)、alpha bboxは[38,8,403,425]。これは画面枠の一致であり、棚の構造・実際のゲーム投影への適合の証明ではない。
- 元画像ごとに非一様な伸縮があり、FULL v3は縦横比が約-5.89%、HALFは約-5.75%、HALF別案は約-4.85%、EMPTYは約-5.75%。
- HALFの空き部分には新しい区画に見える表現があり、EMPTYのガード支柱の数・位置はFULLと揃っていない。状態切替用セットとして未合格。
- 本体構造を共有するため、EMPTYを共通原板としたFULL/HALFを別サブエージェントに追加生成依頼中。
- runtime_approved: false。Godot表示、独立Visual QA、SKU照合、透過フリンジと非一様伸縮の許容判定は未完了。

## EMPTY共通原板からの追加生成

- `full_from_empty_v1.png`: EMPTY原板から商品を高密度に加えたFULL一体画像。
- `half_from_full_emptybase_v2.png` と `half_from_full_emptybase_v2_alt.png`: 上記FULLから商品群を減らしたHALF二案。
- `states_empty_base_comparison.png`: FULL、HALF二案、元EMPTYを同じ442×449キャンバスで比較。
- 商品量の変化は確認できるが、ガード支柱や背板・商品形状は生成ごとに変化する。棚構造の完全一致は未確認で、状態切替用として承認しない。
- 画像ごとに約4.5〜5.8%の非一様伸縮がある。bboxとanchorの値は揃えているが、実ゲーム表示の検証や独立Visual QAは未実施。

## 菓子・パン棚と実ゲーム画面の比較

- `full_from_empty_snacks_v2.png` は棚と菓子・パンを含むFULL画像。`half_from_full_snacks_v1.png` は同じ画像を参照したHALF画像。
- `states_snacks_comparison.png` はFULL/HALF/EMPTYを442×449キャンバスで並べた試作比較。棚支柱などの一致は未保証である。
- `game_demo_zoom1_6.png` はGodotのdemoをzoom 1.6で取得した実画面。`game_shelf_overlay_preview.png` はその画面にFULL候補を推定位置・縮尺で重ねた合成画像であり、ゲーム内の実描画ではない。
- 投影・アンカー情報に基づく比較で、候補はそれぞれ約5.28%と5.37%の非一様な縦横比変更を受けている。実ゲームでの正式な投影適合、SKU照合、独立Visual QAは未完了。
- 共通棚原板に商品領域をマスク合成し、保護線の画素を復元する案も試したが、商品を横切る白い線が現れたため不採用。
