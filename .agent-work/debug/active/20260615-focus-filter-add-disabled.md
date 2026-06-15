# 专注模式过滤条件添加失败

## 现象

- 用户在系统设置的睡眠专注模式中添加 `Ulanzi Deck` App 过滤条件。
- 表单显示亮度输入框，默认值曾显示 `50`，用户输入 `5` 后仍无法添加。
- 复测时系统设置可以列出 `Ulanzi Deck`，也能进入配置表单，但“添加”按钮一直是 disabled。

## 已确认

- app target 已生成 `SetFocusFilterIntent` 元数据，`systemProtocols` 包含 `com.apple.link.systemProtocol.FocusConfiguration`。
- 当前保留的实现是 `nonisolated struct UlanziDeckFocusFilterIntent: SetFocusFilterIntent`，`brightnessPercent` 为 `Double` slider，默认值 `50.0`，范围 `0...100`。
- 产物名称已改为 `Ulanzi Deck`，bundle id 仍为 `com.iBobby.UlanziDeckSwift`。
- 构建产物复制到 `/Applications/Ulanzi Deck.app` 并重新注册 Launch Services 后，问题仍复现。
- 在睡眠和 Class 两个专注模式中都复现。
- 本机没有可用 code signing identity；当前 app 签名为 `Signature=adhoc`，`TeamIdentifier=not set`。
- 对照 Bartender Pro 和 Microsoft Outlook 的 Focus Filter metadata，`effectiveBundleIdentifiers` 也为空，字段结构没有明显缺项；两者签名都有 TeamIdentifier。

## 失败过的方向

- 把亮度参数改成 optional 并提供默认值，系统设置仍无法添加。
- 去掉 `.field` 控件样式、回到默认 stepper metadata 后，用户仍报告无法添加。
- 改成 `Double` slider，默认值 50，拖动到 60 后仍 disabled。
- 改成必填 `Bool` 开关后仍 disabled。
- 改成可选、无默认值 `Int?`，输入 `5` 后仍 disabled。
- 临时去掉所有参数后，“添加”仍 disabled。
- 把 intent 类型显式标记为 `nonisolated` 后仍 disabled，但该改动保留，因为项目启用了 `-default-isolation=MainActor`，系统 AppIntent 入口不应依赖 MainActor 隔离。
- 复制到 `/Applications`、注销 DerivedData 注册路径、重启 System Settings 和 intents helper 后仍 disabled。

## 当前假设

- 首要假设：本机 ad-hoc 签名导致系统设置能显示 metadata，但不允许把该 app 写入 Focus Filter 配置。需要用 Apple Development 或 Developer ID 签名后复测。
- 次要假设：macOS 26.5 的 `SetFocusFilterIntent` 有系统级回归。Apple Developer Forums 有近三周内反馈：macOS 26.5 下 Focus Filter selection/perform 存在问题，暂无 macOS 解决方案。

## 下一步

- 用带 TeamIdentifier 的 Apple Development/Developer ID 签名重新构建，复制到 `/Applications`，重启 System Settings 后再测“添加”按钮。
- 如果正式签名后仍 disabled，再考虑把 Focus Filter 放入 App Intents extension 或等待/规避 macOS 26.5 系统 bug。
