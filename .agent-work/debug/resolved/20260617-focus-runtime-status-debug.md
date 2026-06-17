# 专注状态运行时读取不生效

## 现象

- 用户开启勿扰/专注模式后，临时轮询方案没有把 Ulanzi Deck 亮度设为 0。
- 用户确认运行 app 时见过系统授权提示：是否允许该软件获取勿扰模式状态。

## 已确认

- 直接用 Swift 命令行读取 `INFocusStatusCenter.default`，在用户报告勿扰开启时返回：`authorizationStatus=0`、`isFocused=Optional(false)`。
- Xcode SDK 头文件确认 `authorizationStatus=0` 是 `INFocusStatusAuthorizationStatusNotDetermined`。
- 命令行结果不能等价代表 app bundle 运行时结果，因为它不是 `com.iBobby.UlanziDeckSwift` 这个 app 进程。
- app 已有 `NSFocusStatusUsageDescription`，app entitlements 目前只有 sandbox、USB、用户选择文件夹只读权限。
- 2026-06-17 用户截图确认 app 进程内调试窗口显示：授权状态“已授权”、授权 raw 值 `3`、`isFocused` 原始值 `Optional(false)`。用户切换勿扰开关并点击刷新后这些内容不变。
- `RootView` 的调试窗口刷新路径直接调用 `FocusActivityProviding.debugSnapshot()`，最终读取 `INFocusStatusCenter.default.authorizationStatus` 和 `INFocusStatusCenter.default.focusStatus.isFocused`，没有中间缓存或自定义判断。

## 当前假设

- 项目侧已成功获得 Focus 状态读取授权，但 `INFocusStatusCenter.focusStatus.isFocused` 在当前 macOS/app 场景下没有反映用户切换勿扰模式的状态。
- 这更像 Apple Focus Status API 的语义限制或系统实现问题，而不是 H200 亮度发包、轮询、授权请求或 UI 缓存问题。

## 处理结果

- 结论已沉淀到 `docs/engineering-notes/macos-focus-status-runtime-behavior.md`。
- 删除运行时轮询、启动调试窗口和 `NSFocusStatusUsageDescription` 权限声明。
- 当前 app 不再请求 Focus 状态读取权限，也不再依赖 `INFocusStatusCenter.focusStatus.isFocused` 作为通用“勿扰模式是否开启”检测。
- 若仍要实现自动降亮度，需要评估替代来源：用户手动快捷键/菜单开关、Focus Filter 正式流程、Shortcuts 自动化触发 app、或私有/脆弱系统状态读取路径。
