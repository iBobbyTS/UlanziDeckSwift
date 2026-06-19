# SMB 按钮背景素材

原始图像来自本机 `/Users/ibobby/Downloads/smb.png`，保存在 `original/smb-background.png`，仅作为可追溯原始素材。

应用打包使用的背景图保存在 `UlanziDeckSwift/Assets.xcassets/SMBServerBackground.imageset/smb-server-background.png`。

处理流程：

1. 从原始 `.png` 读取 `1024x1024` 图像。
2. 直接按比例缩小到 H200 单键图标目标尺寸 `196x196`。
3. 不做高斯模糊、裁剪或其他视觉后处理。

可复现命令：

```bash
sips -s format png -z 196 196 docs/assets/smb-icon/original/smb-background.png --out UlanziDeckSwift/Assets.xcassets/SMBServerBackground.imageset/smb-server-background.png
```

`196x196` 来自 `docs/research.md` 中的按键图标协议记录；小窗区域为 `458x196`，本目录素材只用于普通单键 SMB 功能。
