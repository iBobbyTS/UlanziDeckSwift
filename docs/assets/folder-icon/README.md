# 打开文件夹按钮背景素材

原始图像来自本机 `/Users/ibobby/Downloads/folder.png`，保存在 `original/folder-background.png`，仅作为可追溯原始素材。

应用打包使用的源图保存在 `UlanziDeckSwift/Assets.xcassets/FolderBackground.imageset/folder-background.png`，运行时再按每个按键实例生成默认背景和高斯模糊版本。

处理流程：

1. 从原始 `.png` 读取 `1024x1024` 图像。
2. 直接按比例缩小到最长边 `512px`，原图不足该尺寸时不放大。
3. 不做高斯模糊、裁剪或其他视觉后处理。

可复现命令：

```bash
sips -s format png -Z 512 docs/assets/folder-icon/original/folder-background.png --out UlanziDeckSwift/Assets.xcassets/FolderBackground.imageset/folder-background.png
```

`196x196` 来自 `docs/research.md` 中的按键图标协议记录，是最终发给 H200 的单键图标尺寸；本目录的 app 打包素材保留为 `512x512` PNG 源图，供运行时按实例生成显示背景。
