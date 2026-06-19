# Ulanzi Deck 与 Ulanzi Studio 调研

> 调研日期: 2026-06-11
> 目标: 评估使用 Swift 重写 Ulanzi Studio 的可行性

---

## 目录

1. [Ulanzi Deck 硬件产品线](#1-ulanzi-deck-硬件产品线)
2. [Ulanzi Studio 软件](#2-ulanzi-studio-软件)
3. [官方开源状态](#3-官方开源状态)
4. [社区开源逆向成果](#4-社区开源逆向成果)
5. [通信协议详解 (D200)](#5-通信协议详解-d200)
6. [Swift 重写可行性分析](#6-swift-重写可行性分析)
7. [参考资料](#7-参考资料)

---

## 1. Ulanzi Deck 硬件产品线

### 1.1 D200X Creative Deck（最新旗舰，2026年4月发布）

| 项目 | 规格 |
|------|------|
| **售价** | $96 起 (约 ¥700) |
| **按键** | 14 个可自定义高亮 LCD 按键 |
| **旋钮** | 3 个高精度旋转编码器 (Dial 辅助控制器) |
| **屏幕** | 5.5 英寸, 960×540 分辨率 |
| **接口** | **8合1 USB-C 扩展坞**: 双 USB 3.2 Gen2 (10Gbps), HDMI 4K@60Hz, SD/TF 读卡器, 3.5mm 音频 I/O, 100W PD 充电 |
| **尺寸** | 153×113.5×98 mm, ~480g |
| **材质** | 铝合金面板 + 亚克力按键 |
| **连接** | USB-C 有线（低延迟）, 蓝牙仅用于 Dial |
| **兼容应用** | OBS, Twitch, YouTube, Discord, Zoom, Teams 等 100+ 应用 |

特点:
- 集成了 **8合1 扩展坞**，可替代多个桌面外设
- 支持 **离线模式**（即插即用）和 **在线模式**（配合 Studio 自定义）
- 可配对 **Dial 旋钮控制器**（蓝牙，最多 3 设备切换）
- 支持 **智能家居联动**: Philips Hue, Home Assistant, Govee, Nanoleaf, Yeelight
- **终身免费软件更新**

### 1.2 D200H Deck Dock（7合1 集线器版）

- 14 个 LCD 按键
- 7合1 扩展坞
- 适合 Zoom、直播、办公场景

### 1.3 D200 U-Studio（初代 Stream Controller）

- 14 个 LCD 按键 + 13 个自定义宏键
- 专为 OBS、Twitch、YouTube 设计
- **社区逆向最成熟**的型号

### 1.4 D100H Dial Creative Controller（旋钮控制器）

- 蓝牙连接 (VID 0xfff1)
- 1 个旋钮 + 7 个按键
- 离线模式仅支持音量/媒体控制 + Ctrl+C/V/Z/Y
- **USB-C 仅充电，不传数据**

### 1.5 D100H Dial Creative Controller I003（新版）

- 独立旋钮控制器
- 适合精细调节（时间线滚动、调色等）
- 蓝牙支持最多 3 台设备

---

## 2. Ulanzi Studio 软件

| 项目 | 详情 |
|------|------|
| **支持平台** | Windows / macOS（推荐 macOS 12+, 支持 Apple Silicon） |
| **价格** | **完全免费，无订阅** |
| **架构** | 闭源 Electron 桌面应用 |
| **核心功能** | 按键自定义、宏命令、配置文件导入/导出、应用自动切换 |
| **插件市场** | Marketplace 提供社区插件、预设配置、图标包 |
| **支持应用** | OBS, Twitch, YouTube, Discord, Zoom, Teams 等 |
| **双模式** | 在线模式（连接 Studio 自定义）/ 离线模式（即插即用） |
| **硬件联动** | Philips Hue, Home Assistant, Govee, Nanoleaf, Yeelight |
| **多语言** | 内置 8 种语言 |
| **更新** | 终身免费软件更新 |

### 其他相关软件

| 软件 | 说明 |
|------|------|
| **Ulanzi Connect** | 手机 App (iOS/Android)，蓝牙控制灯光等设备 |
| **OBS 插件** | 集成直播场景切换 |
| **UlanziDeck Plugin SDK** | JS 插件开发 SDK（官方，Apache 2.0） |

---

## 3. 官方开源状态

### 3.1 Ulanzi Studio 本体

> ❌ **闭源。** 未公开源代码。

### 3.2 UlanziDeck Plugin SDK

> ✅ **开源，Apache 2.0 协议**

| 仓库 | 说明 |
|------|------|
| [UlanziTechnology/UlanziDeckPlugin-SDK](https://github.com/UlanziTechnology/UlanziDeckPlugin-SDK) ⭐61 | 主 SDK：manifest 参考、demo 插件、浏览器模拟器 |
| [UlanziTechnology/plugin-common-node](https://github.com/UlanziTechnology/plugin-common-node) | Node.js 主服务库 |
| [UlanziTechnology/plugin-common-html](https://github.com/UlanziTechnology/plugin-common-html) | HTML Property Inspector 库 |

插件基于 **"Ulanzi JS Plugin Development Protocol V2.1.2"**，兼容 **Ulanzi Studio 3.0.11**。

插件运行机制:
- JavaScript 编写
- 通过 WebSocket 与 Studio 通信
- 必须在 Studio 内部运行才能生效
- 不适合作为独立替代方案

---

## 4. 社区开源逆向成果

### 4.1 核心逆向项目

| 项目 | 语言 | ⭐ | 协议 | 说明 |
|------|------|----|------|------|
| **[jcalado/companion-surface-d200](https://github.com/jcalado/companion-surface-d200)** | TypeScript | 3 | MIT | Bitfocus Companion 面板插件，完整实现了按键接收 + 图标推送 + 小窗显示 |
| **[brendanwelsh/ulanzi-d100h-homebrew](https://github.com/brendanwelsh/ulanzi-d100h-homebrew)** | JS/doc | 1 | MIT | D100H 旋钮控制器逆向笔记，含 HID 协议、Studio 配置格式、SDK 踩坑记录 |

### 4.2 D200 逆向详情

**来源**: [jcalado 博客 - Ulanzi D200 as Companion Surface](https://jcalado.com/posts/ulanzi-d200-companion/)

逆向方法:
1. 使用 USBPcap 在 Windows 上抓取 Ulanzi Studio 与 D200 的 USB 通信
2. 在 Companion 插件中验证并修正了 ZIP 包格式、固件 Bug 等细节

已知问题:
- D200 内部有两个 USB 设备: `18d1:d002`（废弃/启动加载器）和 `2207:0019`（真正的 HID 设备）
- Linux 直连时可能无法枚举两个设备，需要通过 USB 2.0 Hub 解决
- 固件 Bug: ZIP 包中偏移 1016 + 1024×N 的字节不能是 0x00 或 0x7c

---

## 5. 通信协议详解 (D200)

> 基于 `companion-surface-d200/src/protocol.ts` 反推

### 5.1 设备信息

```
VID:   0x2207
PID:   0x0019
接口:  Interface 0
端点:  EP 0x01 OUT / EP 0x82 IN (两个 1024 字节中断端点)
单包:  1024 字节
```

### 5.2 数据帧格式

```
帧头  [0x7c, 0x7c]         — 2 字节，固定帧起始标记
命令  [cmd: u16 BE]        — 2 字节，大端序命令码
长度  [length: u32 LE]     — 4 字节，小端序数据长度
数据  [data...]             — 最多 1016 字节（1024 - 8 字节头）
```

### 5.3 命令列表

| 命令码 | 名称 | 方向 | 说明 |
|--------|------|------|------|
| `0x0001` | OUT_SET_BUTTONS | 主机→设备 | 上传全部按键图标（ZIP 格式） |
| `0x000d` | OUT_PARTIALLY_UPDATE_BUTTONS | 主机→设备 | 部分更新按键 |
| `0x0006` | OUT_SET_SMALL_WINDOW_DATA | 主机→设备 | 设置小窗显示模式/数据 |
| `0x000a` | OUT_SET_BRIGHTNESS | 主机→设备 | 设置亮度 |
| `0x000b` | OUT_SET_LABEL_STYLE | 主机→设备 | 设置按键标签样式 |
| `0x000f` | OUT_LOCKSCREEN | 主机→设备 | 锁定屏幕 |
| `0x0010` | OUT_UNLOCKSCREEN | 主机→设备 | 解锁屏幕 |
| `0x0101` | IN_BUTTON | 设备→主机 | 按键/旋钮事件上报 |
| `0x0303` | IN_DEVICE_INFO | 设备→主机 | 设备信息上报 |

### 5.4 图标上传协议

按键图标以 **ZIP 包** 形式通过 HID 发送:

```
ZIP 包结构:
  manifest.json   — 布局/按键配置
  Images/*.png    — 每张 196×196 像素图标

manifest.json 格式:
{
  "Buttons": [
    {
      "Index": 0,
      "ViewParam": [{
        "SmallViewMode": 0,
        "Font": { "Size": 10, "Weight": 80, ... }
      }]
    }
  ]
}

固件 Bug 规避:
  ZIP 包中偏移 1016 + 1024×N 的字节 != 0x00 且 != 0x7c
  解决方法: 如果不符合条件，重试压缩并追加随机长度填充文件
```

### 5.5 小窗模式

小窗是 D200 顶部的一个 458×196 像素区域:

| ID | 模式 | 说明 |
|----|------|------|
| `0` | STATS | CPU + RAM + GPU 占用 |
| `1` | DIAL | 模拟表盘时钟 |
| `2` | BACKGROUND | 自定义背景图 |
| `200` | DIGITAL_DATE_TIME_WEEKDAY | 数字: 日期+时间+星期 |
| `201` | DIGITAL_TIME_WEEKDAY | 数字: 时间+星期 |
| `202` | DIGITAL_TIME_DATE | 数字: 时间+日期 |
| `203` | DIGITAL_TIME | 数字: 仅时间 |

数据格式: `${mode}|${cpu}|${mem}|${time}|${gpu}|${format}|${suffix}`

### 5.6 按键事件上报

```
数据: [state:u8] [index:u8] [type:u8] [action:u8]

type:
  0x02 = encoder（旋钮）
  其他 = button（按键）

action:
  0x01 = press（按下）
  0x02 = left（旋钮左转）
  0x03 = right（旋钮右转）
  其他 = release（释放）
```

设备信息上报: ASCII 字符串，含固件版本等信息。

### 5.7 亮度调节 (OUT_SET_BRIGHTNESS)

**✅ 已被两个开源项目完整逆向并实现。**

亮度控制是协议中最简单的命令之一：

| 项目 | 命令码 | 载荷格式 | 实现状态 |
|------|--------|----------|----------|
| **companion-surface-d200** (TypeScript) | `0x000a` | 纯文本数字 (如 `"50"`) | ✅ 已实现 |

**协议细节:**

```
命令:  OUT_SET_BRIGHTNESS = 0x000a
方向:  主机 → 设备
帧:    0x7c 0x7c [0x00 0x0a] [length:4 LE] [data...]
载荷:  ASCII 数字字符串，范围 0-100（百分比）
       例如: "0"（最暗）、"50"（一半）、"100"（最亮）
封包:  单包发送，无需分块
```

**参考代码:**

```typescript
// companion-surface-d200/src/protocol.ts
export function encodeBrightness(percent: number): Buffer {
  const clamped = Math.max(0, Math.min(100, Math.round(percent)))
  return Buffer.from(String(clamped), 'utf8')
}
```

**调用示例:**

```typescript
// companion-surface-d200/src/device.ts
async setBrightness(percent: number): Promise<void> {
  await this.#writePacket(buildSimplePacket(Command.OUT_SET_BRIGHTNESS, encodeBrightness(percent)))
}
```

**注意:** companion-surface-d200 在 config 面板中**没有**暴露亮度调节给用户（缺少对应的 UI 配置项），但 device 层的 `setBrightness()` 方法已经完整实现，可直接调用。

### 5.8 各型号协议差异

| 型号 | 连接方式 | 协议状态 | 备注 |
|------|----------|----------|------|
| **D200** | USB HID | ✅ 完全逆向 | 协议基准型号 |
| **D200X** | USB-C HID + 蓝牙 | ⚠️ 未验证 | 推测与 D200 协议兼容或相近 |
| **D200H** | USB HID | ⚠️ 未验证 | 推测与 D200 协议兼容 |
| **D100H** | 仅蓝牙 (VID 0xfff1) | ⚠️ 部分逆向 | HID 可读旋钮+3键, 全功能需 Studio |
| **D100H I003** | 蓝牙 | ⚠️ 部分逆向 | 同上 |

---

## 6. Swift 重写可行性分析

### 6.1 可行性结论

> ✅ **完全可行。**

社区已完整逆向 D200 的 USB HID 通信协议，当前保留 TypeScript 实现和 JS/doc 逆向笔记作为参考。

### 6.2 推荐架构

```
┌──────────────────────────────────────────┐
│          Swift 原生 App (macOS)           │
│                                           │
│  ┌──────────────────────────────────────┐ │
│  │  HID 通信层 (IOKit)                  │ │
│  │  - IOHIDManager 发现/枚举设备        │ │
│  │  - IOHIDDevice 发送/接收报告         │ │
│  │  - 帧封装: 0x7c7c + cmd + data      │ │
│  │  - 按键事件回调解析                  │ │
│  ├──────────────────────────────────────┤ │
│  │  ZIP 打包/解包层                    │ │
│  │  - 使用 ZIPFoundation 库             │ │
│  │  - 生成 manifest.json                │ │
│  │  - PNG 图标 196×196 处理            │ │
│  │  - 固件 Bug 规避（填充字节检测）     │ │
│  ├──────────────────────────────────────┤ │
│  │  业务逻辑层                          │ │
│  │  - 动作/宏/快捷键管理                │ │
│  │  - 配置文件存储 (JSON/PropertyList)  │ │
│  │  - 应用监听与自动切换                 │ │
│  │  - Scriptable 支持 (Swift/JS)       │ │
│  ├──────────────────────────────────────┤ │
│  │  UI 层 (SwiftUI)                    │ │
│  │  - 所见即所得的布局编辑器            │ │
│  │  - 拖拽绑定动作                     │ │
│  │  - 图标/颜色自定义                  │ │
│  │  - 小窗模式实时预览                 │ │
│  └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

### 6.3 关键依赖

| 需求 | macOS 原生方案 |
|------|---------------|
| HID 通信 | `IOKit` / `IOHIDManager` / `IOHIDDevice` (系统框架) |
| ZIP 处理 | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (Swift Package) |
| PNG 处理 | `CoreGraphics` / `ImageIO` (系统框架) |
| UI 框架 | `SwiftUI` (系统框架) |
| 脚本支持 | `JavaScriptCore` (系统框架) 或 Swift 原生 |

### 6.4 可参考代码映射

| 参考文件 | 语言 | Swift 对应方案 |
|----------|------|---------------|
| `companion-surface-d200/src/protocol.ts` | TypeScript | 直接翻译为 `HIDProtocol.swift` |
| `companion-surface-d200/src/device.ts` | TypeScript | 用 `IOHIDDevice` API 替代 |
| `companion-surface-d200/src/zip-builder.ts` | TypeScript | 用 `ZIPFoundation` 替代 |
| `companion-surface-d200/src/instance.ts` | TypeScript | SwiftUI ViewModel 层 |

### 6.5 工作量估算

| 阶段 | 内容 | 预估时间 |
|------|------|----------|
| **P0** | HID 通信层 + 协议帧编解码 | 2-3 天 |
| **P0** | ZIP 打包 + 图标推送 | 1-2 天 |
| **P1** | 按键事件接收 + 动作绑定 | 2-3 天 |
| **P1** | 小窗模式控制 | 1 天 |
| **P2** | SwiftUI 布局编辑器 | 3-5 天 |
| **P2** | 配置存储/导入导出 | 1-2 天 |
| **P3** | 插件/脚本系统 | 5-7 天 |
| **P3** | 多设备/多型号支持 | 3-5 天 |

### 6.6 风险点

1. **D200X 协议兼容性**: 尚未经社区验证，需实测确认
2. **macOS HID 权限**: 需要用户授权辅助功能权限
3. **蓝牙设备**: D100H 的 BLE HID 协议不同，需额外逆向
4. **固件更新**: 新固件可能改变协议行为
5. **离线模式限制**: Studio 关闭后设备恢复默认布局（不可存自定义布局到硬件）

---

## 7. 参考资料

### 官方资源

| 资源 | 链接 |
|------|------|
| Ulanzi 官网 | https://www.ulanzi.com |
| Ulanzi App 下载页 | https://www.ulanzi.com/pages/ulanzi-app |
| Ulanzi 文档中心 | https://www.ulanzi.com/pages/documentation |
| 固件/手册下载 | https://www.ulanzi.com/pages/downloads |
| 社区论坛 | https://bbs.ulanzistudio.com |
| 插件市场 | https://ugc.ulanzistudio.com |

### 开源仓库

| 仓库 | 链接 |
|------|------|
| UlanziDeck Plugin SDK | https://github.com/UlanziTechnology/UlanziDeckPlugin-SDK |
| plugin-common-node | https://github.com/UlanziTechnology/plugin-common-node |
| plugin-common-html | https://github.com/UlanziTechnology/plugin-common-html |
| companion-surface-d200 (TS 实现) | https://github.com/jcalado/companion-surface-d200 |
| ulanzi-d100h-homebrew (逆向笔记) | https://github.com/brendanwelsh/ulanzi-d100h-homebrew |

### 博文

| 标题 | 链接 |
|------|------|
| Ulanzi D200 as Companion Surface (逆向过程详解) | https://jcalado.com/posts/ulanzi-d200-companion/ |
| Ulanzi Launches D200X Creative Deck | https://petapixel.com/2026/04/17/ulanzi-launches-d200x-creative-deck-a-control-hub-and-8-in-1-dock/ |
| Ulanzi D200X and Dial Review | https://fstoppers.com/reviews/ulanzi-d200x-and-dial-review-can-they-improve-your-editing-workflow-900870 |
| Ulanzi D200X 挑战 Logitech/Elgato | https://www.forbes.com/sites/marksparrow/2026/04/17/ulanzi-launches-d200x-creative-deck-to-challenge-logitech-and-elgato/ |
