# macOS Focus Status 运行时行为

Last updated: 2026-06-17 15:39 MDT

Reference commit: 13cdbd6bc11e91b8aa61e39db0d7a2a5285703d0

Observed versions:

- macOS 26.5.1，build 25F80
- Xcode 26.5，build 17F42
- macOS SDK 26.5

## 官方 API 基线

Apple 在 Intents framework 中暴露 `INFocusStatusCenter`。公开 SDK 头文件提供这些运行时入口：

- `authorizationStatus`，raw value `0...3` 分别代表 not determined、restricted、denied、authorized。
- `requestAuthorizationWithCompletionHandler(_:)`，用于请求读取 Focus 状态的权限。
- `focusStatus.isFocused`，类型是 optional Boolean。

公开头文件没有承诺 `focusStatus.isFocused` 是 macOS 菜单栏“勿扰模式”或任意 Focus 模式开关的通用、可靠检测器。

## 版本化观察

在 macOS 26.5.1 上观察到：

- 用户报告勿扰模式开启时，命令行 Swift 进程读取 `INFocusStatusCenter.default` 返回 `authorizationStatus=0`、`isFocused=Optional(false)`。
- app bundle 进程可以成功获得授权；运行时调试面板显示授权状态为 authorized，raw value 为 `3`。
- 在已授权的 app bundle 进程内，用户打开和关闭勿扰模式后手动刷新，`focusStatus.isFocused` 仍保持 `Optional(false)`。
- 因为原始 API 值没有变化，依赖 `isFocused == true` 的下游逻辑无法区分“已开启”和“已关闭”状态。

这不代表 Apple 文档承诺了相反行为；更窄的结论是：在 macOS 26.5.1 上，不要把 `INFocusStatusCenter.focusStatus.isFocused` 当成当前 macOS 勿扰模式或 Focus 模式的通用状态检测器。

## 分层边界

排查 Focus 状态相关行为时，先拆开这些层：

- 授权层：`requestAuthorizationWithCompletionHandler(_:)` 是否返回或最终进入 authorized 状态。
- API 读取层：`INFocusStatusCenter` 返回的 `authorizationStatus.rawValue` 和 `focusStatus.isFocused` 原始 optional 值。
- app 决策层：app 如何把 `true`、`false`、`nil` 映射到业务行为。
- 副作用层：亮度、通知、UI、文件写入等由决策层触发的动作。

如果授权状态已经是 authorized，但用户切换 Focus/勿扰后原始 `isFocused` 值不变，问题在系统/API 读取层，不应优先怀疑下游副作用。

## 诊断清单

1. 记录或显示 `authorizationStatus.rawValue` 和对应枚举含义。
2. 记录或显示 `String(describing: focusStatus.isFocused)`，保留 `nil`、`Optional(false)`、`Optional(true)` 的差异。
3. 用真实 app bundle 进程诊断，不只依赖命令行 helper；Focus 授权和 app identity 相关。
4. 手动切换目标 Focus/勿扰状态，然后手动刷新读数，不先引入 timer。
5. 确认 `INFocusStatusCenter.default.focusStatus.isFocused` 到调试输出之间没有 app 侧缓存。
6. 只有当原始值会变化后，才继续排查亮度、通知过滤、持久化等下游行为。

## 正确模式

只有当功能可以接受 API 的文档空白和当前版本实测歧义时，才使用 `INFocusStatusCenter`。在 macOS 26.5.1 上，如果目标是“检测任意 Focus 或勿扰是否正在开启”，优先使用显式触发来源：

- 用户手动控制的 app 内模式。
- Shortcuts 自动化或命令触发 app。
- 系统 Focus Filter，前提是系统接受并实际调用该过滤条件。
- 其他已在目标系统版本上验证过的状态来源。

如果以后重新实验这个 API，开发阶段应保留原始 Focus 读数。不要在证明 API 行为前把 `nil` 和 `false` 合并成同一个用户态标签。

## Previous Wrong Attempts

- 把 `isFocused == true` 当成通用勿扰模式检测器是错误路径；用户报告勿扰已开启时，原始值仍保持 `Optional(false)`。
- 把命令行测试结果等同于 app bundle 运行时结果不充分；命令行进程是 `authorizationStatus=0`，app bundle 进程后来是 `authorizationStatus=3`，app identity 会影响授权状态。
- 给同一个 API 加 timer 不能解决问题；轮询只会重复同一个不变化或不代表目标状态的原始值。
- 先排查下游副作用会误导判断；如果原始 API 从未返回 `true`，依赖 `true` 的副作用不是根因。
