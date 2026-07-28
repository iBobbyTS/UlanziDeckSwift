import CoreGraphics
import Darwin
import Foundation

@MainActor
protocol BuiltInDisplayBrightnessReading {
    func currentBrightness() -> Double?
}

enum DisplayServicesBrightnessReadResult: Equatable {
    case success(Double)
    case frameworkUnavailable
    case noActiveBuiltInDisplay
    case failed(Int32)
}

@MainActor
final class DisplayServicesBuiltInDisplayBrightnessReader: BuiltInDisplayBrightnessReading {
    private typealias BrightnessGetter = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let brightnessGetter: BrightnessGetter?

    init() {
        let frameworkHandle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        self.frameworkHandle = frameworkHandle
        if let frameworkHandle,
           let symbol = dlsym(frameworkHandle, "DisplayServicesGetBrightness") {
            brightnessGetter = unsafeBitCast(symbol, to: BrightnessGetter.self)
        } else {
            brightnessGetter = nil
        }
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func currentBrightness() -> Double? {
        guard case let .success(brightness) = readResult() else {
            return nil
        }
        return brightness
    }

    func readResult() -> DisplayServicesBrightnessReadResult {
        guard let brightnessGetter else {
            return .frameworkUnavailable
        }
        guard let displayID = activeBuiltInDisplayID else {
            return .noActiveBuiltInDisplay
        }

        var brightness: Float = 0
        let result = brightnessGetter(displayID, &brightness)
        guard result == 0 else {
            return .failed(result)
        }
        guard brightness.isFinite else {
            return .failed(-1)
        }

        return .success(min(1, max(0, Double(brightness))))
    }

    private var activeBuiltInDisplayID: CGDirectDisplayID? {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(displayIDs.count), &displayIDs, &displayCount) == .success else {
            return nil
        }

        return displayIDs.prefix(Int(displayCount)).first {
            CGDisplayIsBuiltin($0) != 0
        }
    }
}

@MainActor
final class BuiltInDisplayBrightnessMonitor {
    var onBrightnessChange: ((Double) -> Void)?
    private(set) var isMonitoring = false

    private let reader: BuiltInDisplayBrightnessReading
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastBrightness: Double?

    convenience init(pollInterval: TimeInterval = 0.25) {
        self.init(
            reader: DisplayServicesBuiltInDisplayBrightnessReader(),
            pollInterval: pollInterval
        )
    }

    init(
        reader: BuiltInDisplayBrightnessReading,
        pollInterval: TimeInterval = 0.25
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
        lastBrightness = nil
        isMonitoring = false
    }

    func refresh() {
        guard isMonitoring else {
            return
        }

        guard let brightness = reader.currentBrightness() else {
            return
        }

        let normalizedBrightness = min(1, max(0, brightness))
        guard normalizedBrightness != lastBrightness else {
            return
        }

        lastBrightness = normalizedBrightness
        onBrightnessChange?(normalizedBrightness)
    }
}

nonisolated enum BuiltInDisplayBrightnessMapping {
    static func deckPercent(for normalizedBrightness: Double) -> Int {
        guard normalizedBrightness.isFinite else {
            return 0
        }

        let clampedBrightness = min(0.7, max(0, normalizedBrightness))
        return DeckBrightnessConfiguration.clamped(
            Int((clampedBrightness / 0.7 * 100).rounded())
        )
    }
}
