import Foundation
import Dispatch
import IOKit.hid

nonisolated struct H200DeckSyncSummary: Equatable {
    let payloadByteCount: Int
    let packetCount: Int
    let displayCount: Int
}

nonisolated enum H200DeckSyncResult: Equatable {
    case success(H200DeckSyncSummary)
    case failure(H200DeckSyncFailure)
}

nonisolated enum H200DeckSyncFailure: Error, Equatable {
    case notConnected
    case communicationPortOccupied(HIDReturnCode)
    case permissionDenied(HIDReturnCode)
    case openFailed(HIDReturnCode)
    case writeFailed(HIDReturnCode)
    case packageBuildFailed(String)

    var alertTitle: String {
        switch self {
        case .communicationPortOccupied:
            return "H200 通信端口被占用"
        case .permissionDenied:
            return "没有权限写入 H200"
        case .notConnected:
            return "未检测到 H200"
        case .openFailed, .writeFailed, .packageBuildFailed:
            return "无法同步 H200"
        }
    }

    var alertMessage: String {
        switch self {
        case .notConnected:
            return "准备同步按键包时没有找到 H200。请重新连接设备后重试。"
        case let .communicationPortOccupied(code):
            return "有其他应用正在占用 H200 通信端口，按键包尚未发送。请关闭 Ulanzi Studio 或其他控制软件后重试。返回码：\(code.name)。"
        case let .permissionDenied(code):
            return "macOS 拒绝写入 H200，按键包尚未发送。返回码：\(code.name)。"
        case let .openFailed(code):
            return "打开 H200 通信接口失败，按键包尚未发送。返回码：\(code.name)。"
        case let .writeFailed(code):
            return "写入 H200 通信接口失败，按键包尚未完整发送。返回码：\(code.name)。"
        case let .packageBuildFailed(reason):
            return "生成 H200 按键包失败：\(reason)。"
        }
    }
}

nonisolated protocol H200DeckSyncing {
    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult
    func close()
}

extension H200DeckSyncing {
    nonisolated func close() {}
}

nonisolated final class H200HIDDeckSyncer: H200DeckSyncing {
    private let packageBuilder: H200ButtonPackageBuilder
    private var connection: H200HIDConnection?

    nonisolated init(packageBuilder: H200ButtonPackageBuilder = H200ButtonPackageBuilder()) {
        self.packageBuilder = packageBuilder
    }

    deinit {
        close()
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let package: H200ButtonPackage
        do {
            package = try packageBuilder.buildPackage(displays: displays)
        } catch {
            return .failure(.packageBuildFailed(String(describing: error)))
        }

        let packets = H200StartupPacketBuilder.buildStartupPackets(package: package)
        return sendPackets(packets, package: package)
    }

    func close() {
        connection?.close()
        connection = nil
    }

    private func sendPackets(_ packets: [Data], package: H200ButtonPackage) -> H200DeckSyncResult {
        let connection: H200HIDConnection
        switch openConnectionIfNeeded() {
        case let .success(openConnection):
            connection = openConnection
        case let .failure(error):
            return .failure(error)
        }

        if let error = connection.writePackets(packets) {
            close()
            return .failure(error)
        }
        connection.startKeepAlive()

        return .success(H200DeckSyncSummary(
            payloadByteCount: package.payload.count,
            packetCount: packets.count,
            displayCount: package.displayCount
        ))
    }

    private func openConnectionIfNeeded() -> Result<H200HIDConnection, H200DeckSyncFailure> {
        if let connection {
            return .success(connection)
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: H200DeviceTarget.vendorID,
            kIOHIDProductIDKey as String: H200DeviceTarget.productID,
            kIOHIDPrimaryUsagePageKey as String: H200DeviceTarget.primaryUsagePage,
            kIOHIDPrimaryUsageKey as String: H200DeviceTarget.primaryUsage,
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let managerOpenResult = HIDReturnCode(rawValue: IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)))
        guard managerOpenResult.rawValue == kIOReturnSuccess else {
            if managerOpenResult.indicatesOccupiedPort {
                return .failure(.communicationPortOccupied(managerOpenResult))
            }

            return .failure(.openFailed(managerOpenResult))
        }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices
                .map(H200WritableDevice.init(device:))
                .filter(\.identity.isProtocolInterface)
                .sorted(by: { first, second in
                    if first.identity.locationID == second.identity.locationID {
                        return first.identity.serialNumber < second.identity.serialNumber
                    }

                    return first.identity.locationID < second.identity.locationID
                })
                .first
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return .failure(.notConnected)
        }

        let openResult = HIDReturnCode(rawValue: IOHIDDeviceOpen(device.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)))
        guard openResult.rawValue == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            if openResult.indicatesOccupiedPort {
                return .failure(.communicationPortOccupied(openResult))
            }
            if openResult.indicatesPermissionDenied {
                return .failure(.permissionDenied(openResult))
            }

            return .failure(.openFailed(openResult))
        }

        let connection = H200HIDConnection(manager: manager, device: device.device)
        self.connection = connection
        return .success(connection)
    }
}

// HID 句柄只通过内部串行队列访问；DispatchSource 的 @Sendable 闭包需要显式声明。
nonisolated private final class H200HIDConnection: @unchecked Sendable {
    private static let keepAliveInitialDelay: DispatchTimeInterval = .seconds(1)
    private static let keepAliveInterval: DispatchTimeInterval = .seconds(2)

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let queue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.H200HIDConnection")
    private var keepAliveTimer: DispatchSourceTimer?
    private var isOpen = true

    init(manager: IOHIDManager, device: IOHIDDevice) {
        self.manager = manager
        self.device = device
    }

    deinit {
        close()
    }

    func close() {
        queue.sync {
            guard isOpen else {
                return
            }

            stopKeepAliveOnQueue()
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            isOpen = false
        }
    }

    func writePackets(_ packets: [Data]) -> H200DeckSyncFailure? {
        queue.sync {
            guard isOpen else {
                return .notConnected
            }

            return writePacketsOnQueue(packets)
        }
    }

    func startKeepAlive() {
        queue.async { [weak self] in
            guard let self, self.isOpen else {
                return
            }

            self.stopKeepAliveOnQueue()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + Self.keepAliveInitialDelay, repeating: Self.keepAliveInterval)
            timer.setEventHandler { [weak self] in
                guard let self, self.isOpen else {
                    return
                }

                _ = self.writePacketsOnQueue([H200SmallWindowDataPacketBuilder.backgroundModePacket()])
            }
            self.keepAliveTimer = timer
            timer.resume()
        }
    }

    private func stopKeepAliveOnQueue() {
        keepAliveTimer?.setEventHandler {}
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
    }

    private func writePacketsOnQueue(_ packets: [Data]) -> H200DeckSyncFailure? {
        for packet in packets {
            let writeResult = packet.withUnsafeBytes { rawBuffer in
                IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeOutput,
                    CFIndex(0),
                    rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    packet.count
                )
            }
            guard writeResult == kIOReturnSuccess else {
                return .writeFailed(HIDReturnCode(rawValue: writeResult))
            }
        }

        return nil
    }
}

nonisolated private struct H200WritableDevice {
    let device: IOHIDDevice
    let identity: H200DeviceIdentity

    nonisolated init(device: IOHIDDevice) {
        self.device = device
        identity = H200DeviceIdentity(
            vendorID: H200WritableDevice.intProperty(device, kIOHIDVendorIDKey),
            productID: H200WritableDevice.intProperty(device, kIOHIDProductIDKey),
            locationID: H200WritableDevice.intProperty(device, kIOHIDLocationIDKey),
            primaryUsagePage: H200WritableDevice.intProperty(device, kIOHIDPrimaryUsagePageKey),
            primaryUsage: H200WritableDevice.intProperty(device, kIOHIDPrimaryUsageKey),
            maxInputReportSize: H200WritableDevice.intProperty(device, kIOHIDMaxInputReportSizeKey),
            maxOutputReportSize: H200WritableDevice.intProperty(device, kIOHIDMaxOutputReportSizeKey),
            serialNumber: H200WritableDevice.stringProperty(device, kIOHIDSerialNumberKey),
            manufacturer: H200WritableDevice.stringProperty(device, kIOHIDManufacturerKey),
            product: H200WritableDevice.stringProperty(device, kIOHIDProductKey)
        )
    }

    nonisolated private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber else {
            return 0
        }

        return number.intValue
    }

    nonisolated private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String {
        IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
    }
}
