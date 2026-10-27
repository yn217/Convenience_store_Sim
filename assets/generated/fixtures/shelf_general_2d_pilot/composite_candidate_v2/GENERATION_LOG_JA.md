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

## 追加の検討と独立確認

- `empty_from_snacks_v2.png` は菓子・パンのFULL参照から商品を除去したEMPTY試作。`states_snacks_comparison_v2.png` にFULL/HALF/EMPTYを比較した。棚の支柱位置の状態間一致は未検証。
- 制作者以外の担当は `full_from_empty_snacks_v2_contract_fit.png` の密度・菓子やパンのカテゴリ識別をFULL/r0の試作としてPASSと判断。ただし非一様伸縮5.283%、実runtime未接続、SKU未照合を条件として記録した。これはゲームへの採用承認ではない。
- 縦横比を改善する新しい生成画像のalpha>0外接比は0.8769だったが、alpha>=8ではbboxが(129,8)-(1041,1297)、比率は0.7075だった。薄い透明ノイズで数値が変わるため、目的の外形には未達として再生成を依頼した。
- FULL/HALF/EMPTYの完全な構造一致、実ゲームの描画、4方向への展開は未完了。runtime_approvedはfalseを維持する。

## 等倍比でのFULL候補

- `full_snacks_ratio0875_v2.png` は棚と商品を一体生成した新しいFULL画像。alpha>=8でbboxは(10,4)-(1166,1325)、実体の幅÷高さは約0.8751。alpha>=128でも約0.8750。
- `full_snacks_ratio0875_v2_uniform.png` は等方スケール0.31566995と水平反転で正規化。canvas 442×449、anchor (285,302)、alpha bbox [38,8,403,425]。縦横比の変更は0%。
- `full_uniform_comparison.png` に旧FULLと新FULLを並べた。外接枠の一致は棚足・斜め方向・ゲーム内サイズの一致の証明ではない。実画面への重ね合わせと独立評価は進行中。
- 先行するHALF/EMPTYは旧FULLからの生成であり、新FULLとの棚構造一致は未検証。runtime_approved:false。

### 独立Visual QA・等方FULL

制作担当と別の担当が `full_snacks_ratio0875_v2_uniform.png` をFULL/r0試作品としてPASSと判定。4段の商品密度、菓子・パンのカテゴリ認識、背板・前面ガード・支柱・台座を確認した。

`game_shelf_overlay_full_snacks_ratio0875_v2_uniform.png` はGodot demo画面に候補を合成したプレビュー。tile (6,3)、rotation 0、zoom 1.6、描画倍率0.8、算出アンカー(1218.4,725.1)。ゲーム内への候補接続ではなく、bboxだけでは棚足や角度の完全一致は証明できない。

人間による最終画質承認、SKU照合、新FULLを基準にしたHALF/EMPTYの棚構造一致、他の回転、runtime実描画は未完了。runtime_approved:false。

## 等方FULLからの状態試作

- `half_uniform_full_v1.png` と `empty_uniform_full_v1.png` は新しいFULLを参照し、HALF/EMPTYとして一体生成。`states_uniform_comparison.png` で表示した。
- 3状態とも個別商品のruntime配置なし、縦横共通スケールで正規化。FULL/HALFのalpha bboxは[38,8,403,425]、EMPTYは[40,8,402,425]で幅が3px狭い。
- 各画像の生成やcrop/scaleは別々に行っているため、bbox値とanchorメタデータの指定だけでは棚の位置やガード支柱の一致は証明できない。見た目上もガード支柱や背板の差が残るため状態セットは未承認。
- EMPTYは構造が見えるHALFを参照にした再生成を依頼中。runtime_approved:false。

## 3状態への共通変換

- `tools/assets/normalize_shelf_state_set.py` はFULL参照のalpha>=8 bboxから倍率と配置を求め、同じ元キャンバスサイズを持つFULL/HALF/EMPTYへ同一の水平反転・倍率・オフセットを適用する。商品を個別に配置しない。
- `fixed_transform_v1/fixed_transform_report.json` と `fixed_transform_states_comparison.png` に結果を保存。名目スケールは0.315669947、キャンバスは442×449、オフセットは(36,7)。各画像の実効スケールはピクセル丸めにより約(0.31543052, 0.31543624)。
- alpha>=8 bboxはFULL [38,8,403,425]、HALF [38,8,403,426]、EMPTY [38,8,404,428]。状態間で同一の外形にはなっていない。
- 同一の画像変換は什器の構造一致や本来の接地点の証明ではない。独立確認と、HALFを参照するEMPTY再生成を実施中。runtime_approved:false。
