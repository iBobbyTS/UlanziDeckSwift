import Foundation
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
}

nonisolated struct H200HIDDeckSyncer: H200DeckSyncing {
    private let packageBuilder: H200ButtonPackageBuilder

    nonisolated init(packageBuilder: H200ButtonPackageBuilder = H200ButtonPackageBuilder()) {
        self.packageBuilder = packageBuilder
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let package: H200ButtonPackage
        do {
            package = try packageBuilder.buildPackage(displays: displays)
        } catch {
            return .failure(.packageBuildFailed(String(describing: error)))
        }

        let packets = H200PacketBuilder.buildChunkedPackets(command: H200Command.outSetButtons, payload: package.payload)
        return sendPackets(packets, package: package)
    }

    private func sendPackets(_ packets: [Data], package: H200ButtonPackage) -> H200DeckSyncResult {
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
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
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
            return .failure(.notConnected)
        }

        let openResult = HIDReturnCode(rawValue: IOHIDDeviceOpen(device.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)))
        guard openResult.rawValue == kIOReturnSuccess else {
            if openResult.indicatesOccupiedPort {
                return .failure(.communicationPortOccupied(openResult))
            }
            if openResult.indicatesPermissionDenied {
                return .failure(.permissionDenied(openResult))
            }

            return .failure(.openFailed(openResult))
        }
        defer {
            IOHIDDeviceClose(device.device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        for packet in packets {
            let writeResult = packet.withUnsafeBytes { rawBuffer in
                IOHIDDeviceSetReport(
                    device.device,
                    kIOHIDReportTypeOutput,
                    CFIndex(0),
                    rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    packet.count
                )
            }
            guard writeResult == kIOReturnSuccess else {
                return .failure(.writeFailed(HIDReturnCode(rawValue: writeResult)))
            }
        }

        return .success(H200DeckSyncSummary(
            payloadByteCount: package.payload.count,
            packetCount: packets.count,
            displayCount: package.displayCount
        ))
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
