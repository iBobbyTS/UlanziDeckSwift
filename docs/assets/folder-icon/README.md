# 打开文件夹按钮背景素材

原始图像来自本机 `/Users/ibobby/Downloads/folder.png`，保存在 `original/folder-background.png`，仅作为可追溯原始素材。

应用打包使用的背景图保存在 `UlanziDeckSwift/Assets.xcassets/FolderBackground.imageset/folder-background.png`。

处理流程：

1. 从原始 `.png` 读取 `1024x1024` 图像。
2. 直接按比例缩小到 H200 单键图标目标尺寸 `196x196`。
3. 不做高斯模糊、裁剪或其他视觉后处理。

可复现命令：

```bash
sips -s format png -z 196 196 docs/assets/folder-icon/original/folder-background.png --out UlanziDeckSwift/Assets.xcassets/FolderBackground.imageset/folder-background.png
```

`196x196` 来自 `docs/research.md` 中的按键图标协议记录；小窗区域为 `458x196`，本目录素材只用于普通单键打开文件夹功能。
