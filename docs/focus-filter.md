# macOS 专注模式过滤条件

应用通过 `SetFocusFilterIntent` 向系统注册一个专注模式过滤条件，系统设置中的用户可见名称使用 `Ulanzi Deck`，不固定写成某个具体硬件型号。

## 当前行为

- 过滤条件参数只有 `亮度`，取值范围是 `0...100`。
- 用户需要在 macOS 系统设置的具体专注模式中手动添加 `Ulanzi Deck` 过滤条件。
- 专注模式触发时，系统会调用 app target 内的 `UlanziDeckFocusFilterIntent.perform()`。
- `perform()` 会把亮度写入现有配置存储，并发出进程内通知。
- app 正在运行且 H200 已连接时，`H200ConnectionModel` 会收到通知，然后复用顶部亮度 slider 的同一条异步发包路径。
- app 启动并成功同步按键显示后，如果本地已有持久化亮度值，会补发一次亮度包，确保设备亮度和 app 配置一致。

## 边界

- 这个入口不读取系统当前专注模式名称，也不依赖“睡眠”等模式名称判断。
- 是否是目标硬件仍由现有 HID 发现和连接流程判断。
- AppIntents 元数据来自 app target；如果系统设置里暂时看不到 `Ulanzi Deck`，先重新构建/运行 app，让 Launch Services 重新注册该 bundle。
- 修改过滤条件参数结构后，系统设置可能继续使用已有专注模式里的旧过滤条件实例；需要删除旧的 `Ulanzi Deck` 过滤条件后重新添加，必要时重启系统设置再进入该专注模式。
- 本地调试包如果使用 Xcode 的 `Sign to Run Locally` ad-hoc 签名，系统设置可能能列出过滤条件但仍禁用“添加”。遇到这种状态时，先检查 `codesign -dv --verbose=4` 输出里是否有 `TeamIdentifier`；没有可用签名身份时，当前机器无法完整验证系统级 Focus Filter 添加流程。
