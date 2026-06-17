# macOS Shortcuts 亮度调节器

应用通过 App Intents 向 Shortcuts 暴露一个亮度调节器动作。

## Ulanzi Deck 亮度调节器

- 动作名称是 `Ulanzi Deck 亮度调节器`。
- 参数只有 `亮度`，取值范围是 `0...100`。
- 动作只支持正在运行的 app 进程：如果 app 没有运行，Shortcuts 会得到错误提示，用户需要手动打开 app。
- 动作不会主动打开 app，也不会保存亮度配置。
- 动作只在 app 已连接 Ulanzi Deck 且启动同步完成后执行；未连接、未完成同步或连接失败时会返回错误。
- 执行成功时，动作复用顶部亮度 slider 的异步 `0x000a` 发包路径，但调用 `persist: false`，因此不会写入 `UserDefaults`，下次启动也不会把这次 Shortcuts 临时亮度当成用户配置恢复。

## 边界

- 这个动作不直接打开 HID 设备；HID 连接仍由正在运行的 app 和 `H200ConnectionModel` 持有。
- 如果后续需要 app 未运行时也能执行，需要另行设计直接 HID 访问路径，并处理与正在运行 app 抢占 H200 通信端口的问题。

## 签名要求

- Shortcuts 能发现动作只说明 `Metadata.appintents` 已被系统索引；执行动作还需要系统 `linkd` 能验证正在运行的 app 进程身份。
- 在 macOS 26.5.1 上，ad-hoc 签名的 app 会被 `linkd` 拒绝，Shortcuts 会显示“无法与App通信”。统一日志里的关键错误是 `Rejecting invalid client due to requiresValidatedBundle` 和 `Unable to get teamId from com.iBobby.UlanziDeckSwift`。
- 开发调试 Shortcuts 执行路径时，需要使用带 TeamIdentifier 的 Apple Development 或 Developer ID 签名包。只用 Xcode 本地 ad-hoc 签名可以生成 metadata，也可以让 Shortcuts 搜到动作，但不能稳定执行动作。
