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
        let normalizedAddress = DeckKeySMBServerConfiguration.normalizedAddress(address)
        guard let fullURLString = DeckKeySMBServerConfiguration(address: normalizedAddress).fullURLString,
              let url = URL(string: fullURLString)
        else {
            return false
        }

        let status = netFSMounter.mount(url: url) { status in
            guard status != 0 else {
                return
            }

            if status == EPERM {
                NSLog("NetFS 连接 SMB 服务器被系统拒绝：%@，改用系统打开。返回码：%d", fullURLString, status)
                _ = urlOpener.open(url)
                return
            }

            NSLog("连接 SMB 服务器失败：%@，返回码：%d", fullURLString, status)
        }

        guard status != 0 else {
            return true
        }

        if status == EPERM {
            NSLog("NetFS 连接 SMB 服务器被系统拒绝：%@，改用系统打开。返回码：%d", fullURLString, status)
            return urlOpener.open(url)
        }

        NSLog("连接 SMB 服务器失败：%@，返回码：%d", fullURLString, status)
        return false
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
