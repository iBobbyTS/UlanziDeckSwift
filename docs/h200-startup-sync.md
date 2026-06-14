# H200 启动同步包

应用启动并确认 H200 协议接口可独占访问后，会立即生成并发送一份完整按键包。

## 数据来源

- UI 和发送包共用 `DeckKeyDisplay`。
- 初始包使用 `DeckGridInteractionState(layout: .h200Prototype).displays(for: .h200Prototype)` 生成 14 个格子的标题和副标题。
- 当前初始显示内容是数字 `1...14` 和副标题 `就绪`。
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
- 生成 ZIP 后会检查固件问题：payload 偏移 `1016 + 1024 * N` 的字节不能是 `0x00` 或 `0x7c`。如果命中，会加入 dummy 文件重建 ZIP。

## 当前边界

- 启动时只发送一次完整包。
- app 内点击格子后只更新本地原型状态，目前不会继续下发局部更新。
- 如果发送阶段发现端口被 Ulanzi Studio 或其他软件占用，会显示“按键包尚未发送”的错误提示。
