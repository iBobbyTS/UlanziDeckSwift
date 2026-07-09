import Foundation

@MainActor
protocol BrightnessAdjusting: AnyObject {
    var canAdjustBrightness: Bool { get }

    func adjustBrightness(to percent: Int)
}

@MainActor
protocol BrightnessAdjustmentRegistering: AnyObject {
    func register(_ adjuster: BrightnessAdjusting)
    func unregister(_ adjuster: BrightnessAdjusting)
}

@MainActor
final class BrightnessAdjustmentRuntime: BrightnessAdjustmentRegistering {
    static let shared = BrightnessAdjustmentRuntime()

    private weak var adjuster: BrightnessAdjusting?

    private init() {}

    func register(_ adjuster: BrightnessAdjusting) {
        self.adjuster = adjuster
    }

    func unregister(_ adjuster: BrightnessAdjusting) {
        guard self.adjuster === adjuster else {
            return
        }

        self.adjuster = nil
    }

    func adjustBrightness(to percent: Int) -> BrightnessAdjustmentResult {
        guard let adjuster else {
            return .appNotRunning
        }

        guard adjuster.canAdjustBrightness else {
            return .deviceNotReady
        }

        let clampedPercent = DeckBrightnessConfiguration.clamped(percent)
        adjuster.adjustBrightness(to: clampedPercent)
        return .sent(clampedPercent)
    }
}

enum BrightnessAdjustmentResult: Equatable {
    case sent(Int)
    case appNotRunning
    case deviceNotReady
}
