import Foundation

nonisolated enum UlanziDeckFocusFilterSettings {
    static let brightnessDidChangeNotification = Notification.Name("com.iBobby.UlanziDeckSwift.focusFilterBrightnessDidChange")
    static let brightnessPercentUserInfoKey = "brightnessPercent"

    static func apply(
        brightnessPercent: Int,
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        notificationCenter: NotificationCenter = .default
    ) {
        let clampedBrightnessPercent = DeckBrightnessConfiguration.clamped(brightnessPercent)
        configurationStore.saveBrightnessPercent(clampedBrightnessPercent)
        notificationCenter.post(
            name: brightnessDidChangeNotification,
            object: nil,
            userInfo: [brightnessPercentUserInfoKey: clampedBrightnessPercent]
        )
    }
}
