# Shortcuts 仍显示旧专注模式动作

## 现象

- 代码已删除 `UlanziDeckFocusFilterIntent`，新增 `UlanziDeckBrightnessAdjustmentIntent`。
- Xcode 重新运行 app、重启 Shortcuts 后，Shortcuts 搜索 `ulan` 仍只显示“设定 Ulanzi Deck 专注模式过滤条件”。

## 已确认

- 当前源码和测试目录里没有 `FocusFilter`、`UlanziDeckFocusFilter`、`专注模式过滤条件` 残留。
- Xcode 构建产物 `/Users/ibobby/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/Ulanzi Deck.app/Contents/Resources/Metadata.appintents/extract.actionsdata` 只有 `UlanziDeckBrightnessAdjustmentIntent`，标题是 `Ulanzi Deck 亮度调节器`。
- LaunchServices 同时注册了两份同 bundle id `com.iBobby.UlanziDeckSwift` 的 app：
  - `/Applications/Ulanzi Deck.app`
  - Xcode DerivedData 下的 `Build/Products/Debug/Ulanzi Deck.app`
- `/Applications/Ulanzi Deck.app` 是 2026-06-15 的旧包，其 `extract.actionsdata` 仍只有 `UlanziDeckFocusFilterIntent`，系统协议包含 `com.apple.link.systemProtocol.FocusConfiguration`。

## 根因

Shortcuts/LaunchServices 优先索引了 `/Applications/Ulanzi Deck.app` 的旧 AppIntents metadata，而不是 Xcode 当前运行的 DerivedData 新构建产物。

## 修复

已把当前 Xcode 构建产物同步覆盖到 `/Applications/Ulanzi Deck.app`：

```bash
rsync -a --delete \
  '/Users/ibobby/Library/Developer/Xcode/DerivedData/UlanziDeckSwift-awbjgsodgfqkzwgvhebjwrfzykbz/Build/Products/Debug/Ulanzi Deck.app/' \
  '/Applications/Ulanzi Deck.app/'
```

然后重新注册 LaunchServices：

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f -R -trusted '/Applications/Ulanzi Deck.app'
```

随后重启 Shortcuts/AppIntents 索引相关进程：

```bash
killall ShortcutsViewService 2>/dev/null || true
killall siriactionsd 2>/dev/null || true
killall AppPredictionIntentsHelperService 2>/dev/null || true
killall intents_helper 2>/dev/null || true
```

## 验证

- `/Applications/Ulanzi Deck.app` 和 Xcode DerivedData 构建产物的 `Metadata.appintents/extract.actionsdata` SHA-256 已一致。
- 两者 metadata 都只包含 `UlanziDeckBrightnessAdjustmentIntent`，标题为 `Ulanzi Deck 亮度调节器`。

## 后续注意

- 调 AppIntents/Shortcuts metadata 时，如果 `/Applications` 和 DerivedData 里存在同 bundle id 的多份 app，要优先检查每份 app 的 `Contents/Resources/Metadata.appintents/extract.actionsdata`。
- 仅重启 Xcode 构建产物和 Shortcuts app，不一定能让 Shortcuts 放弃 `/Applications` 里的旧副本。
