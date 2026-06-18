import Foundation
import IOKit.hid

struct H200HIDDiscovery: H200Discovering, Sendable {
    nonisolated init() {}

    func discoverH200() -> H200DiscoveryResult {
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
                return .communicationPortOccupied(managerOpenResult)
            }

            return .managerOpenFailed(managerOpenResult)
        }
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return .notConnected
        }

        let candidates = devices
            .map(H200DeviceCandidate.init(device:))
            .filter(\.identity.isProtocolInterface)
            .sorted { first, second in
                if first.identity.locationID == second.identity.locationID {
                    return first.identity.serialNumber < second.identity.serialNumber
                }

                return first.identity.locationID < second.identity.locationID
            }

        guard let candidate = candidates.first else {
            return .notConnected
        }

        let openResult = IOHIDDeviceOpen(candidate.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        switch openResult {
        case kIOReturnSuccess:
            IOHIDDeviceClose(candidate.device, IOOptionBits(kIOHIDOptionsTypeNone))
            return .connected(candidate.identity)
        case kIOReturnBusy, kIOReturnExclusiveAccess:
            return .occupied(candidate.identity, HIDReturnCode(rawValue: openResult))
        case kIOReturnNotPermitted, kIOReturnNotPrivileged:
            return .permissionDenied(candidate.identity, HIDReturnCode(rawValue: openResult))
        default:
            return .openFailed(candidate.identity, HIDReturnCode(rawValue: openResult))
        }
    }
}

nonisolated private struct H200DeviceCandidate {
    let device: IOHIDDevice
    let identity: H200DeviceIdentity

    init(device: IOHIDDevice) {
        self.device = device
        identity = H200DeviceIdentity(
            vendorID: H200DeviceCandidate.intProperty(device, kIOHIDVendorIDKey),
            productID: H200DeviceCandidate.intProperty(device, kIOHIDProductIDKey),
            locationID: H200DeviceCandidate.intProperty(device, kIOHIDLocationIDKey),
            primaryUsagePage: H200DeviceCandidate.intProperty(device, kIOHIDPrimaryUsagePageKey),
            primaryUsage: H200DeviceCandidate.intProperty(device, kIOHIDPrimaryUsageKey),
            maxInputReportSize: H200DeviceCandidate.intProperty(device, kIOHIDMaxInputReportSizeKey),
            maxOutputReportSize: H200DeviceCandidate.intProperty(device, kIOHIDMaxOutputReportSizeKey),
            serialNumber: H200DeviceCandidate.stringProperty(device, kIOHIDSerialNumberKey),
            manufacturer: H200DeviceCandidate.stringProperty(device, kIOHIDManufacturerKey),
            product: H200DeviceCandidate.stringProperty(device, kIOHIDProductKey)
        )
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber else {
            return 0
        }

        return number.intValue
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String {
        IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
    }
}
