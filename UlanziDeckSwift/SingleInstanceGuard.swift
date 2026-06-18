import AppKit
import Darwin
import Foundation

nonisolated protocol SingleInstanceLocking {
    func tryAcquire(identifier: String) -> Bool
}

nonisolated protocol ExistingApplicationActivating {
    func activateExistingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> Bool
}

nonisolated struct SingleInstanceGuard {
    private let bundleIdentifier: String
    private let locker: SingleInstanceLocking
    private let activator: ExistingApplicationActivating
    private let currentLaunchDate: Date
    private let existingApplicationGraceInterval: TimeInterval

    init(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.iBobby.UlanziDeckSwift",
        locker: SingleInstanceLocking = FileSingleInstanceLocker.shared,
        activator: ExistingApplicationActivating = WorkspaceExistingApplicationActivator(),
        currentLaunchDate: Date = NSRunningApplication.current.launchDate ?? Date(),
        existingApplicationGraceInterval: TimeInterval = 2
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.locker = locker
        self.activator = activator
        self.currentLaunchDate = currentLaunchDate
        self.existingApplicationGraceInterval = existingApplicationGraceInterval
    }

    func acquireOrActivateExisting() -> Bool {
        guard locker.tryAcquire(identifier: bundleIdentifier) else {
            _ = activator.activateExistingApplication(bundleIdentifier: bundleIdentifier, launchedBefore: nil)
            return false
        }

        let olderLaunchDate = currentLaunchDate.addingTimeInterval(-existingApplicationGraceInterval)
        if activator.activateExistingApplication(bundleIdentifier: bundleIdentifier, launchedBefore: olderLaunchDate) {
            return false
        }

        return true
    }
}

nonisolated final class FileSingleInstanceLocker: SingleInstanceLocking, @unchecked Sendable {
    static let shared = FileSingleInstanceLocker()

    private let lockDirectory: URL
    private var fileDescriptor: Int32?

    init(lockDirectory: URL = FileManager.default.temporaryDirectory) {
        self.lockDirectory = lockDirectory
    }

    deinit {
        releaseLock()
    }

    func tryAcquire(identifier: String) -> Bool {
        if fileDescriptor != nil {
            return true
        }

        let lockURL = lockDirectory.appendingPathComponent("\(Self.sanitizedIdentifier(identifier)).lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            return false
        }

        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }

        fileDescriptor = fd
        return true
    }

    private func releaseLock() {
        guard let fileDescriptor else {
            return
        }

        close(fileDescriptor)
        self.fileDescriptor = nil
    }

    private static func sanitizedIdentifier(_ identifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return String(identifier.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
    }
}

nonisolated struct WorkspaceExistingApplicationActivator: ExistingApplicationActivating {
    func activateExistingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> Bool {
        guard let application = existingApplication(
            bundleIdentifier: bundleIdentifier,
            launchedBefore: latestLaunchDate
        ) else {
            return false
        }

        application.activate(options: [.activateAllWindows])
        return true
    }

    private func existingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> NSRunningApplication? {
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { application in
                guard application.processIdentifier != currentProcessID else {
                    return false
                }

                guard let latestLaunchDate else {
                    return true
                }

                guard let launchDate = application.launchDate else {
                    return false
                }

                return launchDate < latestLaunchDate
            }
            .sorted { left, right in
                (left.launchDate ?? .distantFuture) < (right.launchDate ?? .distantFuture)
            }
            .first
    }
}
