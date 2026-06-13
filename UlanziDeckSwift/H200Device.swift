import Foundation

struct H200DeviceIdentity: Equatable {
    let vendorID: Int
    let productID: Int
    let locationID: Int
    let primaryUsagePage: Int
    let primaryUsage: Int
    let maxInputReportSize: Int
    let maxOutputReportSize: Int
    let serialNumber: String
    let manufacturer: String
    let product: String

    var isProtocolInterface: Bool {
        vendorID == H200DeviceTarget.vendorID
            && productID == H200DeviceTarget.productID
            && primaryUsagePage == H200DeviceTarget.primaryUsagePage
            && primaryUsage == H200DeviceTarget.primaryUsage
            && maxInputReportSize == H200DeviceTarget.reportSize
            && maxOutputReportSize == H200DeviceTarget.reportSize
    }
}

enum H200DeviceTarget {
    static let vendorID = 0x2207
    static let productID = 0x0019
    static let primaryUsagePage = 12
    static let primaryUsage = 1
    static let reportSize = 1024
}

struct HIDReturnCode: Equatable {
    let rawValue: Int32

    private enum KnownCodes {
        static let success: Int32 = 0x00000000
        static let busy = Int32(bitPattern: 0xe00002d5)
        static let exclusiveAccess = Int32(bitPattern: 0xe00002c5)
        static let notPermitted = Int32(bitPattern: 0xe00002e2)
        static let notPrivileged = Int32(bitPattern: 0xe00002c1)
    }

    var name: String {
        switch rawValue {
        case KnownCodes.success:
            return "kIOReturnSuccess"
        case KnownCodes.busy:
            return "kIOReturnBusy"
        case KnownCodes.exclusiveAccess:
            return "kIOReturnExclusiveAccess"
        case KnownCodes.notPermitted:
            return "kIOReturnNotPermitted"
        case KnownCodes.notPrivileged:
            return "kIOReturnNotPrivileged"
        default:
            return String(format: "0x%08x", UInt32(bitPattern: rawValue))
        }
    }

    var indicatesOccupiedPort: Bool {
        rawValue == KnownCodes.busy || rawValue == KnownCodes.exclusiveAccess
    }
}

enum H200DiscoveryResult: Equatable {
    case connected(H200DeviceIdentity)
    case notConnected
    case communicationPortOccupied(HIDReturnCode)
    case occupied(H200DeviceIdentity, HIDReturnCode)
    case permissionDenied(H200DeviceIdentity, HIDReturnCode)
    case openFailed(H200DeviceIdentity, HIDReturnCode)
    case managerOpenFailed(HIDReturnCode)
}

protocol H200Discovering {
    func discoverH200() -> H200DiscoveryResult
}
