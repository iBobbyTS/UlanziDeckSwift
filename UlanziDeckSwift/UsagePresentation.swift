import Foundation

nonisolated enum UsageQuotaWindow: String, Codable, Equatable, Hashable, Sendable {
    case primary
    case fiveHours
    case sevenDays

    var displayName: String {
        switch self {
        case .primary: return "周额度"
        case .fiveHours: return "5h"
        case .sevenDays: return "7d"
        }
    }

    fileprivate var sortOrder: Int {
        switch self {
        case .primary: return 0
        case .fiveHours: return 1
        case .sevenDays: return 2
        }
    }
}

nonisolated struct UsageQuota: Codable, Equatable, Sendable {
    let window: UsageQuotaWindow
    let remainingPercent: Int
    let resetAfterSeconds: Int
    let resetAt: Int?
    let limitWindowSeconds: Int
    let usedPercent: Double

    init(
        window: UsageQuotaWindow = .primary,
        remainingPercent: Int,
        resetAfterSeconds: Int,
        resetAt: Int? = nil,
        limitWindowSeconds: Int,
        usedPercent: Double
    ) {
        self.window = window
        self.remainingPercent = remainingPercent
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
        self.limitWindowSeconds = limitWindowSeconds
        self.usedPercent = usedPercent
    }

    private enum CodingKeys: String, CodingKey {
        case window
        case remainingPercent
        case resetAfterSeconds
        case resetAt
        case limitWindowSeconds
        case usedPercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        window = try container.decodeIfPresent(UsageQuotaWindow.self, forKey: .window) ?? .primary
        remainingPercent = try container.decode(Int.self, forKey: .remainingPercent)
        resetAfterSeconds = try container.decode(Int.self, forKey: .resetAfterSeconds)
        resetAt = try container.decodeIfPresent(Int.self, forKey: .resetAt)
        limitWindowSeconds = try container.decode(Int.self, forKey: .limitWindowSeconds)
        usedPercent = try container.decode(Double.self, forKey: .usedPercent)
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

nonisolated struct UsageQuotaSnapshot: Codable, Equatable, Sendable {
    let quotas: [UsageQuota]

    init(quotas: [UsageQuota]) {
        var seenWindows = Set<UsageQuotaWindow>()
        self.quotas = quotas
            .sorted { $0.window.sortOrder < $1.window.sortOrder }
            .filter { seenWindows.insert($0.window).inserted }
    }

    init(quota: UsageQuota) {
        self.init(quotas: [quota])
    }

    private enum CodingKeys: String, CodingKey {
        case quotas
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(quotas: try container.decode([UsageQuota].self, forKey: .quotas))
    }
}

nonisolated enum UsageFetchResult: Codable, Equatable, Sendable {
    case success(UsageQuotaSnapshot)
    case authFileNotSelected
    case authFileNeedsReselection
    case invalidAuthFile
    case unsupportedAuthMode
    case invalidConfiguration
    case unauthorized
    case missingWeeklyQuota
    case networkError(String)

    static func success(_ quota: UsageQuota) -> Self {
        .success(UsageQuotaSnapshot(quota: quota))
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case authFileNotSelected
        case authFileNeedsReselection
        case invalidAuthFile
        case unsupportedAuthMode
        case invalidConfiguration
        case unauthorized
        case missingWeeklyQuota
        case networkError
    }

    private enum PayloadKeys: String, CodingKey {
        case value = "_0"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let key = container.allKeys.first, container.allKeys.count == 1 else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "额度结果必须且只能包含一个状态"
            ))
        }

        switch key {
        case .success:
            let payload = try container.nestedContainer(keyedBy: PayloadKeys.self, forKey: key)
            if let snapshot = try? payload.decode(UsageQuotaSnapshot.self, forKey: .value),
               !snapshot.quotas.isEmpty {
                self = .success(snapshot)
            } else {
                self = .success(try payload.decode(UsageQuota.self, forKey: .value))
            }
        case .authFileNotSelected: self = .authFileNotSelected
        case .authFileNeedsReselection: self = .authFileNeedsReselection
        case .invalidAuthFile: self = .invalidAuthFile
        case .unsupportedAuthMode: self = .unsupportedAuthMode
        case .invalidConfiguration: self = .invalidConfiguration
        case .unauthorized: self = .unauthorized
        case .missingWeeklyQuota: self = .missingWeeklyQuota
        case .networkError:
            let payload = try container.nestedContainer(keyedBy: PayloadKeys.self, forKey: key)
            self = .networkError(try payload.decode(String.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .success(snapshot):
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .success)
            try payload.encode(snapshot, forKey: .value)
        case .authFileNotSelected: try container.encode([String: String](), forKey: .authFileNotSelected)
        case .authFileNeedsReselection: try container.encode([String: String](), forKey: .authFileNeedsReselection)
        case .invalidAuthFile: try container.encode([String: String](), forKey: .invalidAuthFile)
        case .unsupportedAuthMode: try container.encode([String: String](), forKey: .unsupportedAuthMode)
        case .invalidConfiguration: try container.encode([String: String](), forKey: .invalidConfiguration)
        case .unauthorized: try container.encode([String: String](), forKey: .unauthorized)
        case .missingWeeklyQuota: try container.encode([String: String](), forKey: .missingWeeklyQuota)
        case let .networkError(message):
            var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .networkError)
            try payload.encode(message, forKey: .value)
        }
    }
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

nonisolated struct UsageButtonMetric: Equatable, Sendable {
    let percentageText: String
    let detailLabelText: String?
    let detailValueText: String?
    let percentageColor: MihoyoGameMetricColor
    let detailValueColor: MihoyoGameMetricColor
}

nonisolated struct UsageButtonContent: Equatable, Sendable {
    let accountNickname: String?
    let metrics: [UsageButtonMetric]

    init(
        accountNickname: String?,
        percentageText: String,
        detailLabelText: String,
        detailValueText: String?,
        percentageColor: MihoyoGameMetricColor,
        detailValueColor: MihoyoGameMetricColor
    ) {
        self.accountNickname = accountNickname
        metrics = [UsageButtonMetric(
            percentageText: percentageText,
            detailLabelText: detailLabelText,
            detailValueText: detailValueText,
            percentageColor: percentageColor,
            detailValueColor: detailValueColor
        )]
    }

    init(accountNickname: String?, metrics: [UsageButtonMetric]) {
        self.accountNickname = accountNickname
        self.metrics = metrics
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

    var percentageText: String { metrics.first?.percentageText ?? "" }
    var detailLabelText: String { metrics.first?.detailLabelText ?? "" }
    var detailValueText: String? { metrics.first?.detailValueText }
    var percentageColor: MihoyoGameMetricColor { metrics.first?.percentageColor ?? .yellow }
    var detailValueColor: MihoyoGameMetricColor { metrics.first?.detailValueColor ?? .yellow }
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
        case let .success(snapshot):
            let quotas = snapshot.quotas
            guard let firstQuota = quotas.first else {
                return UsagePresentation(title: fallbackTitle, subtitle: "额度不可用", buttonContent: nil)
            }
            if quotas.count > 1 {
                let metrics = quotas.map { quota in
                    let resetText = quota.resetAt == nil
                        ? nil
                        : configuration.resetDisplayMode.text(for: quota)
                    return UsageButtonMetric(
                        percentageText: "\(quota.window.displayName) \(quota.remainingPercent)%",
                        detailLabelText: nil,
                        detailValueText: resetText,
                        percentageColor: configuration.colorMode.metricColor(for: quota.remainingPercent),
                        detailValueColor: resetText == nil
                            ? .yellow
                            : configuration.colorMode.resetTimeMetricColor(for: quota.remainingTimeVsUsage)
                    )
                }
                return UsagePresentation(
                    title: quotas.map { "\($0.remainingPercent)%" }.joined(separator: " / "),
                    subtitle: quotas.map(\.window.displayName).joined(separator: " / "),
                    buttonContent: UsageButtonContent(
                        accountNickname: configuration.displayAccountNickname,
                        metrics: metrics
                    )
                )
            }

            let quota = firstQuota
            let percentageColor = configuration.colorMode.metricColor(for: quota.remainingPercent)
            if source == .zcode {
                let resetText = quota.resetAt == nil
                    ? nil
                    : configuration.resetDisplayMode.text(for: quota)
                let windowLabel = quota.window.displayName
                return UsagePresentation(
                    title: "\(quota.remainingPercent)%",
                    subtitle: resetText.map { "\(windowLabel) · \($0)" } ?? windowLabel,
                    buttonContent: UsageButtonContent(
                        accountNickname: configuration.displayAccountNickname,
                        percentageText: "\(quota.remainingPercent)%",
                        detailLabelText: resetText == nil ? windowLabel : "\(windowLabel) · 下次重设",
                        detailValueText: resetText,
                        percentageColor: percentageColor,
                        detailValueColor: resetText == nil
                            ? .yellow
                            : configuration.colorMode.resetTimeMetricColor(for: quota.remainingTimeVsUsage)
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
            return UsagePresentation(title: "Zcode 额度", subtitle: "缺少有效额度", buttonContent: nil)
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
