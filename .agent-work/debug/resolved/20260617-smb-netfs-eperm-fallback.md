# SMB NetFS EPERM fallback

## 现象

用户配置 `ibobby-nas.local` 后，`NetFSMountURLAsync` 日志显示：

```text
连接 SMB 服务器失败：smb://ibobby-nas.local，返回码：1
```

本地确认 `errno` 1 是 `EPERM / Operation not permitted`。

## 已确认事实

- `SMBServerConnector` 已使用 `NetFSMountURLAsync`，`kNAUIOptionAllowUI`，并新增 sandbox `com.apple.security.network.client`。
- NetFS 文档说明正数返回码按 `errno` 解释。
- `EPERM` 表示系统拒绝直接挂载调用；这不同于服务器不存在、认证失败或用户取消。
- 为保留“先尝试 NetFS”的行为，当前修复策略是仅当 NetFS 立即返回 `EPERM` 时降级到 `NSWorkspace.shared.open(smb://...)`。
- 当前剩余失败是测试代码编译问题：`EPERM`/`ENOENT` 是 `Int32`，测试替身初始化参数是 `Int`；`map(\.absoluteString)` 在失败上下文里推断不稳。

## 当前假设

根因不是 SMB 地址格式，而是 sandbox/系统权限拒绝直接 NetFS 挂载。`EPERM` 降级到系统 URL 打开可以复用 Finder/系统挂载路径。

## 验证命令

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

## 下一步

修正测试类型，重跑测试。若通过，将此 note 移到 `resolved/` 并更新 `INDEX.md`。

## 结论

真实日志来自 `NetFSMountURLAsync` 的完成回调，所以只处理同步返回值不够。最终实现同时处理：

- `NetFSMountURLAsync` 立即返回 `EPERM`：直接降级 `NSWorkspace.shared.open(url)`。
- 异步完成回调返回 `EPERM`：同样降级 `NSWorkspace.shared.open(url)`。
- 其它错误：保留失败，不自动打开，避免吞掉服务器不存在、认证失败等语义。

## 验证结果

`2026-06-17 19:52` 运行：

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

结果：`TEST SUCCEEDED`。
