import Foundation
import OSLog

final class ShellCommandExecutor {
    static let shared = ShellCommandExecutor()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "UlanziDeckSwift", category: "shell-command")

    @discardableResult
    func execute(shell: String, command: String) -> Process? {
        let normalizedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommand.isEmpty else { return nil }
        let process = Process()
        let normalizedShell = shell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "zsh" : shell.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedShell.contains("/") {
            process.executableURL = URL(fileURLWithPath: normalizedShell)
            process.arguments = ["-lc", normalizedCommand]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [normalizedShell, "-lc", normalizedCommand]
        }
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.terminationHandler = { [logger] process in
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if process.terminationStatus != 0 {
                logger.error("Shell 命令退出失败，状态码 \(process.terminationStatus, privacy: .public)，stderr: \(stderr, privacy: .public)")
            } else if !stderr.isEmpty {
                logger.warning("Shell 命令 stderr: \(stderr, privacy: .public)")
            }
        }
        do {
            try process.run()
            return process
        } catch {
            logger.error("Shell 命令启动失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
