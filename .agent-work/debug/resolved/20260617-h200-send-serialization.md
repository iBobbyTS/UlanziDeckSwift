# H200 发包串行与 UI 非阻塞调试

## 症状

用户要求重新梳理 H200 发包边界：通信层阻塞并串行安全，设备层公开函数阻塞且返回本次耗时，UI 层不阻塞。初次改动后，全量 `UlanziDeckSwiftTests` 曾在并行测试下偶发失败，主要集中在连续局部同步和 `BrightnessAdjustmentRuntime.shared` 相关测试。

## 已确认事实

- 生产通信层唯一 HID 写入口是 `H200HIDConnection.writePackets(_:)`，它在内部串行队列中同步执行并逐包调用 `IOHIDDeviceSetReport`。
- 设备层公开同步器 `H200HIDDeckSyncer` 用 `operationQueue.sync` 包住完整包、局部包和亮度命令，因此调用返回时本次构建/写入已经结束或已返回错误。
- UI 状态层 `H200ConnectionModel` 改为使用后台 `deviceCommandQueue` 调用阻塞设备函数，再回主线程更新 `status`、`syncSummary`、`alert`，避免发包期间卡住主线程。
- Swift Testing 并行执行时，测试不能在排队局部同步后立刻断言 `partialDisplays.count`；必须等待后台队列完成。

## 修复

- `H200DeckSyncSummary`、`H200DeckSyncResult`、`H200DeckCommandResult` 增加 `elapsedNanoseconds` / `elapsedMilliseconds`。
- `H200ConnectionModel` 把发现、关闭、完整同步、局部同步和亮度命令统一排入后台串行 `deviceCommandQueue`。
- 启动同步未完成时发生格子显示变化，会记录版本并在启动包完成后补发当前完整显示。
- 测试 suite 使用 `.serialized`，异步发包相关断言统一等待后台结果；假同步器用延迟模拟阻塞并把耗时写入 result。
- `FakeH200Discovery` 加锁并标记 `@unchecked Sendable`，避免 `H200Discovering: Sendable` 后的测试并发预警。

## 验证

- `xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests` 通过。
- 最后一次验证日志未出现 Swift 编译警告、测试失败或 expectation 失败。
