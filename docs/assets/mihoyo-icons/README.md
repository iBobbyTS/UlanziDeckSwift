# 米游社游戏按钮背景素材

原始图标来自 Apple App Store / iTunes Lookup 的 `artworkUrl512`，保存在 `original/`，仅作为可追溯原始素材。

应用打包使用的源图保存在 `UlanziDeckSwift/Assets.xcassets/`，运行时再按每个游戏按键实例生成默认背景和高斯模糊版本：

- `MihoyoGenshinBackground`
- `MihoyoStarRailBackground`
- `MihoyoZenlessZoneZeroBackground`

处理流程：

1. 下载原始 `512x512` 图标。
2. 转换为 PNG 并保持最长边不超过 `512px`，原图不足该尺寸时不放大。
3. 不做高斯模糊、裁剪或其他视觉后处理。

可复现命令示例：

```bash
sips -s format png -Z 512 docs/assets/mihoyo-icons/original/genshin-impact-512.jpg --out UlanziDeckSwift/Assets.xcassets/MihoyoGenshinBackground.imageset/mihoyo-genshin-background.png
sips -s format png -Z 512 docs/assets/mihoyo-icons/original/honkai-star-rail-512.jpg --out UlanziDeckSwift/Assets.xcassets/MihoyoStarRailBackground.imageset/mihoyo-star-rail-background.png
sips -s format png -Z 512 docs/assets/mihoyo-icons/original/zenless-zone-zero-512.jpg --out UlanziDeckSwift/Assets.xcassets/MihoyoZenlessZoneZeroBackground.imageset/mihoyo-zenless-zone-zero-background.png
```

`196x196` 来自 `docs/research.md` 中的按键图标协议记录，是最终发给 H200 的单键图标尺寸；本目录的 app 打包素材保留为 `512x512` PNG 源图，供运行时按实例生成显示背景。
