# SMB 按钮背景素材

原始图标来自本机 `/Users/ibobby/Pictures/未命名.icns`，保存在 `original/smb-background.icns`，仅作为可追溯原始素材。

应用打包使用的背景图保存在 `UlanziDeckSwift/Assets.xcassets/SMBServerBackground.imageset/smb-server-background.png`。

处理流程：

1. 从原始 `.icns` 抽取 `1024x1024` PNG。
2. 中心裁剪为正方形。
3. 添加高斯模糊。
4. 降采样到 H200 单键图标目标尺寸 `196x196`。

`196x196` 来自 `docs/research.md` 中的按键图标协议记录；小窗区域为 `458x196`，本目录素材只用于普通单键 SMB 功能。
