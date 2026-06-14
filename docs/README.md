# UlanziDeckSwift 文档

本目录记录 Ulanzi Deck H200 Swift 重构相关的调研、协议说明和实现约定。

## 文档索引

- [research.md](research.md)：Ulanzi Deck 产品线、官方软件、社区逆向项目和 D200/H200 HID 协议调研。
- [h200-startup-sync.md](h200-startup-sync.md)：启动成功后向 H200 同步 14 格数字包的实现约定。
- [h200-input-events.md](h200-input-events.md)：H200 物理按键输入包解析和应用内按键状态映射。

## 更新规则

- 文档默认使用中文。
- 修改设备识别、HID 协议、启动检测、用户可见流程或重要工程约定时，同步检查是否需要更新本目录。
- 引用外部协议字段、命令名、Apple API、仓库名或硬件型号时保留原文，解释文字使用中文。
