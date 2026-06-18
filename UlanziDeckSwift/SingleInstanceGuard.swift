import AppKit
import Darwin
import Foundation

nonisolated protocol SingleInstanceLocking {
    func tryAcquire(identifier: String) -> Bool
}

nonisolated protocol ExistingApplicationLocating {
    func existingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> ExistingApplication?
}

nonisolated struct SingleInstanceGuard {
    enum AcquisitionResult: Equatable {
        case acquired
        case blockedByExistingApplication(ExistingApplication)
        case blockedByUnknownApplication
    }

    private let bundleIdentifier: String
    private let locker: SingleInstanceLocking
    private let locator: ExistingApplicationLocating
    private let currentLaunchDate: Date
    private let existingApplicationGraceInterval: TimeInterval

    init(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.iBobby.UlanziDeckSwift",
        locker: SingleInstanceLocking = FileSingleInstanceLocker.shared,
        locator: ExistingApplicationLocating = WorkspaceExistingApplicationLocator(),
        currentLaunchDate: Date = NSRunningApplication.current.launchDate ?? Date(),
        existingApplicationGraceInterval: TimeInterval = 2
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.locker = locker
        self.locator = locator
        self.currentLaunchDate = currentLaunchDate
        self.existingApplicationGraceInterval = existingApplicationGraceInterval
    }

    func acquire() -> AcquisitionResult {
        guard locker.tryAcquire(identifier: bundleIdentifier) else {
            guard let existingApplication = locator.existingApplication(
                bundleIdentifier: bundleIdentifier,
                launchedBefore: nil
            ) else {
                return .blockedByUnknownApplication
            }

            return .blockedByExistingApplication(existingApplication)
        }

        let olderLaunchDate = currentLaunchDate.addingTimeInterval(-existingApplicationGraceInterval)
        if let existingApplication = locator.existingApplication(
            bundleIdentifier: bundleIdentifier,
            launchedBefore: olderLaunchDate
        ) {
            return .blockedByExistingApplication(existingApplication)
        }

        return .acquired
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

nonisolated struct ExistingApplication: Equatable {
    let processIdentifier: pid_t
    let bundleURL: URL?

    init(
        processIdentifier: pid_t,
        bundleURL: URL?
    ) {
        self.processIdentifier = processIdentifier
        self.bundleURL = bundleURL
    }

    static func == (lhs: ExistingApplication, rhs: ExistingApplication) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier && lhs.bundleURL == rhs.bundleURL
    }
}

nonisolated struct WorkspaceExistingApplicationLocator: ExistingApplicationLocating {
    func existingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> ExistingApplication? {
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
            .map { application in
                ExistingApplication(
                    processIdentifier: application.processIdentifier,
                    bundleURL: application.bundleURL
                )
            }
    }
}
