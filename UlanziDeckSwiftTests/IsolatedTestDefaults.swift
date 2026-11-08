import Foundation

/// 为单个测试创建一次性隔离的 UserDefaults suite，返回 defaults 实例与清理闭包。
///
/// 自定义 suite 首次写入时 cfprefsd 会在 ~/Library/Preferences 创建 `<suiteName>.plist`；
/// `removePersistentDomain(forName:)` 只清空域内容，且 cfprefsd 对已删除域的空 plist 落盘
/// 是异步的（实测可滞后数秒），测试内立即删除文件仍可能被稍后落盘的空 plist 覆盖。
/// 因此除测试内即时清理外，这里还登记每个 suite 的 plist 路径，并注册一次进程退出清扫兜底：
/// 退出时轮询删除本轮登记的文件，并按文件名模式顺带清理历史残留，保证测试结束后
/// ~/Library/Preferences 不残留 `UlanziDeckSwiftTests.*.plist`。
func makeIsolatedTestDefaults() throws -> (defaults: UserDefaults, cleanup: () -> Void) {
    enum SuiteCreationError: Error {
        case suiteUnavailable(String)
    }

    let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw SuiteCreationError.suiteUnavailable(suiteName)
    }
    let suitePlistURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Preferences/\(suiteName).plist")

    registeredSuitePlistLock.lock()
    let isFirstSuite = registeredSuitePlistPaths.isEmpty
    registeredSuitePlistPaths.append(suitePlistURL.path)
    registeredSuitePlistLock.unlock()
    if isFirstSuite {
        atexit(sweepRegisteredSuitePlistFilesAtExit)
    }

    return (
        defaults: defaults,
        cleanup: {
            defaults.removePersistentDomain(forName: suiteName)
            // cfprefsd 异步落盘，这里尽力删一次；尚未落盘的残留交给进程退出清扫兜底
            try? FileManager.default.removeItem(at: suitePlistURL)
        }
    )
}

private let registeredSuitePlistLock = NSLock()
private var registeredSuitePlistPaths: [String] = []

/// 进程退出时轮询清理测试残留的 plist。
/// cfprefsd 的空 plist 落盘可能滞后数秒，只删一次会漏，因此轮询约 12 秒兜底；
/// 同时按 `UlanziDeckSwiftTests.` 前缀清理历史残留（例如上一轮异常退出留下的文件）。
private func sweepRegisteredSuitePlistFilesAtExit() {
    let preferencesDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Preferences")
    for _ in 0..<48 {
        Thread.sleep(forTimeInterval: 0.25)
        registeredSuitePlistLock.lock()
        let registeredPaths = registeredSuitePlistPaths
        registeredSuitePlistLock.unlock()
        for path in registeredPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: preferencesDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        for entry in entries
        where entry.lastPathComponent.hasPrefix("UlanziDeckSwiftTests.")
            && entry.pathExtension == "plist" {
            try? FileManager.default.removeItem(at: entry)
        }
    }
}
