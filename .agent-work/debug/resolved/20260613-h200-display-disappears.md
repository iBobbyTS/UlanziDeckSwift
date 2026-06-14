# H200 启动包短暂显示后消失

## 已确认观察

- 用户实机观察：本 app 打开后，H200 确实显示了 app 发送的内容，但几秒后消失。
- 2026-06-13 第二次实机观察：追加 `OUT_SET_SMALL_WINDOW_DATA` background 后，时钟不再和 `3_2` 宽槽位重叠，但内容仍然在几秒后消失。
- `docs/research.md` 没有记录必须周期性重发完整 `OUT_SET_BUTTONS` 包；风险点里已有“Studio 关闭后设备恢复默认布局”的离线模式限制。
- `companion-surface-d200` 初始化时发一次完整 `setButtons`，之后只在内容变化时 flush；没有固定周期重发完整按键包。
- `companion-surface-d200` 会长期持有 HIDAsync 连接，并且初始化后会发送小窗模式数据；当小窗禁用时，它发送 `SmallWindowMode.BACKGROUND` 后暂停 5 秒 keep-alive。
- `strmdck` 的 `keep_alive()` 发送的是 `set_small_window_data({})`，不是完整按键 ZIP。

## 当前假设

第一次修复确认小窗模式包有效，但单次发送不足以保住在线内容。根因更可能是 H200 固件需要周期性在线态保活；保活包应优先使用参考实现中的小窗数据包，而不是重发完整按键 ZIP。

## 下一步

- 保持 HID 连接，并在启动包后继续周期发送 `OUT_SET_SMALL_WINDOW_DATA` background 小包。
- 首次保活延迟 1 秒，之后每 2 秒发送一次，等待实机确认是否还会消失。

## 本地验证

- 2026-06-13 22:01 MST：`xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests` 通过。
- 2026-06-13 22:07 MST：加入 1 秒后首发、每 2 秒重复的 background 小窗保活后，同一测试命令通过；之前的 Sendable 捕获警告已处理。
- 2026-06-13 用户实机确认：内容不再几秒后消失。
