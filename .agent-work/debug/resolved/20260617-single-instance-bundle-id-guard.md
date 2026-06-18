# 单实例 bundle id 保护

- 时间：2026-06-17 22:07 MDT
- 现象：用户发现本机同时存在 2 个 `Ulanzi Deck` 进程，可能导致 HID 单格刷新后设备状态被另一个进程覆盖。
- 根因：只依赖 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 不能防止两个不同路径、相同 bundle id 的 app 同时启动；同时旧版本进程不会持有新实现里的文件锁。

## 已验证事实

- `/Applications/Ulanzi Deck.app/Contents/MacOS/Ulanzi Deck` 在测试期间已运行，PID 为 `59246`。
- 初版启动锁会让 XCTest host 因同 bundle id 拿不到锁而提前退出，表现为 `Early unexpected exit, operation never finished bootstrapping`。
- `INFOPLIST_KEY_LSMultipleInstancesProhibited = YES` 出现在 build settings 中，但没有进入 generated `Contents/Info.plist`。
- 后续需求改为重复启动时显示自定义 alert 和已有进程信息，因此不能再使用 `LSMultipleInstancesProhibited`。该 key 会让 LaunchServices 在 app 代码运行前拦截重复启动，导致新进程没有机会显示自定义提示。
- Xcode 文件系统同步分组会把显式 `Info.plist` 当资源复制，需要通过 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除。

## 修复

- 启动时先使用按 bundle id 派生的 `flock` 文件锁，防止两个新版本副本同时启动。
- 拿到锁后仍检查是否存在更早启动的同 bundle id 进程；如果存在，不进入主界面、不碰 HID，关闭重复实例的临时 SwiftUI 挂载窗口后显示独立 `NSAlert`。
- XCTest 环境通过 `XCTestConfigurationFilePath` 跳过单实例保护，避免测试 host 被本机正在运行的 app 拦截。
- 显式维护 `UlanziDeckSwift/Info.plist`，但不包含 `LSMultipleInstancesProhibited`，让 app 自己处理重复启动提示。
- alert 文案为中文，能获取到时显示已有进程 PID 和 app 路径；按钮只有“退出”。

## 验证

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

结果：通过。

产物检查：

```bash
plutil -p ~/Library/Developer/Xcode/DerivedData/UlanziDeckSwift-awbjgsodgfqkzwgvhebjwrfzykbz/Build/Products/Debug/Ulanzi\ Deck.app/Contents/Info.plist | rg 'LSMultipleInstancesProhibited|CFBundleIdentifier'
```

确认 `LSMultipleInstancesProhibited` 不存在。
