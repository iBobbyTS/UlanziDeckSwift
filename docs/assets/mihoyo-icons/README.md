# 米游社游戏按钮背景素材

原始图标来自 Apple App Store / iTunes Lookup 的 `artworkUrl512`，保存在 `original/`，仅作为可追溯原始素材。

应用打包使用的背景图保存在 `UlanziDeckSwift/Assets.xcassets/`：

- `MihoyoGenshinBackground`
- `MihoyoStarRailBackground`
- `MihoyoZenlessZoneZeroBackground`

处理流程：

1. 下载原始 `512x512` 图标。
2. 中心裁剪为正方形。
3. 添加高斯模糊。
4. 降采样到 H200 单键图标目标尺寸 `196x196`。

`196x196` 来自 `docs/research.md` 中的按键图标协议记录；小窗区域为 `458x196`，本目录素材只用于普通单键游戏状态功能。
