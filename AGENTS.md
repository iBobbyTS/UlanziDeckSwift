# UlanziDeckSwift 项目规则

## 项目定位

- 这是一个 macOS SwiftUI 应用，用 Swift 重构 Ulanzi Deck H200 的基础控制能力。
- 当前实现重点是识别 H200 HID 协议接口、启动时确认设备连接状态，并提供 14 格按键交互原型。
- 项目以本地 Xcode/macOS 工作流为主，不使用 Docker、Node 包管理器或服务端运行环境。

## 技术栈

- 语言与框架：Swift、SwiftUI、AppKit、IOKit HID。
- 工程入口：`UlanziDeckSwift.xcodeproj`。
- 单元测试：Swift Testing，测试目标在 `UlanziDeckSwiftTests/`。
- UI 测试模板保留在 `UlanziDeckSwiftUITests/`，只有实际覆盖用户流程时再扩展。

## 语言与文案

- 项目默认全部使用中文：Codex 回复、实现计划、文档、UI 可见文案、可访问性文案、测试说明和提交消息正文都使用中文。
- Swift 类型、方法、属性、协议名等代码标识符优先使用英文，遵循 Apple API 和 Swift 生态惯例。
- 代码注释默认中文；只有引用 Apple API、HID 规范、第三方仓库、命令名、协议字段或硬件型号时保留英文原文。
- Git 提交使用 Conventional Commits。`type` 和可选 `scope` 使用英文，description 和 body 默认中文。

## UI 本地化

- 当前不启用多语言文件，源语言就是中文，SwiftUI 中的可见字符串直接写中文。
- 后续如果需要多语言，先统一迁移到 `Localizable.xcstrings`，并在同一次改动中更新所有支持语言。
- 新增界面时，按钮、弹窗、状态文本、可访问性 label/value 都必须同步使用中文。

## H200 HID 约定

- 当前实测目标设备接口：
  - Vendor ID：`0x2207`
  - Product ID：`0x0019`
  - Usage Page：`12`
  - Usage：`1`
  - 输入/输出报告大小：`1024`
- 同一设备还会暴露普通键盘接口，例如 Usage Page `1`、Usage `6`，不能把它当作协议通信接口。
- 判断占用状态时，先枚举并过滤出目标 HID 协议接口，再用 `IOHIDDeviceOpen(..., kIOHIDOptionsTypeSeizeDevice)` 探测是否被其他进程独占。
- HID 识别、占用判断和后续协议通信逻辑应保留在 HID/设备层，不要塞进 SwiftUI View。

## 验证命令

- 改动 Swift 代码后至少运行：

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

- 只改文档时不需要运行 Xcode 测试，但需要检查 Markdown 内容和链接是否合理。
- 涉及 entitlements、HID 识别或设备访问时，优先补充或更新单元测试；必要时再用真实 H200 做手工验证。

## 文档规则

- `docs/README.md` 是文档入口和文档更新规则来源。
- `docs/research.md` 是 Ulanzi Deck、Ulanzi Studio 和社区逆向方案的调研资料。
- 修改 HID 协议、设备识别、启动流程或用户可见行为时，同步判断是否需要更新 `docs/` 下的相关说明。
- `.codewhale/instructions.md` 是自动生成的结构文件，不作为项目规范来源。

## 工作流

- 当前不启用 Linear/Symphony 工作流文件。
- 当前不启用仓库级 git hook 维护性审计提醒；如需启用，先由用户明确 commit 间隔和 baseline 策略。
- 不创建 `.agents/skills/`，除非用户明确要求为本仓库沉淀项目专用 skill。

## 安全与维护

- 保留用户未要求删除的改动，不执行 `git reset --hard`、`git checkout --` 或破坏性清理。
- 避免把设备访问错误吞掉；权限不足、设备未连接、被占用和普通打开失败应保持可区分。
- 新增共享抽象前先确认至少有真实复用需求；HID 目标识别、错误映射和协议封包属于高风险边界，应保持单一来源。
