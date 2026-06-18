# 单实例 bundle id 保护

- 时间：2026-06-17 22:07 MDT
- 现象：用户发现本机同时存在 2 个 `Ulanzi Deck` 进程，可能导致 HID 单格刷新后设备状态被另一个进程覆盖。
- 根因：只依赖 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 不能防止两个不同路径、相同 bundle id 的 app 同时启动；同时旧版本进程不会持有新实现里的文件锁。

## 已验证事实

- `/Applications/Ulanzi Deck.app/Contents/MacOS/Ulanzi Deck` 在测试期间已运行，PID 为 `59246`。
- 初版启动锁会让 XCTest host 因同 bundle id 拿不到锁而提前退出，表现为 `Early unexpected exit, operation never finished bootstrapping`。
- `INFOPLIST_KEY_LSMultipleInstancesProhibited = YES` 出现在 build settings 中，但没有进入 generated `Contents/Info.plist`；改为显式 `UlanziDeckSwift/Info.plist` 后，产物中确认有 `LSMultipleInstancesProhibited => true`。
- Xcode 文件系统同步分组会把显式 `Info.plist` 当资源复制，需要通过 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除。

## 修复

- 启动时先使用按 bundle id 派生的 `flock` 文件锁，防止两个新版本副本同时启动。
- 拿到锁后仍检查是否存在更早启动的同 bundle id 进程；如果存在，激活已有进程并退出，覆盖旧版本不持有新锁的场景。
- XCTest 环境通过 `XCTestConfigurationFilePath` 跳过单实例保护，避免测试 host 被本机正在运行的 app 拦截。
- 显式维护 `UlanziDeckSwift/Info.plist`，包含 `LSMultipleInstancesProhibited` 作为 LaunchServices 层面的软保护。

## 验证

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

结果：通过。

产物检查：

```bash
plutil -p ~/Library/Developer/Xcode/DerivedData/UlanziDeckSwift-awbjgsodgfqkzwgvhebjwrfzykbz/Build/Products/Debug/Ulanzi\ Deck.app/Contents/Info.plist | rg 'LSMultipleInstancesProhibited|CFBundleIdentifier'
```

确认 `LSMultipleInstancesProhibited => true` 且 `Contents/Resources/Info.plist` 不存在。
