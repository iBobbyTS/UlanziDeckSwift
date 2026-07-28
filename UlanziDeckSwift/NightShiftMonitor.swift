import Darwin
import Foundation
import ObjectiveC

nonisolated struct NightShiftState: Equatable, Sendable {
    let isEnabled: Bool
    let strength: Double
}

@MainActor
protocol NightShiftStateReading {
    func currentState() -> NightShiftState?
}

nonisolated enum CoreBrightnessNightShiftReadResult: Equatable {
    case success(NightShiftState)
    case frameworkUnavailable
    case clientUnavailable
    case statusReadFailed
    case strengthReadFailed
}

@MainActor
final class CoreBrightnessNightShiftStateReader: NightShiftStateReading {
    private struct BlueLightTime {
        var hour: Int32 = 0
        var minute: Int32 = 0
    }

    private struct BlueLightSchedule {
        var fromTime = BlueLightTime()
        var toTime = BlueLightTime()
    }

    private struct BlueLightStatus {
        var active: Int8 = 0
        var enabled: Int8 = 0
        var sunSchedulePermitted: Int8 = 0
        var mode: Int32 = 0
        var schedule = BlueLightSchedule()
        var disableFlags: UInt64 = 0
        var available: Int8 = 0
    }

    private typealias ObjectMessageSend = @convention(c) (
        AnyObject,
        Selector
    ) -> Unmanaged<AnyObject>?
    private typealias PointerMessageSend = @convention(c) (
        AnyObject,
        Selector,
        UnsafeMutableRawPointer
    ) -> Int8

    private var frameworkHandle: UnsafeMutableRawPointer?
    private let messageSendPointer: UnsafeMutableRawPointer?
    private var client: AnyObject?

    init() {
        frameworkHandle = dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_LAZY
        )
        messageSendPointer = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2),
            "objc_msgSend"
        )

        guard frameworkHandle != nil,
              let messageSendPointer,
              let clientClass = NSClassFromString("CBBlueLightClient")
        else {
            client = nil
            return
        }

        let sendObject = unsafeBitCast(messageSendPointer, to: ObjectMessageSend.self)
        guard let allocated = sendObject(
            clientClass as AnyObject,
            NSSelectorFromString("alloc")
        )?.takeRetainedValue()
        else {
            client = nil
            return
        }

        client = sendObject(
            allocated,
            NSSelectorFromString("init")
        )?.takeUnretainedValue()
    }

    deinit {
        client = nil
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func currentState() -> NightShiftState? {
        guard case let .success(state) = readResult() else {
            return nil
        }

        return state
    }

    func readResult() -> CoreBrightnessNightShiftReadResult {
        guard frameworkHandle != nil, messageSendPointer != nil else {
            return .frameworkUnavailable
        }
        guard let client, let messageSendPointer else {
            return .clientUnavailable
        }

        let sendPointer = unsafeBitCast(messageSendPointer, to: PointerMessageSend.self)
        var status = BlueLightStatus()
        let didReadStatus = withUnsafeMutablePointer(to: &status) { pointer in
            sendPointer(
                client,
                NSSelectorFromString("getBlueLightStatus:"),
                UnsafeMutableRawPointer(pointer)
            )
        }
        guard didReadStatus != 0 else {
            return .statusReadFailed
        }

        var strength: Float = 0
        let didReadStrength = withUnsafeMutablePointer(to: &strength) { pointer in
            sendPointer(
                client,
                NSSelectorFromString("getStrength:"),
                UnsafeMutableRawPointer(pointer)
            )
        }
        guard didReadStrength != 0, strength.isFinite else {
            return .strengthReadFailed
        }

        return .success(NightShiftState(
            isEnabled: status.enabled != 0,
            strength: min(1, max(0, Double(strength)))
        ))
    }
}

@MainActor
final class NightShiftMonitor {
    var onStateChange: ((NightShiftState) -> Void)?
    private(set) var isMonitoring = false

    private let reader: NightShiftStateReading
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastState: NightShiftState?

    convenience init(pollInterval: TimeInterval = 0.5) {
        self.init(
            reader: CoreBrightnessNightShiftStateReader(),
            pollInterval: pollInterval
        )
    }

    init(
        reader: NightShiftStateReading,
        pollInterval: TimeInterval = 0.5
    ) {
        self.reader = reader
        self.pollInterval = pollInterval
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !isMonitoring else {
            refresh()
            return
        }

        isMonitoring = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastState = nil
        isMonitoring = false
    }

    func refresh() {
        guard isMonitoring, let state = reader.currentState(), state != lastState else {
            return
        }

        lastState = state
        onStateChange?(state)
    }
}

nonisolated enum NightShiftColorTemperatureMapping {
    static let neutralKelvin = 6_500.0
    static let warmestKelvin = 2_500.0

    static func kelvin(for state: NightShiftState) -> Double? {
        guard state.isEnabled else {
            return nil
        }

        let strength = state.strength.isFinite
            ? min(1, max(0, state.strength))
            : 0
        return neutralKelvin - (neutralKelvin - warmestKelvin) * strength
    }
}
