import AppKit
import Darwin
import Foundation
import NetFS

protocol SMBServerConnecting {
    @MainActor
    func connect(to address: String) -> Bool
}

protocol NetFSMounting {
    @MainActor
    func mount(url: URL, completion: @escaping (Int) -> Void) -> Int
}

protocol SMBURLOpening {
    @MainActor
    func open(_ url: URL) -> Bool
}

struct SMBServerConnector: SMBServerConnecting {
    private let netFSMounter: NetFSMounting
    private let urlOpener: SMBURLOpening

    init(
        netFSMounter: NetFSMounting = SystemNetFSMounter(),
        urlOpener: SMBURLOpening = WorkspaceSMBURLOpener()
    ) {
        self.netFSMounter = netFSMounter
        self.urlOpener = urlOpener
    }

    @MainActor
    func connect(to address: String) -> Bool {
        guard let validatedAddress = DeckKeySMBServerConfiguration.validatedAddress(address),
              let fullURLString = DeckKeySMBServerConfiguration(address: validatedAddress).fullURLString,
              let url = URL(string: fullURLString)
        else {
            return false
        }
        let logDescription = SMBServerLogFormatter.redactedDescription(for: url)

        let status = netFSMounter.mount(url: url) { status in
            guard status != 0 else {
                return
            }

            if status == EPERM {
                NSLog("NetFS 连接 SMB 服务器被系统拒绝：%@，改用系统打开。返回码：%d", logDescription, status)
                _ = urlOpener.open(url)
                return
            }

            NSLog("连接 SMB 服务器失败：%@，返回码：%d", logDescription, status)
        }

        guard status != 0 else {
            return true
        }

        if status == EPERM {
            NSLog("NetFS 连接 SMB 服务器被系统拒绝：%@，改用系统打开。返回码：%d", logDescription, status)
            return urlOpener.open(url)
        }

        NSLog("连接 SMB 服务器失败：%@，返回码：%d", logDescription, status)
        return false
    }
}

nonisolated enum SMBServerLogFormatter {
    static func redactedDescription(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "smb://<invalid>"
        }

        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        guard let sanitizedURLString = components.string,
              !DeckKeySMBServerConfiguration.containsUserInfo(in: sanitizedURLString)
        else {
            return "smb://<invalid>"
        }
        return sanitizedURLString
    }
}

private struct SystemNetFSMounter: NetFSMounting {
    @MainActor
    func mount(url: URL, completion: @escaping (Int) -> Void) -> Int {
        let openOptions = NSMutableDictionary()
        openOptions[kNAUIOptionKey] = kNAUIOptionAllowUI
        var requestID: AsyncRequestID?
        let status = NetFSMountURLAsync(
            url as CFURL,
            nil,
            nil,
            nil,
            openOptions as CFMutableDictionary,
            nil,
            &requestID,
            DispatchQueue.main
        ) { status, _, _ in
            completion(Int(status))
        }

        return Int(status)
    }
}

private struct WorkspaceSMBURLOpener: SMBURLOpening {
    @MainActor
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}
