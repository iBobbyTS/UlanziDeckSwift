import AppIntents
import Foundation

struct UlanziDeckBrightnessAdjustmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Ulanzi Deck 亮度调节器"
    static var description: IntentDescription? = "调节正在运行的 Ulanzi Deck app 已连接设备的亮度。"
    static var supportedModes: IntentModes = .background

    @Parameter(
        title: "亮度",
        description: "Ulanzi Deck 亮度百分比。",
        default: 0.0,
        controlStyle: .slider,
        inclusiveRange: (0.0, 100.0)
    )
    var brightnessPercent: Double

    static var parameterSummary: some ParameterSummary {
        Summary("将亮度设为 \(\.$brightnessPercent)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let percent = DeckBrightnessConfiguration.clamped(Int(brightnessPercent.rounded()))
        switch BrightnessAdjustmentRuntime.shared.adjustBrightness(to: percent) {
        case .sent:
            return .result()
        case .appNotRunning:
            throw BrightnessAdjustmentIntentError.appNotRunning
        case .deviceNotReady:
            throw BrightnessAdjustmentIntentError.deviceNotReady
        }
    }
}

struct UlanziDeckShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UlanziDeckBrightnessAdjustmentIntent(),
            phrases: [
                "调节 \(.applicationName) 亮度",
                "设置 \(.applicationName) 亮度",
            ],
            shortTitle: "亮度调节器",
            systemImageName: "sun.max"
        )
    }
}

enum BrightnessAdjustmentIntentError: LocalizedError {
    case appNotRunning
    case deviceNotReady

    var errorDescription: String? {
        switch self {
        case .appNotRunning:
            return "无法调节 Ulanzi Deck 亮度。请先打开 Ulanzi Deck app。"
        case .deviceNotReady:
            return "无法调节 Ulanzi Deck 亮度。请确认 app 正在运行且 Ulanzi Deck 已连接并完成同步。"
        }
    }
}
