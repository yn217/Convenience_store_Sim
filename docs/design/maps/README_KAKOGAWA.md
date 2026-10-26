# 加古川市の独立2.5Dマップ — map_id: kakogawa_city_v1
- [座標JSON](../../../data/world/maps/kakogawa_city_v1.json)
- [透明マーカーSVG](./kakogawa_marker_overlay_v1.svg)
- [関連Issue #154](https://github.com/yn217/Convenience_store_Sim/issues/154)、[地域マップ #150](https://github.com/yn217/Convenience_store_Sim/issues/150)

**画像ファイルの状態：** 高精細な背景PNGと施設ピン付きプレビューPNG・QA画像は会話内のZIP `kakogawa_map_v1_package.zip` として作成済みですが、**このPRにはまだPNGのバイナリは登録していません**。画像を使用するCodex/ClaudeはPNGをGitHubへ別途登録し、以下のパスで合流させてください。

- `assets/generated/maps/kakogawa_city_v1/kakogawa_base.png`（背景画像）
- `docs/design/maps/kakogawa_isometric_map.png`（レビュー用プレビュー）
- `docs/design/maps/kakogawa_coordinate_qa.png`（QA画像）
- マーカーSVGは背景とは別の透明レイヤーで、座標`x,y`は背景元サイズ**1672×940ピクセル**。ゲーム画面で表示するときはアスペクト比の余白/スケール/オフセットに従って投影する。
- POI数20、出店候補9。マップIDを青葉市/神戸淡路と独立して保存。
- **これは実際の地図と一致するGISではありません**。駅・川・商業施設等の「位置」は概念配置であり、緯度経度・距離・駅構内位置を表さない。
- `runtime_approved:false`。ゲーム導入は視覚レビュー・クリック/パン/ズーム・立地#148需要との接続後。
- 多言語POPは不要。GitHub Actionsの追加禁止。
