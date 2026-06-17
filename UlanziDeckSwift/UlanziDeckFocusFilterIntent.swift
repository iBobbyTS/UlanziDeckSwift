import AppIntents

struct UlanziDeckFocusFilterIntent: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Ulanzi Deck"
    static var description: IntentDescription? = "在专注模式中配置 Ulanzi Deck。"

    @Parameter(
        title: "亮度",
        description: "专注模式启用时应用到 Ulanzi Deck 的亮度百分比。",
        default: 50.0,
        controlStyle: .slider,
        inclusiveRange: (0.0, 100.0)
    )
    var brightnessPercent: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Ulanzi Deck",
            subtitle: "亮度 \(effectiveBrightnessPercent)%"
        )
    }

    func perform() async throws -> some IntentResult {
        UlanziDeckFocusFilterSettings.apply(brightnessPercent: effectiveBrightnessPercent)
        return .result()
    }

    private var effectiveBrightnessPercent: Int {
        DeckBrightnessConfiguration.clamped(Int(brightnessPercent.rounded()))
    }
}
