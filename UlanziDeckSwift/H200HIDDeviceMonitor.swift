import Foundation
import IOKit
import IOKit.hid

nonisolated protocol H200DeviceMonitoring: AnyObject, Sendable {
    var onDeviceMatched: (@Sendable () -> Void)? { get set }
    var onDeviceRemoved: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
}

nonisolated final class H200NoopDeviceMonitor: H200DeviceMonitoring, @unchecked Sendable {
    var onDeviceMatched: (@Sendable () -> Void)?
    var onDeviceRemoved: (@Sendable () -> Void)?

    init() {}
    func start() {}
    func stop() {}
}

nonisolated final class H200HIDDeviceMonitor: H200DeviceMonitoring, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.H200HIDDeviceMonitor")
    private var manager: IOHIDManager?
    private var isStarted = false
    private var _onDeviceMatched: (@Sendable () -> Void)?
    private var _onDeviceRemoved: (@Sendable () -> Void)?

    var onDeviceMatched: (@Sendable () -> Void)? {
        get { queue.sync { _onDeviceMatched } }
        set { queue.sync { _onDeviceMatched = newValue } }
    }

    var onDeviceRemoved: (@Sendable () -> Void)? {
        get { queue.sync { _onDeviceRemoved } }
        set { queue.sync { _onDeviceRemoved = newValue } }
    }

    init() {}

    deinit {
        stop()
    }

    func start() {
        queue.sync {
            guard !isStarted else { return }

            let manager = IOHIDManagerCreate(
                kCFAllocatorDefault,
                IOOptionBits(IOHIDManagerOptions.independentDevices.rawValue)
            )
            let matching: [String: Any] = [
                kIOHIDVendorIDKey as String: H200DeviceTarget.vendorID,
                kIOHIDProductIDKey as String: H200DeviceTarget.productID,
                kIOHIDPrimaryUsagePageKey as String: H200DeviceTarget.primaryUsagePage,
                kIOHIDPrimaryUsageKey as String: H200DeviceTarget.primaryUsage,
            ]
            IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

            let context = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceMatchingCallback, context)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceRemovalCallback, context)
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

            let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            if openResult != kIOReturnSuccess {
                NSLog("H200HIDDeviceMonitor: IOHIDManagerOpen 失败，返回码：%d", openResult)
            }

            self.manager = manager
            self.isStarted = true
        }
    }

    func stop() {
        queue.sync {
            guard isStarted, let manager else { return }

            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))

            self.manager = nil
            self.isStarted = false
        }
    }

    private static let deviceMatchingCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let monitor = Unmanaged<H200HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleDeviceMatched()
    }

    private static let deviceRemovalCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let monitor = Unmanaged<H200HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleDeviceRemoved()
    }

    private func handleDeviceMatched() {
        let handler: (@Sendable () -> Void)? = queue.sync {
            guard isStarted else { return nil }
            return _onDeviceMatched
        }
        handler?()
    }

    private func handleDeviceRemoved() {
        let handler: (@Sendable () -> Void)? = queue.sync {
            guard isStarted else { return nil }
            return _onDeviceRemoved
        }
        handler?()
    }
}
