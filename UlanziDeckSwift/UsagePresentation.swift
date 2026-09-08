import Foundation

nonisolated struct UsageQuota: Codable, Equatable, Sendable {
    let remainingPercent: Int
    let resetAfterSeconds: Int
    let resetAt: Int?
    let limitWindowSeconds: Int
    let usedPercent: Double

    init(
        remainingPercent: Int,
        resetAfterSeconds: Int,
        resetAt: Int? = nil,
        limitWindowSeconds: Int,
        usedPercent: Double
    ) {
        self.remainingPercent = remainingPercent
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
        self.limitWindowSeconds = limitWindowSeconds
        self.usedPercent = usedPercent
    }

    var remainingTimeVsUsage: Double {
        let remainingWindowFraction = Double(resetAfterSeconds) / Double(limitWindowSeconds)
        let usedFraction = usedPercent * 0.01
        return remainingWindowFraction / usedFraction
    }

    var resetAfterText: String {
        let clampedSeconds = max(0, resetAfterSeconds)
        let days = clampedSeconds / 86_400
        let hours = clampedSeconds % 86_400 / 3_600
        let minutes = clampedSeconds % 3_600 / 60
        let clockText = "\(hours):\(String(format: "%02d", minutes))"
        return days > 0 ? "\(days)天 \(clockText)" : clockText
    }

    func resetAtText(timeZone: TimeZone = .current) -> String? {
        guard let resetAt else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(resetAt))
        let components = Calendar(identifier: .gregorian).dateComponents(in: timeZone, from: date)
        guard let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute
        else { return nil }
        return String(format: "%d/%d %d:%02d", month, day, hour, minute)
    }
}

nonisolated enum UsageFetchResult: Codable, Equatable, Sendable {
    case success(UsageQuota)
    case authFileNotSelected
    case authFileNeedsReselection
    case invalidAuthFile
    case unsupportedAuthMode
    case invalidConfiguration
    case unauthorized
    case missingWeeklyQuota
    case networkError(String)
}

typealias CodexUsageQuota = UsageQuota
typealias CodexUsageResult = UsageFetchResult

nonisolated enum UsageDataSource: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case codex
    case zcode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex: return "Codex"
        case .zcode: return "Zcode"
        }
    }
}

nonisolated struct UsageButtonContent: Equatable, Sendable {
    let accountNickname: String?
    let percentageText: String
    let detailLabelText: String
    let detailValueText: String?
    let percentageColor: MihoyoGameMetricColor
    let detailValueColor: MihoyoGameMetricColor

    init(
        accountNickname: String?,
        percentageText: String,
        detailLabelText: String,
        detailValueText: String?,
        percentageColor: MihoyoGameMetricColor,
        detailValueColor: MihoyoGameMetricColor
    ) {
        self.accountNickname = accountNickname
        self.percentageText = percentageText
        self.detailLabelText = detailLabelText
        self.detailValueText = detailValueText
        self.percentageColor = percentageColor
        self.detailValueColor = detailValueColor
    }

    init(
        accountNickname: String?,
        percentageText: String,
        resetLabelText: String,
        resetAfterText: String,
        percentageColor: MihoyoGameMetricColor,
        resetAfterColor: MihoyoGameMetricColor
    ) {
        self.init(
            accountNickname: accountNickname,
            percentageText: percentageText,
            detailLabelText: resetLabelText,
            detailValueText: resetAfterText,
            percentageColor: percentageColor,
            detailValueColor: resetAfterColor
        )
    }

    var resetLabelText: String { detailLabelText }
    var resetAfterText: String { detailValueText ?? "" }
    var resetAfterColor: MihoyoGameMetricColor { detailValueColor }
}

typealias CodexUsageButtonContent = UsageButtonContent

nonisolated struct UsagePresentation: Equatable, Sendable {
    let title: String
    let subtitle: String
    let buttonContent: UsageButtonContent?
}

nonisolated enum UsagePresentationFormatter {
    static func presentation(
        for configuration: DeckKeyCodexUsageConfiguration
    ) -> UsagePresentation {
        let source = configuration.dataSource
        let fallbackTitle = "\(source.title) 额度"

        switch configuration.lastResult {
        case let .success(quota):
            let percentageColor = configuration.colorMode.metricColor(for: quota.remainingPercent)
            if source == .zcode {
                let resetText = quota.resetAt == nil
                    ? nil
                    : configuration.resetDisplayMode.text(for: quota)
                return UsagePresentation(
                    title: "\(quota.remainingPercent)%",
                    subtitle: resetText.map { "周额度 · \($0)" } ?? "周额度",
                    buttonContent: UsageButtonContent(
                        accountNickname: configuration.displayAccountNickname,
                        percentageText: "\(quota.remainingPercent)%",
                        detailLabelText: resetText == nil ? "周额度" : "周额度 · 下次重设",
                        detailValueText: resetText,
                        percentageColor: percentageColor,
                        detailValueColor: resetText == nil
                            ? .yellow
                            : configuration.colorMode.resetTimeMetricColor(
                                for: quota.remainingTimeVsUsage
                            )
                    )
                )
            }

            let resetText = configuration.resetDisplayMode.text(for: quota)
            return UsagePresentation(
                title: "\(quota.remainingPercent)%",
                subtitle: quota.resetAfterText,
                buttonContent: UsageButtonContent(
                    accountNickname: configuration.displayAccountNickname,
                    percentageText: "\(quota.remainingPercent)%",
                    detailLabelText: "下次重设",
                    detailValueText: resetText,
                    percentageColor: percentageColor,
                    detailValueColor: configuration.colorMode.resetTimeMetricColor(
                        for: quota.remainingTimeVsUsage
                    )
                )
            )
        case .authFileNotSelected:
            return UsagePresentation(title: fallbackTitle, subtitle: source == .zcode ? "未选择 config.json" : "未选择 auth.json", buttonContent: nil)
        case .authFileNeedsReselection:
            return UsagePresentation(title: fallbackTitle, subtitle: "需重选文件", buttonContent: nil)
        case .invalidAuthFile:
            return UsagePresentation(title: source == .zcode ? "config.json" : "auth.json", subtitle: "JSON 格式无效", buttonContent: nil)
        case .invalidConfiguration:
            return UsagePresentation(title: "Zcode 配置", subtitle: "缺少 provider 配置", buttonContent: nil)
        case .unsupportedAuthMode:
            return UsagePresentation(title: "auth.json", subtitle: "仅支持 ChatGPT 登录", buttonContent: nil)
        case .unauthorized:
            return UsagePresentation(title: fallbackTitle, subtitle: source == .zcode ? "鉴权失败" : "登录已失效", buttonContent: nil)
        case .missingWeeklyQuota:
            return UsagePresentation(title: "Zcode 额度", subtitle: "缺少周额度", buttonContent: nil)
        case .networkError:
            return UsagePresentation(title: fallbackTitle, subtitle: "刷新失败", buttonContent: nil)
        case nil:
            return UsagePresentation(
                title: fallbackTitle,
                subtitle: configuration.selectedConfigurationFilePath == nil ? "未配置" : "未刷新",
                buttonContent: nil
            )
        }
    }
}
