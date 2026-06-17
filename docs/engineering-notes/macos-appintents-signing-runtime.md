# macOS AppIntents 签名与运行时通信

Last updated: 2026-06-17 17:00 MDT

Observed versions:

- macOS 26.5.1，build 25F80
- Xcode 26.5，build 17F42
- macOS SDK 26.5

## 观察

在 ad-hoc 签名的 macOS app 中，Shortcuts 可以索引 `Contents/Resources/Metadata.appintents/extract.actionsdata` 并显示动作，但执行动作时可能提示：

```text
无法运行“Ulanzi Deck 亮度调节器”操作，因为“快捷指令”无法与App通信。
```

这不是 app 自定义的 `LocalizedError`，也不是业务逻辑返回值。执行失败发生在系统 AppIntents 运行时与 app 进程建立通信之前。

## 关键日志

统一日志中 `linkd` 会记录：

```text
Failed to generate bundleIdentity:
 -Not a platform binary, checking teamId...
 -Unable to get teamId from com.iBobby.UlanziDeckSwift PID [...]
Rejecting invalid client due to requiresValidatedBundle
```

app 侧对应会看到：

```text
Unable to get synchronousRemoteObjectProxy
Error Domain=NSCocoaErrorDomain Code=4097
connection to service named com.apple.linkd.autoShortcut
```

## 结论

macOS 26.5.1 的 AppIntents 执行通信要求 `linkd` 能验证 app bundle identity。ad-hoc 签名没有 TeamIdentifier，因此会被 `requiresValidatedBundle` 拒绝。

可见性和可执行性是两层：

- 可见性：`Metadata.appintents/extract.actionsdata` 被索引，Shortcuts 能搜到动作。
- 可执行性：运行中的 app 进程必须有可验证的 bundle identity，通常需要 Apple Development 或 Developer ID 签名。

## 诊断清单

1. 检查当前运行进程路径：

```bash
ps aux | rg -i 'Ulanzi Deck'
```

2. 检查 app metadata 是否为当前动作：

```bash
plutil -p '/Applications/Ulanzi Deck.app/Contents/Resources/Metadata.appintents/extract.actionsdata'
```

3. 检查签名是否有 TeamIdentifier：

```bash
codesign -dv --verbose=4 '/Applications/Ulanzi Deck.app' 2>&1 | rg 'Signature|TeamIdentifier|Identifier'
```

4. 检查系统拒绝原因：

```bash
/usr/bin/log show --last 10m --style compact \
  --predicate 'process == "linkd" OR eventMessage CONTAINS[c] "linkd.autoShortcut" OR eventMessage CONTAINS[c] "requiresValidatedBundle"'
```

如果 `TeamIdentifier=not set` 且日志包含 `requiresValidatedBundle`，应先修签名，不要继续追 `perform()`、HID、亮度发包或 app 内 runtime。

## 正确模式

- 开发 Shortcuts/AppIntents 执行路径时，使用带 TeamIdentifier 的 Apple Development 签名。
- 如果本机没有有效签名身份，`security find-identity -v -p codesigning` 会显示 `0 valid identities found`，此时无法验证 Shortcuts 真正执行路径。
- 如果项目要长期支持未签名本地调试，需要另行设计非 AppIntents 的本地 IPC 或命令行入口；这不等同于 Shortcuts 正式动作能力。
