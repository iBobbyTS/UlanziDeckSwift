# H200 启动同步包

应用启动并确认 H200 协议接口可独占访问后，会立即生成并发送一份完整按键包。

## 数据来源

- UI 和发送包共用 `DeckKeyDisplay`。
- 启动时先通过 `UserDefaultsDeckConfigurationStore` 尝试恢复用户上次保存的 14 格配置；没有保存内容、保存内容损坏或布局不匹配时，回退到 `DeckGridInteractionState(layout: .h200Prototype)` 的默认配置。
- 初始包使用恢复后的 `DeckGridInteractionState.displays(for: .h200Prototype)` 生成 14 个格子的标题和副标题。
- 当前显示内容是每个格子的功能状态和参数摘要；默认配置下每个格子都是 tally，当前值和默认值都是 `0`。打开文件夹和打开文件功能会显示已选项目名称，未选择时分别显示“选择文件夹”和“选择文件”。亮度是顶部全局 slider，不占用任何按键格子。
- 第 14 个格子对应协议里的 `3_2` 宽槽位，占 2 列；UI 也按 2 列宽显示，避免 app 预览和设备包布局不一致。

## 包格式

- 发送内容是 ZIP payload。
- ZIP 根目录包含 `manifest.json`。
- 每个格子的 PNG 放在 `Images/key_<id>.png`。
- `manifest.json` 使用零基坐标键，例如 `0_0`、`3_2`。
- `3_2` 宽槽位写入 `SmallViewMode: 2`，让固件按 458×196 的宽图处理。

## HID 分片

- 完整包使用命令 `0x0001` 发送。
- 第一个 HID report 是 1024 字节：
  - `0x7c 0x7c`
  - 2 字节大端命令
  - 4 字节小端 payload 长度
  - 最多 1016 字节 payload
- 后续 report 每包 1024 字节，末包补零。
- 生成 ZIP 后会检查固件问题：payload 偏移 `1016 + 1024 * N` 的字节不能是 `0x00` 或 `0x7c`。如果命中，会加入 padding 文件并按 1 字节步长重建 ZIP，直到避开这些分片边界。
- 完整按键包发送后，会追加一条 `0x0006` 小窗数据包，按 `3_2` 宽槽位当前显示模式设置小窗。`功能` 对应 `BACKGROUND(2)` 并显示自定义 PNG，`时钟` 对应 `DIAL(1)`，`系统状态` 对应 `STATS(0)`。

## 连接生命周期

- 参考实现没有要求按固定周期重发完整 `0x0001` 按键 ZIP 包；完整包在初始化或布局内容变化时发送。
- 当前原型在短按计数、长按重置、修改默认值、修改文件夹/文件参数或修改 SMB 地址后，只用 `0x000d` 局部更新包同步对应单个格子的当前可见状态。
- 顶部亮度 slider 变化会先更新 app UI 和本地配置，再通过后台串行任务发送 `0x000a` 亮度包；如果发送期间 UI 继续变化，只保留最新百分比，当前发送成功后再发送最新值，避免亮度包堆积。亮度不影响按键画面，因此不会为亮度变化重发完整按键包。
- Shortcuts 的亮度调节器只在 app 正在运行且 H200 已完成同步时临时发送 `0x000a` 亮度包，不保存亮度配置，也不会主动打开 app。
- 用户修改按键功能、修改默认值、文件夹路径、文件路径、亮度百分比、物理短按计数和长按重置后，会同步写入本地 `UserDefaults`，下次启动用同一份状态生成首包。
- app 会在启动同步成功后持续持有 H200 协议 HID 接口连接，直到重试、退出或同步器释放。
- 参考实现里 5 秒 `keepAlive` 针对小窗时钟/状态数据，不是完整按键包刷新。
- 当前原型会在启动同步后继续保活：1 秒后先发送一次当前小窗模式的 `0x0006` 数据，之后每 2 秒重复发送一次，避免 H200 在几秒后恢复离线/默认显示。时钟模式的保活包会带当前时间。

## 发包线程边界

- `H200HIDConnection.writePackets(_:)` 是通信层唯一 HID 写入口，通过内部串行队列同步执行，逐包调用 `IOHIDDeviceSetReport`，调用返回即表示本批写入已结束或已经得到写入错误。
- `H200DeckSyncing` 暴露的发包函数保持同步阻塞：`sendStartupPackage(displays:)`、`sendPartialPackage(displays:)`、`setBrightness(percent:)` 都只在 PNG/ZIP 构建或本次 HID 写入完成后返回。
- `H200DeckSyncResult` 和 `H200DeckCommandResult` 都携带 `elapsedNanoseconds` / `elapsedMilliseconds`。完整包和局部包的耗时包含排队进入设备同步器、PNG/ZIP 构建、HID 打开/写入和返回；亮度命令的耗时包含排队进入设备同步器、HID 打开/写入和返回。
- SwiftUI 状态层不在主线程直接调用阻塞设备函数。`H200ConnectionModel` 统一通过后台 `deviceCommandQueue` 串行执行发现、关闭、完整同步、局部同步和亮度命令，再回到主线程更新 `status`、`syncSummary` 和 `alert`，因此发包期间 UI 仍可响应。
- 如果用户在启动完整包尚未返回时修改格子，应用会先记录显示版本变化；启动包完成后自动补发一次当前完整显示，避免设备停留在启动时的旧画面。

## 当前边界

- 启动时发送完整按键包，并追加一次当前小窗模式包。
- 保活只发送当前小窗模式的小包，不周期性重发完整按键 ZIP。
- tally、文件夹、文件和 SMB 配置状态变化后使用 `0x000d` 局部更新；payload 仍然是 ZIP，`manifest.json` 只包含本次变化的单个格子，图片也只包含该格子的 PNG。
- 宽槽位切到 `时钟` 或 `系统状态` 时会先清空该槽位功能，并用 `0x000d` 发送一张透明宽图清掉设备上的旧自定义背景；同一批局部更新会附带 `0x0006` 小窗模式包切到 `DIAL(1)` 或 `STATS(0)`。切回 `功能` 时继续发送宽槽位局部 PNG，并附带 `BACKGROUND(2)` 小窗模式包恢复自定义显示。
- `STATS(0)` 小窗 payload 使用 `${mode}|${cpu}|${mem}|${time}|${gpu}|${format}|${suffix}`。CPU 和内存来自 Mach host statistics，GPU 优先读取 `IOAccelerator` 的 `PerformanceStatistics["Device Utilization %"]`，读不到时退回 `Renderer/Tiler Utilization %` 的较大值，仍读不到则发 `0`。
- app 内修改顶部亮度百分比或 Shortcuts 亮度调节器动作时，只发送 `0x000a` 简单包；payload 是 UTF-8 百分比数字，例如 `"50"`。
- 亮度不再是按键功能，物理按键不会触发亮度调节。
- 如果发送阶段发现端口被 Ulanzi Studio 或其他软件占用，会显示“按键包尚未发送”的错误提示。
