# Shortcuts 无法与 app 通信

## 现象

- Shortcuts 已能找到 `Ulanzi Deck 亮度调节器`。
- 执行动作时报错：`无法运行“Ulanzi Deck 亮度调节器”操作，因为“快捷指令”无法与App通信。`

## 已确认

- 当前运行进程是 `/Applications/Ulanzi Deck.app/Contents/MacOS/Ulanzi Deck`。
- `/Applications/Ulanzi Deck.app/Contents/Resources/Metadata.appintents/extract.actionsdata` 只包含 `UlanziDeckBrightnessAdjustmentIntent`，没有旧 Focus Filter metadata。
- 报错不是 app 自定义的 `appNotRunning` 或 `deviceNotReady` 文案，说明 `perform()` 没有正常进入业务返回路径。
- `codesign -dv` 显示当前 app 是 `Signature=adhoc`，`TeamIdentifier=not set`。
- `security find-identity -v -p codesigning` 显示 `0 valid identities found`。

## 根因

macOS AppIntents 执行通信被 `linkd` 拒绝，因为 app 没有可验证的 TeamIdentifier。

关键统一日志：

```text
Failed to generate bundleIdentity:
 -Not a platform binary, checking teamId...
 -Unable to get teamId from com.iBobby.UlanziDeckSwift PID [...]
Rejecting invalid client due to requiresValidatedBundle
```

app 侧对应日志：

```text
Unable to get synchronousRemoteObjectProxy
Error Domain=NSCocoaErrorDomain Code=4097
connection to service named com.apple.linkd.autoShortcut
```

## 结论

Shortcuts 能看到动作只代表 metadata 已索引；执行动作还要求系统能验证 app 进程身份。ad-hoc 签名在 macOS 26.5.1 上不满足 `linkd` 的 `requiresValidatedBundle` 要求。

## 修复路径

- 给项目配置有效 Apple Development 或 Developer ID 签名，确保 `codesign -dv --verbose=4` 输出非空 `TeamIdentifier`。
- 重新构建 app，覆盖 `/Applications/Ulanzi Deck.app`，重新注册 LaunchServices。
- 重启 app 和 Shortcuts 后再测动作执行。

当前机器没有有效 codesigning identity，所以本轮无法直接生成可验证签名包。

## 文档

- 已新增 `docs/engineering-notes/macos-appintents-signing-runtime.md`。
- 已更新 `docs/shortcuts.md` 的签名要求。
