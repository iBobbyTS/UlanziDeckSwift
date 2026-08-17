import Foundation

nonisolated struct DeckGridLayout: Equatable {
    nonisolated struct Key: Identifiable, Equatable {
        let id: Int
        let row: Int
        let column: Int
        let columnSpan: Int
    }

    let identifier: String
    let name: String
    let columnCount: Int
    let keys: [Key]

    static let h200Prototype = DeckGridLayout(
        identifier: "h200Prototype",
        name: "H200 原型",
        columnCount: 5,
        keys: (1...14).map { number in
            let zeroBasedIndex = number - 1
            return Key(
                id: number,
                row: zeroBasedIndex / 5,
                column: zeroBasedIndex % 5,
                columnSpan: number == 14 ? 2 : 1
            )
        }
    )

    var rows: [[Key]] {
        Dictionary(grouping: keys, by: \.row)
            .sorted { $0.key < $1.key }
            .map { rowIndex, rowKeys in
                rowKeys.sorted { first, second in
                    if first.column == second.column {
                        return first.id < second.id
                    }

                    return first.column < second.column
                }
            }
    }

    func keyID(forSequentialInputIndex index: Int) -> Int? {
        let orderedKeys = rows.flatMap { $0 }
        guard orderedKeys.indices.contains(index) else {
            return nil
        }

        return orderedKeys[index].id
    }
}

nonisolated struct DeckKeyDisplay: Equatable, Identifiable {
    let id: Int
    let row: Int
    let column: Int
    let columnSpan: Int
    let displayMode: DeckKeyDisplayMode
    let title: String
    let subtitle: String
    let mihoyoGame: MihoyoGame?
    let mihoyoGameButtonContent: MihoyoGameButtonContent?
    let codexUsageButtonContent: CodexUsageButtonContent?
    let sub2APIButtonContent: Sub2APIButtonContent?
    let newAPIModelAvailabilityButtonContent: NewAPIModelAvailabilityButtonContent?
    let folderButtonContent: FolderButtonContent?
    let fileButtonContent: FileButtonContent?
    let webPageButtonContent: WebPageButtonContent?
    let smbServerButtonContent: SMBServerButtonContent?
    let pageFolderButtonContent: PageFolderButtonContent?
    let pageBackButtonContent: PageBackButtonContent?
    let buttonVisualContent: ButtonVisualContent
    let isSelected: Bool
    let isPressed: Bool
    let canDelete: Bool
    let canDrag: Bool

    init(
        key: DeckGridLayout.Key,
        configuration: DeckKeyConfiguration,
        isSelected: Bool,
        isPressed: Bool
    ) {
        id = key.id
        row = key.row
        column = key.column
        columnSpan = key.columnSpan
        displayMode = key.columnSpan > 1 ? configuration.displayMode : .function
        let configuredMihoyoGame = configuration.function.game
        var mihoyoGameButtonContent: MihoyoGameButtonContent?
        var codexUsageButtonContent: CodexUsageButtonContent?
        var sub2APIButtonContent: Sub2APIButtonContent?
        var newAPIModelAvailabilityButtonContent: NewAPIModelAvailabilityButtonContent?
        var folderButtonContent: FolderButtonContent?
        var fileButtonContent: FileButtonContent?
        var webPageButtonContent: WebPageButtonContent?
        var smbServerButtonContent: SMBServerButtonContent?
        var pageFolderButtonContent: PageFolderButtonContent?
        var pageBackButtonContent: PageBackButtonContent?
        var buttonBackgroundUsesFittedImage = true
        let hasCustomDisplayName = !configuration.visual.name.isEmpty

        if key.columnSpan > 1 && configuration.displayMode != .function {
            title = configuration.visual.displayName(fallback: configuration.displayMode.previewTitle)
            subtitle = configuration.displayMode.previewSubtitle
            mihoyoGame = nil
        } else {
            mihoyoGame = configuredMihoyoGame
            switch configuration.function {
            case .none:
                title = configuration.visual.displayName(fallback: "")
                subtitle = ""
            case .tally:
                title = configuration.visual.displayName(fallback: "\(configuration.tally.value)")
                subtitle = "默认 \(configuration.tally.defaultValue)"
            case .openFolder:
                let content = FolderButtonContent(
                    visual: ButtonVisualContent(
                        displayName: configuration.visual.displayName(fallback: configuration.openFolder.automaticDisplayName),
                        backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
                        backgroundAssetName: nil,
                        usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
                        dimsBackground: configuration.visual.dimsBackground,
                        hasCustomDisplayName: hasCustomDisplayName,
                        hasCustomBackground: configuration.visual.hasCustomBackground
                    )
                )
                title = content.displayName
                subtitle = configuration.openFolder.path ?? ""
                folderButtonContent = content
            case .openFile:
                let content = FileButtonContent(
                    visual: ButtonVisualContent(
                        displayName: configuration.visual.displayName(fallback: configuration.openFile.automaticDisplayName),
                        backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
                        backgroundAssetName: nil,
                        usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
                        dimsBackground: configuration.visual.dimsBackground,
                        hasCustomDisplayName: hasCustomDisplayName,
                        hasCustomBackground: configuration.visual.hasCustomBackground
                    )
                )
                title = content.displayName
                subtitle = configuration.openFile.path ?? ""
                fileButtonContent = content
            case .openWebPage:
                let content = WebPageButtonContent(
                    visual: ButtonVisualContent(
                        displayName: configuration.visual.displayName(fallback: configuration.openWebPage.displayName),
                        backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
                        backgroundAssetName: nil,
                        usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
                        dimsBackground: configuration.visual.dimsBackground,
                        hasCustomDisplayName: hasCustomDisplayName,
                        hasCustomBackground: configuration.visual.hasCustomBackground
                    )
                )
                title = content.displayName
                subtitle = configuration.openWebPage.urlString
                webPageButtonContent = content
            case .connectSMBServer:
                let content = SMBServerButtonContent(
                    visual: ButtonVisualContent(
                        displayName: configuration.visual.displayName(fallback: configuration.smbServer.automaticDisplayName),
                        backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
                        backgroundAssetName: nil,
                        usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
                        dimsBackground: configuration.visual.dimsBackground,
                        hasCustomDisplayName: hasCustomDisplayName,
                        hasCustomBackground: configuration.visual.hasCustomBackground
                    )
                )
                title = content.displayName
                subtitle = configuration.smbServer.address
                smbServerButtonContent = content
            case .pageFolder:
                let content = PageFolderButtonContent(
                    visual: ButtonVisualContent(
                        displayName: configuration.visual.displayName(fallback: DeckKeyPageFolderConfiguration.defaultDisplayName),
                        backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
                        backgroundAssetName: nil,
                        usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
                        dimsBackground: configuration.visual.dimsBackground,
                        hasCustomDisplayName: hasCustomDisplayName,
                        hasCustomBackground: configuration.visual.hasCustomBackground
                    )
                )
                title = content.displayName
                subtitle = ""
                pageFolderButtonContent = content
            case .pageBack:
                let content = PageBackButtonContent(
                    displayName: configuration.visual.displayName(fallback: configuration.automaticButtonDisplayName)
                )
                title = content.displayName
                subtitle = ""
                pageBackButtonContent = content
            case .previousPage, .nextPage:
                title = configuration.visual.displayName(fallback: configuration.automaticButtonDisplayName)
                subtitle = ""
            case .brightness:
                title = configuration.visual.displayName(fallback: "")
                subtitle = ""
            case .sub2API:
                if case let .success(item) = configuration.sub2API.lastResult {
                    let content = Sub2APIButtonContent(
                        serviceName: configuration.sub2API.serviceDisplayName,
                        groupName: configuration.sub2API.displayName,
                        availableConcurrency: item.availableConcurrency
                    )
                    title = configuration.visual.displayName(fallback: content.availableConcurrencyText)
                    subtitle = "\(content.serviceName) \(content.groupName)"
                    sub2APIButtonContent = content
                } else if case .invalidToken = configuration.sub2API.lastResult {
                    title = configuration.visual.displayName(fallback: "令牌")
                    subtitle = "无效"
                } else if case .tokenExpired = configuration.sub2API.lastResult {
                    title = configuration.visual.displayName(fallback: "令牌")
                    subtitle = "已过期"
                } else if case .notFound = configuration.sub2API.lastResult {
                    title = configuration.visual.displayName(fallback: "未找到")
                    subtitle = "分组 \(configuration.sub2API.targetGroupID)"
                } else if case .networkError = configuration.sub2API.lastResult {
                    title = configuration.visual.displayName(fallback: "网络")
                    subtitle = "错误"
                } else {
                    title = configuration.visual.displayName(fallback: "号池")
                    subtitle = "未配置"
                }
            case .sub2APIBalance:
                let balance = configuration.sub2APIBalance
                let valueText: String
                let isFailure: Bool
                if let result = balance.lastResult,
                   let formattedValue = result.displayValue {
                    valueText = "\(balance.displayUnit)\(formattedValue)"
                    isFailure = false
                } else if balance.lastResult != nil {
                    valueText = "失败"
                    isFailure = true
                } else {
                    valueText = "失败"
                    isFailure = true
                }
                let content = Sub2APIButtonContent(
                    serviceName: balance.serviceDisplayName,
                    label: "余额",
                    valueText: valueText,
                    isFailure: isFailure
                )
                title = configuration.visual.displayName(fallback: valueText)
                subtitle = "\(content.serviceName) 余额"
                sub2APIButtonContent = content
            case .sub2APIDailyCost:
                let dailyCost = configuration.sub2APIDailyCost
                let valueText: String
                let isFailure: Bool
                if let formattedValue = dailyCost.lastResult?.displayValue {
                    valueText = "\(dailyCost.displayUnit)\(formattedValue)"
                    isFailure = false
                } else {
                    valueText = "失败"
                    isFailure = true
                }
                let content = Sub2APIButtonContent(
                    serviceName: dailyCost.serviceDisplayName,
                    label: "今日消费",
                    valueText: valueText,
                    isFailure: isFailure
                )
                title = configuration.visual.displayName(fallback: valueText)
                subtitle = "\(content.serviceName) 今日消费"
                sub2APIButtonContent = content
            case .newAPIModelAvailability:
                let availability = configuration.newAPIModelAvailability
                if case let .success(data) = availability.lastResult,
                   let group = data.groups.first(where: { $0.group == availability.normalizedSelectedGroup }) {
                    let content = NewAPIModelAvailabilityButtonContent(
                        serviceName: availability.serviceDisplayName,
                        groupName: availability.groupDisplayName,
                        successRate: group.successRate,
                        series: group.series
                    )
                    title = configuration.visual.displayName(fallback: content.successRateText)
                    subtitle = "\(content.serviceName) | \(content.groupName)"
                    newAPIModelAvailabilityButtonContent = content
                } else {
                    title = configuration.visual.displayName(fallback: "可用率")
                    subtitle = availability.groupDisplayName
                }
            case .codexUsage:
                switch configuration.codexUsage.lastResult {
                case let .success(quota):
                    codexUsageButtonContent = CodexUsageButtonContent(
                        accountNickname: configuration.codexUsage.displayAccountNickname,
                        percentageText: "\(quota.remainingPercent)%",
                        resetLabelText: "下次重设",
                        resetAfterText: configuration.codexUsage.resetDisplayMode.text(for: quota),
                        percentageColor: configuration.codexUsage.colorMode.metricColor(
                            for: quota.remainingPercent
                        ),
                        resetAfterColor: configuration.codexUsage.colorMode.resetTimeMetricColor(
                            for: quota.remainingTimeVsUsage
                        )
                    )
                    title = configuration.visual.displayName(
                        fallback: "\(quota.remainingPercent)%"
                    )
                    subtitle = quota.resetAfterText
                case .authFileNotSelected:
                    title = configuration.visual.displayName(fallback: "Codex 额度")
                    subtitle = "未选择 auth.json"
                case .authFileNeedsReselection:
                    title = configuration.visual.displayName(fallback: "Codex 额度")
                    subtitle = "需重选文件"
                case .invalidAuthFile:
                    title = configuration.visual.displayName(fallback: "auth.json")
                    subtitle = "JSON 格式无效"
                case .unsupportedAuthMode:
                    title = configuration.visual.displayName(fallback: "auth.json")
                    subtitle = "仅支持 ChatGPT 登录"
                case .unauthorized:
                    title = configuration.visual.displayName(fallback: "Codex 额度")
                    subtitle = "登录已失效"
                case .networkError:
                    title = configuration.visual.displayName(fallback: "Codex 额度")
                    subtitle = "刷新失败"
                case nil:
                    title = configuration.visual.displayName(fallback: "Codex 额度")
                    subtitle = configuration.codexUsage.authFilePath == nil ? "未配置" : "未刷新"
                }
            case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
                buttonBackgroundUsesFittedImage = false
                if case let .success(status) = configuration.mihoyoGame.lastResult {
                    title = configuration.visual.displayName(fallback: status.buttonTitle)
                    subtitle = status.buttonSubtitle
                    mihoyoGameButtonContent = status.buttonContent
                } else if case .loginRequired = configuration.mihoyoGame.lastResult {
                    title = configuration.visual.displayName(fallback: configuration.function.game?.shortDisplayName ?? "游戏")
                    subtitle = "未登录"
                } else if case .loginExpired = configuration.mihoyoGame.lastResult {
                    title = configuration.visual.displayName(fallback: configuration.function.game?.shortDisplayName ?? "游戏")
                    subtitle = "需重登"
                } else if case .noBoundRole = configuration.mihoyoGame.lastResult {
                    title = configuration.visual.displayName(fallback: configuration.function.game?.shortDisplayName ?? "游戏")
                    subtitle = "无角色"
                } else if case .networkError = configuration.mihoyoGame.lastResult {
                    title = configuration.visual.displayName(fallback: configuration.function.game?.shortDisplayName ?? "游戏")
                    subtitle = "查询失败"
                } else {
                    title = configuration.visual.displayName(fallback: configuration.function.game?.shortDisplayName ?? "游戏")
                    subtitle = "未查询"
                }
            }
        }
        let buttonVisualContent = ButtonVisualContent(
            displayName: title,
            backgroundPNGData: configuration.selectedButtonBackgroundPNGData,
            backgroundAssetName: nil,
            usesFittedBackgroundImage: buttonBackgroundUsesFittedImage,
            dimsBackground: configuration.visual.dimsBackground,
            hasCustomDisplayName: hasCustomDisplayName,
            hasCustomBackground: configuration.visual.hasCustomBackground
        )
        self.mihoyoGameButtonContent = mihoyoGameButtonContent
        self.codexUsageButtonContent = codexUsageButtonContent
        self.sub2APIButtonContent = sub2APIButtonContent
        self.newAPIModelAvailabilityButtonContent = newAPIModelAvailabilityButtonContent
        self.folderButtonContent = folderButtonContent
        self.fileButtonContent = fileButtonContent
        self.webPageButtonContent = webPageButtonContent
        self.smbServerButtonContent = smbServerButtonContent
        self.pageFolderButtonContent = pageFolderButtonContent
        self.pageBackButtonContent = pageBackButtonContent
        self.buttonVisualContent = buttonVisualContent
        self.isSelected = isSelected
        self.isPressed = isPressed
        canDelete = configuration.function != .pageBack
        canDrag = key.columnSpan == 1
    }

    var isWide: Bool {
        columnSpan > 1
    }

    var devicePixelSize: H200DeviceTarget.PixelSize {
        isWide ? H200DeviceTarget.smallWindowIconSize : H200DeviceTarget.buttonIconSize
    }

    var renderIdentity: DeckKeyRenderIdentity {
        DeckKeyRenderIdentity(
            id: id,
            row: row,
            column: column,
            columnSpan: columnSpan,
            displayMode: displayMode,
            title: title,
            subtitle: subtitle,
            mihoyoGame: mihoyoGame,
            mihoyoGameButtonContent: mihoyoGameButtonContent,
            codexUsageButtonContent: codexUsageButtonContent,
            sub2APIButtonContent: sub2APIButtonContent,
            newAPIModelAvailabilityButtonContent: newAPIModelAvailabilityButtonContent,
            folderButtonContent: folderButtonContent,
            fileButtonContent: fileButtonContent,
            webPageButtonContent: webPageButtonContent,
            smbServerButtonContent: smbServerButtonContent,
            pageFolderButtonContent: pageFolderButtonContent,
            pageBackButtonContent: pageBackButtonContent,
            buttonVisualContent: buttonVisualContent,
            devicePixelSize: devicePixelSize
        )
    }
}

nonisolated struct DeckKeyRenderIdentity: Equatable {
    let id: Int
    let row: Int
    let column: Int
    let columnSpan: Int
    let displayMode: DeckKeyDisplayMode
    let title: String
    let subtitle: String
    let mihoyoGame: MihoyoGame?
    let mihoyoGameButtonContent: MihoyoGameButtonContent?
    let codexUsageButtonContent: CodexUsageButtonContent?
    let sub2APIButtonContent: Sub2APIButtonContent?
    let newAPIModelAvailabilityButtonContent: NewAPIModelAvailabilityButtonContent?
    let folderButtonContent: FolderButtonContent?
    let fileButtonContent: FileButtonContent?
    let webPageButtonContent: WebPageButtonContent?
    let smbServerButtonContent: SMBServerButtonContent?
    let pageFolderButtonContent: PageFolderButtonContent?
    let pageBackButtonContent: PageBackButtonContent?
    let buttonVisualContent: ButtonVisualContent
    let devicePixelSize: H200DeviceTarget.PixelSize
}

nonisolated struct NewAPIModelAvailabilityButtonContent: Equatable {
    let serviceName: String
    let groupName: String
    let successRate: Double
    let series: [NewAPIModelAvailabilitySeriesPoint]

    var successRateText: String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), successRate)
    }
}

nonisolated struct CodexUsageButtonContent: Equatable, Sendable {
    let accountNickname: String?
    let percentageText: String
    let resetLabelText: String
    let resetAfterText: String
    let percentageColor: MihoyoGameMetricColor
    let resetAfterColor: MihoyoGameMetricColor
}

nonisolated struct ButtonVisualContent: Equatable {
    let displayName: String
    let backgroundPNGData: Data?
    let backgroundAssetName: String?
    let usesFittedBackgroundImage: Bool
    let dimsBackground: Bool
    let hasCustomDisplayName: Bool
    let hasCustomBackground: Bool
}

nonisolated struct FolderButtonContent: Equatable {
    let visual: ButtonVisualContent

    var displayName: String { visual.displayName }
    var backgroundPNGData: Data? { visual.backgroundPNGData }
    var dimsBackground: Bool { visual.dimsBackground }
}

nonisolated struct FileButtonContent: Equatable {
    let visual: ButtonVisualContent

    var displayName: String { visual.displayName }
    var backgroundPNGData: Data? { visual.backgroundPNGData }
    var dimsBackground: Bool { visual.dimsBackground }
}

nonisolated struct WebPageButtonContent: Equatable {
    let visual: ButtonVisualContent

    var displayName: String { visual.displayName }
    var backgroundPNGData: Data? { visual.backgroundPNGData }
    var dimsBackground: Bool { visual.dimsBackground }
}

nonisolated struct SMBServerButtonContent: Equatable {
    let visual: ButtonVisualContent

    var displayName: String { visual.displayName }
    var backgroundPNGData: Data? { visual.backgroundPNGData }
    var dimsBackground: Bool { visual.dimsBackground }
}

nonisolated struct PageFolderButtonContent: Equatable {
    let visual: ButtonVisualContent

    var displayName: String { visual.displayName }
    var backgroundPNGData: Data? { visual.backgroundPNGData }
    var dimsBackground: Bool { visual.dimsBackground }
}

nonisolated struct PageBackButtonContent: Equatable {
    let displayName: String
}

nonisolated struct DeckPreviewGridMetrics: Equatable {
    let cellLength: Double
    let spacing: Double

    static let h200 = DeckPreviewGridMetrics(cellLength: 82, spacing: 16)

    func slotWidth(columnSpan: Int) -> Double {
        let safeColumnSpan = max(1, columnSpan)
        return Double(safeColumnSpan) * cellLength + Double(safeColumnSpan - 1) * spacing
    }

    func rowWidth(for keys: [DeckGridLayout.Key]) -> Double {
        let slotWidth = keys.reduce(0) { partialResult, key in
            partialResult + self.slotWidth(columnSpan: key.columnSpan)
        }
        let visibleSpacing = Double(max(0, keys.count - 1)) * spacing
        return slotWidth + visibleSpacing
    }

    func gridHeight(rowCount: Int) -> Double {
        let safeRowCount = max(0, rowCount)
        guard safeRowCount > 0 else {
            return 0
        }

        let rowHeight = Double(safeRowCount) * cellLength
        let visibleSpacing = Double(safeRowCount - 1) * spacing
        return rowHeight + visibleSpacing
    }
}

nonisolated struct DeckPreviewLayoutMetrics: Equatable {
    let gridMetrics: DeckPreviewGridMetrics
    let outerHorizontalPadding: Double
    let outerVerticalPadding: Double
    let contentTopPadding: Double
    let contentBottomPadding: Double
    let innerPadding: Double
    let pageSpacing: Double
    let pageSelectorHeight: Double

    static let h200 = DeckPreviewLayoutMetrics(
        gridMetrics: .h200,
        outerHorizontalPadding: 28,
        outerVerticalPadding: 0,
        contentTopPadding: 16,
        contentBottomPadding: 16,
        innerPadding: 28,
        pageSpacing: 12,
        pageSelectorHeight: 26
    )

    func gridContentWidth(for layout: DeckGridLayout) -> Double {
        layout.rows
            .map { gridMetrics.rowWidth(for: $0) }
            .max() ?? 0
    }

    func gridContentHeight(for layout: DeckGridLayout) -> Double {
        gridMetrics.gridHeight(rowCount: layout.rows.count)
    }

    func deckSurfaceWidth(for layout: DeckGridLayout) -> Double {
        gridContentWidth(for: layout) + innerPadding * 2
    }

    func deckSurfaceHeight(for layout: DeckGridLayout) -> Double {
        gridContentHeight(for: layout) + innerPadding * 2
    }

    func previewAreaMinimumWidth(for layout: DeckGridLayout) -> Double {
        deckSurfaceWidth(for: layout) + outerHorizontalPadding * 2
    }

    func previewAreaHeight(for layout: DeckGridLayout) -> Double {
        contentTopPadding
            + deckSurfaceHeight(for: layout)
            + pageSpacing
            + pageSelectorHeight
            + contentBottomPadding
            + outerVerticalPadding * 2
    }
}

nonisolated struct DeckGridPage: Equatable {
    let id: String
    var parentID: String?
    var configurations: [Int: DeckKeyConfiguration]
}

nonisolated struct RootPageNavigationItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isCurrent: Bool
    let canDelete: Bool
}

nonisolated struct DeckKeySub2APIReferenceOption: Identifiable, Equatable {
    let instanceID: String
    let title: String

    var id: String { instanceID }
}

/// 公共 Sub2API 来源图工具。来源只允许指向自定义根，因而同类型和跨类型
/// 的循环都在加载和编辑时由同一份规则拒绝。
nonisolated enum Sub2APIDataSourceGraph {
    static func resolvedSourceInstanceID(
        for instanceID: String,
        in configurations: [String: Sub2APIDataSourceConfiguration]
    ) -> String? {
        var current = instanceID
        var visited: Set<String> = []
        while visited.insert(current).inserted {
            guard let configuration = configurations[current] else {
                return nil
            }
            guard let sourceID = configuration.dataSourceInstanceID else {
                return current
            }
            current = sourceID
        }
        return nil
    }

    static func resolvedConfiguration(
        for instanceID: String,
        in configurations: [String: Sub2APIDataSourceConfiguration]
    ) -> Sub2APIDataSourceConfiguration? {
        guard let consumer = configurations[instanceID],
              let sourceID = resolvedSourceInstanceID(for: instanceID, in: configurations),
              let source = configurations[sourceID]
        else {
            return nil
        }

        var resolved = source
        resolved.instanceID = sourceID
        // 跨查询类型只共享 Base URL/认证；同类型才继承刷新间隔。
        if source.queryKind != consumer.queryKind {
            resolved.queryKind = consumer.queryKind
            resolved.refreshInterval = consumer.refreshInterval
        }
        return resolved
    }

    static func invalidReferenceInstanceIDs(
        in configurations: [String: Sub2APIDataSourceConfiguration]
    ) -> Set<String> {
        var invalid: Set<String> = []
        for (instanceID, configuration) in configurations {
            guard let sourceID = configuration.dataSourceInstanceID else {
                continue
            }

            guard sourceID != instanceID,
                  let source = configurations[sourceID],
                  source.dataSourceInstanceID == nil,
                  resolvedSourceInstanceID(for: instanceID, in: configurations) != nil
            else {
                invalid.insert(instanceID)
                invalid.insert(sourceID)
                continue
            }
        }
        return invalid
    }

    static func canReference(
        candidateInstanceID: String,
        from instanceID: String,
        in configurations: [String: Sub2APIDataSourceConfiguration]
    ) -> Bool {
        guard candidateInstanceID != instanceID,
              configurations[instanceID] != nil,
              let candidate = configurations[candidateInstanceID],
              candidate.dataSourceInstanceID == nil,
              !invalidReferenceInstanceIDs(in: configurations).contains(instanceID),
              !invalidReferenceInstanceIDs(in: configurations).contains(candidateInstanceID)
        else {
            return false
        }
        return !isReferenced(instanceID, in: configurations)
            && resolvedSourceInstanceID(for: candidateInstanceID, in: configurations) != instanceID
    }

    private static func isReferenced(
        _ instanceID: String,
        in configurations: [String: Sub2APIDataSourceConfiguration]
    ) -> Bool {
        configurations.values.contains { $0.dataSourceInstanceID == instanceID }
    }
}

nonisolated struct DeckGridInteractionState: Equatable {
    static let rootPageID = "root"
    static let maximumRootPageCount = 10
    static let maximumNestedPageDepth = 3

    private(set) var selectedKeyID: Int?
    private(set) var currentPageID: String
    private(set) var rootPageIDs: [String]
    private var pages: [String: DeckGridPage]
    private(set) var pressedKeyIDs: Set<Int>
    private let layout: DeckGridLayout
    private let validKeyIDs: Set<Int>
    private let wideKeyIDs: Set<Int>

    var configurations: [Int: DeckKeyConfiguration] {
        get {
            pages[currentPageID]?.configurations ?? [:]
        }
        set {
            if pages[currentPageID] == nil {
                pages[currentPageID] = DeckGridPage(id: currentPageID, parentID: nil, configurations: [:])
            }
            pages[currentPageID]?.configurations = newValue
        }
    }

    var persistedPages: [DeckGridPage] {
        pages.values.sorted { first, second in
            let firstRootIndex = rootPageIDs.firstIndex(of: first.id)
            let secondRootIndex = rootPageIDs.firstIndex(of: second.id)
            switch (firstRootIndex, secondRootIndex) {
            case let (.some(firstIndex), .some(secondIndex)):
                return firstIndex < secondIndex
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return first.id < second.id
            }
        }
    }

    var currentRootPageID: String {
        rootPageID(containing: currentPageID) ?? rootPageIDs.first ?? Self.rootPageID
    }

    var currentRootPageIndex: Int {
        rootPageIDs.firstIndex(of: currentRootPageID) ?? 0
    }

    var rootPageCount: Int {
        rootPageIDs.count
    }

    var canAddRootPage: Bool {
        rootPageIDs.count < Self.maximumRootPageCount && isOnRootPage
    }

    var canDeleteCurrentRootPage: Bool {
        rootPageIDs.count > 1 && isOnRootPage
    }

    var rootPageNavigationItems: [RootPageNavigationItem] {
        rootPageIDs.enumerated().map { index, pageID in
            RootPageNavigationItem(
                id: pageID,
                title: "\(index + 1)",
                isCurrent: pageID == currentRootPageID,
                canDelete: rootPageIDs.count > 1 && pageID == currentPageID
            )
        }
    }

    var currentPageDepth: Int {
        pageDepth(pageID: currentPageID)
    }

    var isOnRootPage: Bool {
        rootPageIDs.contains(currentPageID)
    }

    var navigationPathTitles: [String] {
        navigationPathPageIDs().map { pageID in
            if let rootIndex = rootPageIDs.firstIndex(of: pageID) {
                return "\(rootIndex + 1)"
            }
            return DeckKeyPageFolderConfiguration.defaultDisplayName
        }
    }

    init(layout: DeckGridLayout) {
        selectedKeyID = layout.keys.first?.id
        currentPageID = Self.rootPageID
        rootPageIDs = [Self.rootPageID]
        self.layout = layout
        pages = [
            Self.rootPageID: DeckGridPage(
                id: Self.rootPageID,
                parentID: nil,
                configurations: Self.rootConfigurations(for: layout)
            ),
        ]
        pressedKeyIDs = []
        validKeyIDs = Set(layout.keys.map(\.id))
        wideKeyIDs = Set(layout.keys.filter { $0.columnSpan > 1 }.map(\.id))
    }

    init(layout: DeckGridLayout, configurations storedConfigurations: [Int: DeckKeyConfiguration]) {
        self.init(layout: layout, pages: [
            DeckGridPage(
                id: Self.rootPageID,
                parentID: nil,
                configurations: storedConfigurations
            ),
        ])
    }

    init(layout: DeckGridLayout, pages storedPages: [DeckGridPage]) {
        self.init(layout: layout, pages: storedPages, rootPageIDs: [])
    }

    init(layout: DeckGridLayout, pages storedPages: [DeckGridPage], rootPageIDs storedRootPageIDs: [String]) {
        let validKeyIDs = Set(layout.keys.map(\.id))
        let wideKeyIDs = Set(layout.keys.filter { $0.columnSpan > 1 }.map(\.id))
        self.layout = layout
        self.validKeyIDs = validKeyIDs
        self.wideKeyIDs = wideKeyIDs
        selectedKeyID = layout.keys.first?.id
        currentPageID = Self.rootPageID
        rootPageIDs = []
        pressedKeyIDs = []

        var normalizedPages: [String: DeckGridPage] = [:]
        for page in storedPages where !page.id.isEmpty {
            let isRootPage = page.parentID == nil
            let defaultConfigurations = isRootPage
                ? Self.rootConfigurations(for: layout)
                : Self.childPageConfigurations(for: layout)
            normalizedPages[page.id] = DeckGridPage(
                id: page.id,
                parentID: isRootPage ? nil : page.parentID,
                configurations: Self.normalizedConfigurations(
                    page.configurations,
                    defaultConfigurations: defaultConfigurations,
                    allowsPageBack: !isRootPage,
                    wideKeyIDs: wideKeyIDs
                )
            )
        }

        var seenRootPageIDs: Set<String> = []
        var normalizedRootPageIDs = storedRootPageIDs
            .filter { pageID in
                normalizedPages[pageID]?.parentID == nil && seenRootPageIDs.insert(pageID).inserted
            }
        if normalizedRootPageIDs.isEmpty {
            seenRootPageIDs.removeAll()
            normalizedRootPageIDs = storedPages
                .filter { page in
                    page.parentID == nil && normalizedPages[page.id] != nil
                        && seenRootPageIDs.insert(page.id).inserted
                }
                .map(\.id)
        }
        normalizedRootPageIDs = Array(normalizedRootPageIDs.prefix(Self.maximumRootPageCount))

        if normalizedRootPageIDs.isEmpty {
            normalizedRootPageIDs = [Self.rootPageID]
        }

        if normalizedPages[normalizedRootPageIDs[0]] == nil {
            normalizedPages[Self.rootPageID] = DeckGridPage(
                id: Self.rootPageID,
                parentID: nil,
                configurations: Self.rootConfigurations(for: layout)
            )
            normalizedRootPageIDs[0] = Self.rootPageID
        }
        if !normalizedRootPageIDs.contains(Self.rootPageID),
           let rootPage = normalizedPages.removeValue(forKey: normalizedRootPageIDs[0]) {
            normalizedPages[Self.rootPageID] = DeckGridPage(
                id: Self.rootPageID,
                parentID: nil,
                configurations: rootPage.configurations
            )
            let previousRootPageID = normalizedRootPageIDs[0]
            normalizedRootPageIDs[0] = Self.rootPageID
            let childPageIDs = normalizedPages.keys.filter { normalizedPages[$0]?.parentID == previousRootPageID }
            for pageID in childPageIDs {
                normalizedPages[pageID]?.parentID = Self.rootPageID
            }
        }
        rootPageIDs = normalizedRootPageIDs
        currentPageID = rootPageIDs[0]
        let reachablePageIDs = Self.reachablePageIDs(
            in: normalizedPages,
            from: rootPageIDs
        )
        normalizedPages = normalizedPages.filter { reachablePageIDs.contains($0.key) }
        for pageID in Array(normalizedPages.keys) where !rootPageIDs.contains(pageID) {
            let configurations = normalizedPages[pageID]?.configurations ?? [:]
            normalizedPages[pageID]?.configurations = Self.ensureBackKey(
                in: configurations,
                layout: layout
            )
        }
        pages = normalizedPages
        normalizeSub2APIInstanceIDs()
    }

    private static func reachablePageIDs(
        in pages: [String: DeckGridPage],
        from rootPageIDs: [String]
    ) -> Set<String> {
        var reachablePageIDs = Set(rootPageIDs)
        var pendingPageIDs = rootPageIDs
        var pendingIndex = 0

        while pendingIndex < pendingPageIDs.count {
            let pageID = pendingPageIDs[pendingIndex]
            pendingIndex += 1
            guard let page = pages[pageID] else {
                continue
            }

            for configuration in page.configurations.values where configuration.function == .pageFolder {
                guard let childPageID = configuration.pageFolder.pageID,
                      let childPage = pages[childPageID],
                      childPage.parentID == pageID,
                      reachablePageIDs.insert(childPageID).inserted
                else {
                    continue
                }

                pendingPageIDs.append(childPageID)
            }
        }

        return reachablePageIDs
    }

    private static func rootConfigurations(for layout: DeckGridLayout) -> [Int: DeckKeyConfiguration] {
        Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
    }

    private static func newRootPageConfigurations(
        for layout: DeckGridLayout,
        inheritingDisplayModesFrom previousConfigurations: [Int: DeckKeyConfiguration]
    ) -> [Int: DeckKeyConfiguration] {
        Dictionary(uniqueKeysWithValues: layout.keys.map { key in
            var configuration = DeckKeyConfiguration.empty
            if key.columnSpan > 1 {
                configuration.displayMode = previousConfigurations[key.id]?.displayMode ?? .function
            }
            return (key.id, configuration)
        })
    }

    private static func childPageConfigurations(
        for layout: DeckGridLayout,
        inheritingDisplayModesFrom parentConfigurations: [Int: DeckKeyConfiguration] = [:]
    ) -> [Int: DeckKeyConfiguration] {
        let emptyConfigurations = Dictionary(uniqueKeysWithValues: layout.keys.map { key in
            var configuration = DeckKeyConfiguration.empty
            if key.columnSpan > 1 {
                configuration.displayMode = parentConfigurations[key.id]?.displayMode ?? .function
            }
            return (key.id, configuration)
        })
        return ensureBackKey(in: emptyConfigurations, layout: layout)
    }

    private static func ensureBackKey(
        in configurations: [Int: DeckKeyConfiguration],
        layout: DeckGridLayout
    ) -> [Int: DeckKeyConfiguration] {
        if configurations.values.contains(where: { $0.function == .pageBack }) {
            return configurations
        }

        guard let key = defaultBackKey(in: layout) else {
            return configurations
        }

        var updatedConfigurations = configurations
        var pageBackConfiguration = DeckKeyConfiguration.pageBack
        pageBackConfiguration.refreshDefaultButtonBackgroundSnapshot()
        updatedConfigurations[key.id] = pageBackConfiguration
        return updatedConfigurations
    }

    private static func defaultBackKey(in layout: DeckGridLayout) -> DeckGridLayout.Key? {
        layout.keys.first { $0.id == 13 && $0.columnSpan == 1 }
            ?? layout.keys.last { $0.columnSpan == 1 }
    }

    private static func normalizedConfigurations(
        _ storedConfigurations: [Int: DeckKeyConfiguration],
        defaultConfigurations: [Int: DeckKeyConfiguration],
        allowsPageBack: Bool,
        wideKeyIDs: Set<Int>
    ) -> [Int: DeckKeyConfiguration] {
        var normalizedConfigurations = defaultConfigurations
        for keyID in normalizedConfigurations.keys {
            if let configuration = storedConfigurations[keyID] {
                normalizedConfigurations[keyID] = Self.normalized(
                    configuration,
                    isWide: wideKeyIDs.contains(keyID),
                    allowsPageBack: allowsPageBack
                )
            }
        }
        return normalizedConfigurations
    }

    private static func normalized(
        _ configuration: DeckKeyConfiguration,
        isWide: Bool,
        allowsPageBack: Bool
    ) -> DeckKeyConfiguration {
        var normalizedConfiguration = configuration
        if normalizedConfiguration.function == .brightness {
            normalizedConfiguration = .empty
        }

        if normalizedConfiguration.function == .pageBack, (!allowsPageBack || isWide) {
            normalizedConfiguration = .empty
        }

        if normalizedConfiguration.function == .pageFolder, isWide {
            normalizedConfiguration = .empty
        }

        if !isWide {
            normalizedConfiguration.displayMode = .function
        }

        normalizedConfiguration.refreshDefaultButtonBackgroundSnapshot()
        return normalizedConfiguration
    }

    mutating func select(keyID: Int) {
        guard validKeyIDs.contains(keyID) else {
            return
        }

        selectedKeyID = keyID
    }

    func canSwapSquareConfigurations(sourceKeyID: Int, targetKeyID: Int) -> Bool {
        sourceKeyID != targetKeyID
            && validKeyIDs.contains(sourceKeyID)
            && validKeyIDs.contains(targetKeyID)
            && !wideKeyIDs.contains(sourceKeyID)
            && !wideKeyIDs.contains(targetKeyID)
    }

    @discardableResult
    mutating func swapSquareConfigurations(sourceKeyID: Int, targetKeyID: Int) -> Bool {
        guard canSwapSquareConfigurations(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID) else {
            return false
        }

        let sourceConfiguration = configurations[sourceKeyID, default: .tallyDefault]
        configurations[sourceKeyID] = configurations[targetKeyID, default: .tallyDefault]
        configurations[targetKeyID] = sourceConfiguration
        pressedKeyIDs.remove(sourceKeyID)
        pressedKeyIDs.remove(targetKeyID)

        if selectedKeyID == sourceKeyID {
            selectedKeyID = targetKeyID
        } else if selectedKeyID == targetKeyID {
            selectedKeyID = sourceKeyID
        }

        return true
    }

    mutating func beginPress(keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].displayMode == .function,
              configurations[keyID, default: .tallyDefault].function.pressRuntimeAction != .none,
              !pressedKeyIDs.contains(keyID)
        else {
            return false
        }

        pressedKeyIDs.insert(keyID)
        return true
    }

    mutating func endPress(keyID: Int) {
        pressedKeyIDs.remove(keyID)
    }

    @discardableResult
    mutating func triggerShortPress(keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].displayMode == .function,
              configurations[keyID, default: .tallyDefault].function == .tally
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].tally.value += 1
        return true
    }

    @discardableResult
    mutating func addRootPageAfterCurrent() -> Bool {
        guard canAddRootPage else {
            return false
        }

        let newRootPageID = makeRootPageID()
        let insertionIndex = currentRootPageIndex + 1
        rootPageIDs.insert(newRootPageID, at: min(insertionIndex, rootPageIDs.count))
        pages[newRootPageID] = DeckGridPage(
            id: newRootPageID,
            parentID: nil,
            configurations: Self.newRootPageConfigurations(
                for: layout,
                inheritingDisplayModesFrom: configurations
            )
        )
        currentPageID = newRootPageID
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func deleteCurrentRootPage() -> Bool {
        guard canDeleteCurrentRootPage else {
            return false
        }

        let deletedPageID = currentPageID
        let deletedIndex = currentRootPageIndex
        rootPageIDs.removeAll { $0 == deletedPageID }
        removePageSubtree(deletedPageID)
        normalizeSub2APIDataSources()
        let nextIndex = max(0, min(deletedIndex - 1, rootPageIDs.count - 1))
        currentPageID = rootPageIDs[nextIndex]
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func goToRootPage(id pageID: String) -> Bool {
        guard canGoToRootPage(id: pageID) else { return false }

        currentPageID = pageID
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    func canGoToRootPage(id pageID: String) -> Bool {
        isOnRootPage && rootPageIDs.contains(pageID) && currentPageID != pageID
    }

    @discardableResult
    mutating func goToPreviousRootPage() -> Bool {
        guard canGoToPreviousRootPage else { return false }

        currentPageID = rootPageIDs[currentRootPageIndex - 1]
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    var canGoToPreviousRootPage: Bool {
        isOnRootPage && currentRootPageIndex > 0
    }

    @discardableResult
    mutating func goToNextRootPage() -> Bool {
        guard canGoToNextRootPage else { return false }

        currentPageID = rootPageIDs[currentRootPageIndex + 1]
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    var canGoToNextRootPage: Bool {
        isOnRootPage && currentRootPageIndex < rootPageIDs.count - 1
    }

    func folderPath(for keyID: Int) -> String? {
        configurations[keyID, default: .tallyDefault].openFolder.path
    }

    func openFolderConfiguration(for keyID: Int) -> DeckKeyOpenFolderConfiguration {
        configurations[keyID, default: .tallyDefault].openFolder
    }

    func filePath(for keyID: Int) -> String? {
        configurations[keyID, default: .tallyDefault].openFile.path
    }

    func openFileConfiguration(for keyID: Int) -> DeckKeyOpenFileConfiguration {
        configurations[keyID, default: .tallyDefault].openFile
    }

    func webPageURLString(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].openWebPage.urlString
    }

    func openWebPageConfiguration(for keyID: Int) -> DeckKeyOpenWebPageConfiguration {
        configurations[keyID, default: .tallyDefault].openWebPage
    }

    func smbServerAddress(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].smbServer.address
    }

    func smbServerName(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].smbServer.name
    }

    func sub2APIConfiguration(for keyID: Int) -> DeckKeySub2APIConfiguration {
        configurations[keyID, default: .tallyDefault].sub2API
    }

    func sub2APIBalanceConfiguration(for keyID: Int) -> DeckKeySub2APIBalanceConfiguration {
        configurations[keyID, default: .tallyDefault].sub2APIBalance
    }

    func sub2APIDailyCostConfiguration(for keyID: Int) -> DeckKeySub2APIDailyCostConfiguration {
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost
    }

    func newAPIModelAvailabilityConfiguration(for keyID: Int) -> DeckKeyNewAPIModelAvailabilityConfiguration {
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability
    }

    func codexUsageConfiguration(for keyID: Int) -> DeckKeyCodexUsageConfiguration {
        configurations[keyID, default: .tallyDefault].codexUsage
    }

    func resolvedSub2APIBearerKey(for keyID: Int) -> String {
        resolvedSub2APIDataSourceValue(for: keyID)?.bearerKey ?? ""
    }

    func resolvedSub2APIDataSourceInstanceID(for keyID: Int) -> String {
        guard configurations[keyID]?.function.isSub2APIQuery == true else {
            return ""
        }

        let instanceID = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration.instanceID
        return Sub2APIDataSourceGraph.resolvedSourceInstanceID(
            for: instanceID,
            in: activeSub2APIDataSourceConfigurationsByInstanceID()
        ) ?? instanceID
    }

    func resolvedSub2APIDataSourceConfiguration(for keyID: Int) -> DeckKeySub2APIConfiguration? {
        guard let configuration = configurations[keyID], configuration.function == .sub2API,
              let resolved = Sub2APIDataSourceGraph.resolvedConfiguration(
                for: configuration.sub2APIDataSourceConfiguration.instanceID,
                in: activeSub2APIDataSourceConfigurationsByInstanceID()
              )
        else {
            return nil
        }

        var result = configuration.sub2API
        result.instanceID = resolved.instanceID
        result.baseURL = resolved.baseURL
        result.dataSourceInstanceID = nil
        result.refreshInterval = resolved.refreshInterval
        result.bearerKey = resolved.bearerKey
        result.credentialID = resolved.credentialID
        return result
    }

    func resolvedSub2APIDataSourceValue(for keyID: Int) -> Sub2APIDataSourceConfiguration? {
        guard let configuration = configurations[keyID],
              configuration.function.isSub2APIQuery
        else { return nil }
        return Sub2APIDataSourceGraph.resolvedConfiguration(
            for: configuration.sub2APIDataSourceConfiguration.instanceID,
            in: activeSub2APIDataSourceConfigurationsByInstanceID()
        )
    }

    func resolvedSub2APIBaseURL(for keyID: Int) -> String {
        resolvedSub2APIDataSourceValue(for: keyID)?.baseURL ?? ""
    }

    func resolvedSub2APIRefreshInterval(for keyID: Int) -> Int {
        resolvedSub2APIDataSourceValue(for: keyID)?.refreshInterval ?? 30
    }

    func canSetSub2APIRefreshInterval(for keyID: Int) -> Bool {
        guard let configuration = configurations[keyID],
              configuration.function.isSub2APIQuery
        else {
            return false
        }

        let consumer = configuration.sub2APIDataSourceConfiguration
        guard let sourceID = consumer.dataSourceInstanceID else {
            return true
        }

        guard let source = activeSub2APIDataSourceConfigurationsByInstanceID()[sourceID] else {
            return false
        }

        // 同类查询共享来源的刷新间隔；跨余额/号池查询只共享认证和 Base URL。
        return source.queryKind != consumer.queryKind
    }

    func sub2APIDataSourceReferenceOptions(for keyID: Int) -> [DeckKeySub2APIReferenceOption] {
        guard configurations[keyID]?.function.isSub2APIQuery == true else {
            return []
        }

        let currentInstanceID = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration.instanceID
        return sub2APIReferenceOptions(for: currentInstanceID)
    }

    func mihoyoGame(for keyID: Int) -> MihoyoGame? {
        configurations[keyID, default: .tallyDefault].function.game
    }

    func mihoyoGameConfiguration(for keyID: Int) -> DeckKeyMihoyoGameConfiguration {
        configurations[keyID, default: .tallyDefault].mihoyoGame
    }

    func canAssignPageFolder(to keyID: Int) -> Bool {
        validKeyIDs.contains(keyID)
            && !wideKeyIDs.contains(keyID)
            && currentPageDepth < Self.maximumNestedPageDepth
            && configurations[keyID, default: .tallyDefault].function != .pageBack
    }

    func canDeleteFunction(keyID: Int) -> Bool {
        validKeyIDs.contains(keyID)
            && configurations[keyID, default: .tallyDefault].function != .pageBack
    }

    func pageID(for keyID: Int) -> String? {
        guard configurations[keyID, default: .tallyDefault].function == .pageFolder else {
            return nil
        }

        return configurations[keyID, default: .tallyDefault].pageFolder.pageID
    }

    @discardableResult
    mutating func enterPageFolder(keyID: Int) -> Bool {
        guard let pageID = pageID(for: keyID),
              pages[pageID] != nil
        else {
            return false
        }

        currentPageID = pageID
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func goBackPage() -> Bool {
        guard let parentID = pages[currentPageID]?.parentID,
              pages[parentID] != nil
        else {
            return false
        }

        currentPageID = parentID
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func goToRootPage() -> Bool {
        guard currentPageID != rootPageIDs[0] else {
            return false
        }

        currentPageID = rootPageIDs[0]
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func setSub2APIBaseURL(_ baseURL: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.isSub2APIQuery,
              configurations[keyID, default: .tallyDefault]
                .sub2APIDataSourceConfiguration.dataSourceInstanceID == nil
        else {
            return false
        }

        selectedKeyID = keyID
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var dataSource = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration
        if dataSource.baseURL != normalizedBaseURL {
            clearSub2APIQueryRuntimeState(for: keyID)
        }
        dataSource.baseURL = normalizedBaseURL
        configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        return true
    }

    @discardableResult
    mutating func setNewAPIBaseURL(_ baseURL: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.baseURL =
            baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastResult = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulSnapshot = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.groupListState = .idle
        return true
    }

    @discardableResult
    mutating func setNewAPIRefreshInterval(_ interval: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.refreshInterval = max(5, interval)
        return true
    }

    @discardableResult
    mutating func setNewAPIModelName(_ modelName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        let normalized = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if configurations[keyID, default: .tallyDefault].newAPIModelAvailability.modelName != normalized {
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastResult = nil
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulRefreshAt = nil
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulSnapshot = nil
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.groupListState = .idle
        }
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.modelName = normalized
        return true
    }

    @discardableResult
    mutating func setNewAPISelectedGroup(_ group: String?, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        let normalized = group?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = normalized?.isEmpty == false ? normalized : nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.selectedGroup = value
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastResult = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulSnapshot = nil
        return true
    }

    @discardableResult
    mutating func setNewAPIServiceName(_ serviceName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.customServiceName =
            serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    @discardableResult
    mutating func setNewAPIGroupName(_ groupName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.customGroupName =
            groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    @discardableResult
    mutating func setNewAPIGroupListState(
        _ state: DeckKeyNewAPIModelAvailabilityGroupListState,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.groupListState = state
        return true
    }

    @discardableResult
    mutating func setNewAPILastResult(
        _ result: NewAPIModelAvailabilityResult,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastResult = result
        if case .success = result {
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulRefreshAt = Date()
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulSnapshot = result
        }
        return true
    }

    @discardableResult
    mutating func clearNewAPIRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .newAPIModelAvailability
        else { return false }
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastResult = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulSnapshot = nil
        configurations[keyID, default: .tallyDefault].newAPIModelAvailability.lastSuccessfulRefreshAt = nil
        return true
    }

    @discardableResult
    mutating func setSub2APITargetGroupID(_ groupID: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        if configurations[keyID, default: .tallyDefault].sub2API.targetGroupID != groupID {
            configurations[keyID, default: .tallyDefault].sub2API.lastResult = nil
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulSnapshot = nil
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulRefreshAt = nil
        }
        configurations[keyID, default: .tallyDefault].sub2API.targetGroupID = groupID
        return true
    }

    @discardableResult
    mutating func setSub2APIRefreshInterval(_ interval: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              canSetSub2APIRefreshInterval(for: keyID)
        else {
            return false
        }

        selectedKeyID = keyID
        var dataSource = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration
        dataSource.refreshInterval = max(5, interval)
        configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        return true
    }

    @discardableResult
    mutating func setSub2APIBearerKey(_ bearerKey: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.isSub2APIQuery,
              configurations[keyID, default: .tallyDefault]
                .sub2APIDataSourceConfiguration.dataSourceInstanceID == nil
        else {
            return false
        }

        selectedKeyID = keyID
        var dataSource = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration
        let previousCredentialID = dataSource.credentialID
        if dataSource.bearerKey != bearerKey {
            clearSub2APIQueryRuntimeState(for: keyID)
        }
        if !bearerKey.isEmpty, dataSource.credentialID == nil {
            dataSource.credentialID = UUID().uuidString
        } else if bearerKey.isEmpty {
            dataSource.credentialID = nil
        }
        dataSource.bearerKey = bearerKey
        configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        if let credentialID = dataSource.credentialID {
            propagateSub2APIBearerKey(bearerKey, credentialID: credentialID)
        } else if !bearerKey.isEmpty {
            // UUID 生成失败不会发生，但不要让一个旧共享 ID 留下过时 token。
            if let previousCredentialID {
                propagateSub2APIBearerKey("", credentialID: previousCredentialID)
            }
        } else if let previousCredentialID {
            propagateSub2APIBearerKey("", credentialID: previousCredentialID)
        }
        return true
    }

    /// 将刷新后的认证写回真实来源根，而不是写回触发请求的引用消费者。
    @discardableResult
    mutating func setSub2APIBearerKey(
        _ bearerKey: String,
        forDataSourceInstanceID instanceID: String
    ) -> Bool {
        for pageID in pages.keys.sorted() {
            guard var page = pages[pageID] else { continue }
            for keyID in page.configurations.keys.sorted() {
                guard var configuration = page.configurations[keyID],
                      configuration.function.isSub2APIQuery,
                      configuration.sub2APIDataSourceConfiguration.instanceID == instanceID,
                      configuration.sub2APIDataSourceConfiguration.dataSourceInstanceID == nil
                else { continue }

                var dataSource = configuration.sub2APIDataSourceConfiguration
                let previousCredentialID = dataSource.credentialID
                if dataSource.bearerKey != bearerKey {
                    if configuration.function == .sub2API {
                        configuration.sub2API.groupListState = .idle
                        configuration.sub2API.lastResult = nil
                        configuration.sub2API.lastSuccessfulRefreshAt = nil
                        configuration.sub2API.lastSuccessfulSnapshot = nil
                    } else if configuration.function == .sub2APIBalance {
                        configuration.sub2APIBalance.lastResult = nil
                        configuration.sub2APIBalance.lastSuccessfulRefreshAt = nil
                        configuration.sub2APIBalance.lastSuccessfulSnapshot = nil
                    } else {
                        configuration.sub2APIDailyCost.lastResult = nil
                        configuration.sub2APIDailyCost.lastSuccessfulRefreshAt = nil
                        configuration.sub2APIDailyCost.lastSuccessfulSnapshot = nil
                    }
                }
                if !bearerKey.isEmpty, dataSource.credentialID == nil {
                    dataSource.credentialID = UUID().uuidString
                } else if bearerKey.isEmpty {
                    dataSource.credentialID = nil
                }
                dataSource.bearerKey = bearerKey
                configuration.sub2APIDataSourceConfiguration = dataSource
                page.configurations[keyID] = configuration
                pages[pageID] = page
                if let credentialID = dataSource.credentialID {
                    propagateSub2APIBearerKey(bearerKey, credentialID: credentialID)
                } else if let previousCredentialID {
                    propagateSub2APIBearerKey("", credentialID: previousCredentialID)
                }
                return true
            }
        }
        return false
    }

    @discardableResult
    mutating func setSub2APIDataSourceInstanceID(_ sourceInstanceID: String?, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.isSub2APIQuery
        else {
            return false
        }

        let normalizedSourceInstanceID = sourceInstanceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateSourceInstanceID = normalizedSourceInstanceID?.isEmpty == false
            ? normalizedSourceInstanceID
            : nil
        let currentInstanceID = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration.instanceID
        if let candidateSourceInstanceID {
            let configurationsByInstanceID = activeSub2APIDataSourceConfigurationsByInstanceID()
            guard Sub2APIDataSourceGraph.canReference(
                candidateInstanceID: candidateSourceInstanceID,
                from: currentInstanceID,
                in: configurationsByInstanceID
            )
            else {
                return false
            }
        }

        selectedKeyID = keyID
        guard configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration.dataSourceInstanceID
                != candidateSourceInstanceID
        else {
            return false
        }
        var dataSource = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration
        dataSource.dataSourceInstanceID = candidateSourceInstanceID
        if candidateSourceInstanceID == nil {
            dataSource.baseURL = ""
            dataSource.bearerKey = ""
            dataSource.credentialID = nil
        }
        configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        clearSub2APIQueryRuntimeState(for: keyID)
        return true
    }

    @discardableResult
    mutating func restoreSub2APICredential(
        bearerKey: String,
        credentialID: String?,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.isSub2APIQuery
        else {
            return false
        }

        var dataSource = configurations[keyID, default: .tallyDefault]
            .sub2APIDataSourceConfiguration
        dataSource.bearerKey = bearerKey
        dataSource.credentialID = credentialID
        configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        if let credentialID {
            propagateSub2APIBearerKey(bearerKey, credentialID: credentialID)
        }
        return true
    }

    /// 将同一 credential ID 的所有持久化消费者同步到一个 bearer 值。
    /// 共享凭据只有一个逻辑 owner，避免刷新或手动更新后保留旧引用值。
    /// 空值表示显式删除：所有消费者也必须移除 credential ID，使持久化层
    /// 能够识别最后一个引用已消失并删除 Keychain 项。
    private mutating func propagateSub2APIBearerKey(_ bearerKey: String, credentialID: String) {
        for pageID in pages.keys.sorted() {
            guard var page = pages[pageID] else { continue }
            for keyID in page.configurations.keys.sorted() {
                guard var configuration = page.configurations[keyID],
                      configuration.sub2APIDataSourceConfiguration.credentialID == credentialID
                else { continue }
                configuration.sub2APIDataSourceConfiguration.bearerKey = bearerKey
                if bearerKey.isEmpty {
                    configuration.sub2APIDataSourceConfiguration.credentialID = nil
                }
                page.configurations[keyID] = configuration
            }
            pages[pageID] = page
        }
    }

    @discardableResult
    mutating func setSub2APIServiceName(_ serviceName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.isSub2APIQuery
        else {
            return false
        }

        selectedKeyID = keyID
        let normalized = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if configurations[keyID, default: .tallyDefault].function == .sub2API {
            configurations[keyID, default: .tallyDefault].sub2API.customServiceName = normalized
        } else if configurations[keyID, default: .tallyDefault].function == .sub2APIBalance {
            configurations[keyID, default: .tallyDefault].sub2APIBalance.customServiceName = normalized
        } else {
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.customServiceName = normalized
        }
        return true
    }

    @discardableResult
    mutating func setSub2APIBalanceUnit(_ unit: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2APIBalance
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2APIBalance.unit = unit
        return true
    }

    @discardableResult
    mutating func setSub2APIBalanceLastResult(_ result: Sub2APIBalanceResult, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2APIBalance
        else { return false }
        configurations[keyID, default: .tallyDefault].sub2APIBalance.lastResult = result
        if case .success = result {
            configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulRefreshAt = Date()
            configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulSnapshot = result
        }
        return true
    }

    @discardableResult
    mutating func clearSub2APIBalanceRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].sub2APIBalance.lastResult != nil
        else { return false }
        configurations[keyID, default: .tallyDefault].sub2APIBalance.lastResult = nil
        configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulSnapshot = nil
        return true
    }

    @discardableResult
    mutating func setSub2APIDailyCostUnit(_ unit: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2APIDailyCost
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.unit = unit
        return true
    }

    @discardableResult
    mutating func setSub2APIDailyCostTimezone(
        _ timezone: Sub2APIDailyCostTimezone,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2APIDailyCost,
              configurations[keyID, default: .tallyDefault].sub2APIDailyCost.timezone != timezone
        else { return false }
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.timezone = timezone
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastResult = nil
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulSnapshot = nil
        return true
    }

    @discardableResult
    mutating func setSub2APIDailyCostLastResult(
        _ result: Sub2APIDailyCostResult,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2APIDailyCost
        else { return false }
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastResult = result
        if case .success = result {
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulRefreshAt = Date()
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulSnapshot = result
        }
        return true
    }

    @discardableResult
    mutating func clearSub2APIDailyCostRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastResult != nil
        else { return false }
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastResult = nil
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulSnapshot = nil
        configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulRefreshAt = nil
        return true
    }

    private mutating func clearSub2APIQueryRuntimeState(for keyID: Int) {
        if configurations[keyID, default: .tallyDefault].function == .sub2API {
            configurations[keyID, default: .tallyDefault].sub2API.groupListState = .idle
            configurations[keyID, default: .tallyDefault].sub2API.lastResult = nil
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulRefreshAt = nil
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulSnapshot = nil
        } else if configurations[keyID, default: .tallyDefault].function == .sub2APIBalance {
            configurations[keyID, default: .tallyDefault].sub2APIBalance.lastResult = nil
            configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulRefreshAt = nil
            configurations[keyID, default: .tallyDefault].sub2APIBalance.lastSuccessfulSnapshot = nil
        } else {
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastResult = nil
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulRefreshAt = nil
            configurations[keyID, default: .tallyDefault].sub2APIDailyCost.lastSuccessfulSnapshot = nil
        }
    }

    @discardableResult
    mutating func setSub2APIGroupName(_ groupName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2API.customGroupName =
            groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    @discardableResult
    mutating func setSub2APILastResult(_ result: Sub2APICapacityResult, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].sub2API.lastResult = result
        if case .success = result {
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulRefreshAt = Date()
            configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulSnapshot = result
        }
        return true
    }

    @discardableResult
    mutating func clearSub2APIRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID) else {
            return false
        }

        let currentConfiguration = configurations[keyID, default: .tallyDefault].sub2API
        guard currentConfiguration.lastResult != nil || currentConfiguration.groupListState != .idle else {
            return false
        }

        configurations[keyID, default: .tallyDefault].sub2API.lastResult = nil
        configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].sub2API.lastSuccessfulSnapshot = nil
        configurations[keyID, default: .tallyDefault].sub2API.groupListState = .idle
        return true
    }

    @discardableResult
    mutating func setCodexUsageConfiguration(
        _ configuration: DeckKeyCodexUsageConfiguration,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage = configuration
        return true
    }

    @discardableResult
    mutating func setCodexUsageRefreshIntervalMinutes(_ minutes: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.refreshIntervalMinutes =
            DeckKeyCodexUsageConfiguration.normalizedRefreshIntervalMinutes(minutes)
        return true
    }

    @discardableResult
    mutating func setCodexUsageColorMode(_ colorMode: CodexUsageColorMode, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.colorMode = colorMode
        return true
    }

    @discardableResult
    mutating func setCodexUsageResetDisplayMode(
        _ resetDisplayMode: CodexUsageResetDisplayMode,
        for keyID: Int
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.resetDisplayMode = resetDisplayMode
        return true
    }

    @discardableResult
    mutating func setCodexUsageAuthSource(_ authSource: CodexAuthSource, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.authSource = authSource
        return true
    }

    mutating func setCodexUsageManualAuthData(_ manualAuthData: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.manualAuthData = manualAuthData
        return true
    }

    mutating func setCodexUsageAccountNickname(_ accountNickname: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].codexUsage.accountNickname = accountNickname
        return true
    }

    @discardableResult
    mutating func setCodexUsageLastResult(_ result: CodexUsageResult, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .codexUsage
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].codexUsage.lastResult = result
        if case .success = result {
            configurations[keyID, default: .tallyDefault].codexUsage.lastSuccessfulRefreshAt = Date()
            configurations[keyID, default: .tallyDefault].codexUsage.lastSuccessfulSnapshot = result
        }
        return true
    }

    @discardableResult
    mutating func clearCodexUsageRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].codexUsage.lastResult != nil
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].codexUsage.lastResult = nil
        configurations[keyID, default: .tallyDefault].codexUsage.lastSuccessfulRefreshAt = nil
        configurations[keyID, default: .tallyDefault].codexUsage.lastSuccessfulSnapshot = nil
        return true
    }

    @discardableResult
    mutating func setSub2APIGroupListState(_ state: DeckKeySub2APIGroupListState, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].sub2API.groupListState = state
        return true
    }

    @discardableResult
    mutating func setMihoyoGameLastResult(_ result: MihoyoGameStatusResult, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.game != nil
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].mihoyoGame.lastResult = result
        if case let .success(status) = result {
            configurations[keyID, default: .tallyDefault].mihoyoGame.lastSuccessfulSnapshot = status
            configurations[keyID, default: .tallyDefault].mihoyoGame.lastSuccessfulRefreshAt = Date()
        }
        return true
    }

    @discardableResult
    mutating func clearMihoyoGameRuntimeState(for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].mihoyoGame.lastResult != nil
        else {
            return false
        }

        configurations[keyID, default: .tallyDefault].mihoyoGame.lastResult = nil
        configurations[keyID, default: .tallyDefault].mihoyoGame.lastSuccessfulSnapshot = nil
        configurations[keyID, default: .tallyDefault].mihoyoGame.lastSuccessfulRefreshAt = nil
        return true
    }

    @discardableResult
    mutating func setMihoyoGameRefreshIntervalMinutes(_ minutes: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function.game != nil
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].mihoyoGame.refreshIntervalMinutes =
            DeckKeyMihoyoGameRefreshConfiguration.clamped(minutes)
        return true
    }

    @discardableResult
    mutating func resetTally(keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].displayMode == .function,
              configurations[keyID, default: .tallyDefault].function == .tally
        else {
            return false
        }

        let defaultValue = configurations[keyID, default: .tallyDefault].tally.defaultValue
        configurations[keyID, default: .tallyDefault].tally.value = defaultValue
        return true
    }

    @discardableResult
    mutating func setTallyDefaultValue(_ value: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .tally
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].tally.defaultValue = value
        configurations[keyID, default: .tallyDefault].tally.value = value
        return true
    }

    func buttonVisualConfiguration(for keyID: Int) -> DeckKeyVisualConfiguration? {
        guard validKeyIDs.contains(keyID) else {
            return nil
        }

        return configurations[keyID]?.buttonVisualConfiguration
    }

    @discardableResult
    mutating func setButtonVisualConfiguration(
        _ visual: DeckKeyVisualConfiguration,
        for keyID: Int,
        selectsKey: Bool = true
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              var configuration = configurations[keyID],
              configuration.setButtonVisualConfiguration(visual)
        else {
            return false
        }

        if selectsKey {
            selectedKeyID = keyID
        }
        configurations[keyID] = configuration
        return true
    }

    @discardableResult
    mutating func setButtonVisualName(_ name: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        guard var visual = buttonVisualConfiguration(for: keyID) else {
            return false
        }

        visual.name = DeckKeyVisualConfiguration.normalizedName(name)
        return setButtonVisualConfiguration(visual, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setButtonVisualBlurEnabled(_ enabled: Bool, for keyID: Int, selectsKey: Bool = true) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].buttonVisualCanUseBlurredBackground,
              var visual = buttonVisualConfiguration(for: keyID)
        else {
            return false
        }

        visual.usesBlurredBackground = enabled
        return setButtonVisualConfiguration(visual, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setButtonVisualDimmingEnabled(_ enabled: Bool, for keyID: Int, selectsKey: Bool = true) -> Bool {
        guard var visual = buttonVisualConfiguration(for: keyID) else {
            return false
        }

        visual.dimsBackground = enabled
        return setButtonVisualConfiguration(visual, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setFolderConfiguration(
        _ configuration: DeckKeyOpenFolderConfiguration,
        for keyID: Int,
        selectsKey: Bool = true
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openFolder
        else {
            return false
        }

        if selectsKey {
            selectedKeyID = keyID
            configurations[keyID, default: .tallyDefault].visual = configuration.visual
        }
        configurations[keyID, default: .tallyDefault].openFolder = configuration
        configurations[keyID, default: .tallyDefault].refreshDefaultButtonBackgroundSnapshot()
        return true
    }

    @discardableResult
    mutating func setFolderName(_ name: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        setButtonVisualName(name, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setFolderBackgroundPNGData(_ backgroundPNGData: Data?, for keyID: Int, selectsKey: Bool = true) -> Bool {
        guard var visual = buttonVisualConfiguration(for: keyID) else {
            return false
        }

        visual.backgroundPNGData = backgroundPNGData
        if backgroundPNGData == nil {
            visual.blurredBackgroundPNGData = nil
            visual.usesBlurredBackground = false
        }
        return setButtonVisualConfiguration(visual, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setFileConfiguration(
        _ configuration: DeckKeyOpenFileConfiguration,
        for keyID: Int,
        selectsKey: Bool = true
    ) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openFile
        else {
            return false
        }

        if selectsKey {
            selectedKeyID = keyID
            configurations[keyID, default: .tallyDefault].visual.name = configuration.visual.name
        }
        configurations[keyID, default: .tallyDefault].openFile = configuration
        return true
    }

    @discardableResult
    mutating func setFileName(_ name: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        setButtonVisualName(name, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setFileIconBlurEnabled(_ enabled: Bool, for keyID: Int, selectsKey: Bool = true) -> Bool {
        setButtonVisualBlurEnabled(enabled, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setWebPageURLString(_ urlString: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openWebPage
        else {
            return false
        }

        selectedKeyID = keyID
        let normalizedURLString = DeckKeyOpenWebPageConfiguration.normalizedURLString(urlString)
        if configurations[keyID, default: .tallyDefault].openWebPage.urlString != normalizedURLString {
            configurations[keyID, default: .tallyDefault].openWebPage.title = ""
            configurations[keyID, default: .tallyDefault].openWebPage.iconPNGData = nil
            configurations[keyID, default: .tallyDefault].openWebPage.blurredIconPNGData = nil
        }
        configurations[keyID, default: .tallyDefault].openWebPage.urlString = normalizedURLString
        configurations[keyID, default: .tallyDefault].refreshDefaultButtonBackgroundSnapshot()
        return true
    }

    @discardableResult
    mutating func setWebPageMetadata(_ metadata: WebPageMetadata, for keyID: Int, matchingURLString urlString: String) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openWebPage,
              configurations[keyID, default: .tallyDefault].openWebPage.urlString == DeckKeyOpenWebPageConfiguration.normalizedURLString(urlString)
        else {
            return false
        }

        if let title = metadata.title {
            configurations[keyID, default: .tallyDefault].openWebPage.title = DeckKeyVisualConfiguration.normalizedName(title)
        }
        if let iconSnapshot = metadata.iconSnapshot {
            configurations[keyID, default: .tallyDefault].openWebPage.iconPNGData = iconSnapshot.iconPNGData
            configurations[keyID, default: .tallyDefault].openWebPage.blurredIconPNGData = iconSnapshot.blurredIconPNGData
            configurations[keyID, default: .tallyDefault].openWebPage.usesBlurredIcon = false
        }
        return true
    }

    @discardableResult
    mutating func setWebPageTitle(_ title: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        setButtonVisualName(title, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func setSMBServerAddress(_ address: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .connectSMBServer,
              let validatedAddress = DeckKeySMBServerConfiguration.validatedAddress(address)
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].smbServer.address = validatedAddress
        return true
    }

    @discardableResult
    mutating func setSMBServerName(_ name: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        setButtonVisualName(name, for: keyID, selectsKey: selectsKey)
    }

    @discardableResult
    mutating func assign(_ function: DeckKeyFunction, to keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              DeckKeyFunction.assignableCases.contains(function),
              configurations[keyID, default: .tallyDefault].function != .pageBack
        else {
            return false
        }

        if function == .pageFolder {
            guard canAssignPageFolder(to: keyID) else {
                return false
            }

            removeChildPageIfNeeded(for: keyID)
            let childPageID = makeChildPageID()
            pages[childPageID] = DeckGridPage(
                id: childPageID,
                parentID: currentPageID,
                configurations: Self.childPageConfigurations(
                    for: layout,
                    inheritingDisplayModesFrom: configurations
                )
            )
            selectedKeyID = keyID
            configurations[keyID] = Self.defaultConfiguration(for: .pageFolder, pageID: childPageID)
            return true
        }

        removeChildPageIfNeeded(for: keyID)
        let previousFunction = configurations[keyID, default: .tallyDefault].function
        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].clearDefaultButtonBackgroundSnapshot(for: previousFunction)
        configurations[keyID, default: .tallyDefault].function = function
        if function.isSub2APIQuery {
            ensureUniqueSub2APIInstanceID(for: keyID)
        }
        configurations[keyID, default: .tallyDefault].refreshDefaultButtonBackgroundSnapshot()
        if function == .newAPIModelAvailability {
            ensureUniqueNewAPIInstanceID(for: keyID)
        }
        normalizeSub2APIDataSources()
        return true
    }

    @discardableResult
    mutating func setDisplayMode(_ displayMode: DeckKeyDisplayMode, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              wideKeyIDs.contains(keyID)
        else {
            return false
        }

        selectedKeyID = keyID
        pressedKeyIDs.remove(keyID)
        configurations[keyID, default: .tallyDefault].displayMode = displayMode
        return true
    }

    @discardableResult
    mutating func clearFunction(keyID: Int) -> Bool {
        guard canDeleteFunction(keyID: keyID) else {
            return false
        }

        selectedKeyID = keyID
        removeChildPageIfNeeded(for: keyID)
        pressedKeyIDs.remove(keyID)
        configurations[keyID] = .empty
        normalizeSub2APIDataSources()
        return true
    }

    func configuration(for keyID: Int) -> DeckKeyConfiguration? {
        configurations[keyID]
    }

    func tallyValue(for keyID: Int) -> Int {
        configurations[keyID, default: .tallyDefault].tally.value
    }

    func tallyDefaultValue(for keyID: Int) -> Int {
        configurations[keyID, default: .tallyDefault].tally.defaultValue
    }

    func isPressed(keyID: Int) -> Bool {
        pressedKeyIDs.contains(keyID)
    }

    private func activeSub2APIDataSourceConfigurationsByInstanceID() -> [String: Sub2APIDataSourceConfiguration] {
        var configurationsByInstanceID: [String: Sub2APIDataSourceConfiguration] = [:]
        for page in pages.values {
            for configuration in page.configurations.values where configuration.function.isSub2APIQuery {
                let dataSource = configuration.sub2APIDataSourceConfiguration
                configurationsByInstanceID[dataSource.instanceID] = dataSource
            }
        }
        return configurationsByInstanceID
    }

    private func sub2APIReferenceOptions(
        for currentInstanceID: String
    ) -> [DeckKeySub2APIReferenceOption] {
        let configurationsByInstanceID = activeSub2APIDataSourceConfigurationsByInstanceID()
        guard !configurationsByInstanceID.values.contains(where: {
            $0.dataSourceInstanceID == currentInstanceID
        }) else {
            return []
        }

        return configurationsByInstanceID
            .filter { instanceID, configuration in
                instanceID != currentInstanceID
                    && configuration.dataSourceInstanceID == nil
            }
            .map { instanceID, configuration in
                DeckKeySub2APIReferenceOption(
                    instanceID: instanceID,
                    title: referenceTitle(for: instanceID, fallback: configuration)
                )
            }
            .sorted { first, second in
                let comparison = first.title.localizedStandardCompare(second.title)
                return comparison == .orderedSame
                    ? first.instanceID < second.instanceID
                    : comparison == .orderedAscending
            }
    }

    private func referenceTitle(
        for instanceID: String,
        fallback: Sub2APIDataSourceConfiguration
    ) -> String {
        for page in pages.values {
            if let configuration = page.configurations.values.first(where: {
                $0.function.isSub2APIQuery
                    && $0.sub2APIDataSourceConfiguration.instanceID == instanceID
            }) {
                if configuration.function == .sub2API {
                    return "\(configuration.sub2API.serviceDisplayName) (\(configuration.sub2API.displayName))"
                }
                if configuration.function == .sub2APIBalance {
                    return "\(configuration.sub2APIBalance.serviceDisplayName) (余额)"
                }
                return "\(configuration.sub2APIDailyCost.serviceDisplayName) (今日消费)"
            }
        }
        return instanceID.isEmpty ? fallback.baseURL : instanceID
    }

    private mutating func normalizeSub2APIInstanceIDs() {
        var seenInstanceIDs: Set<String> = []
        for pageID in pages.keys.sorted() {
            guard var page = pages[pageID] else {
                continue
            }
            for keyID in page.configurations.keys.sorted() {
                guard var configuration = page.configurations[keyID],
                      configuration.function.isSub2APIQuery
                else {
                    continue
                }

                let instanceID = configuration.sub2APIDataSourceConfiguration.instanceID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if instanceID.isEmpty || !seenInstanceIDs.insert(instanceID).inserted {
                    var dataSource = configuration.sub2APIDataSourceConfiguration
                    dataSource.instanceID = UUID().uuidString
                    configuration.sub2APIDataSourceConfiguration = dataSource
                    seenInstanceIDs.insert(dataSource.instanceID)
                } else {
                    var dataSource = configuration.sub2APIDataSourceConfiguration
                    dataSource.instanceID = instanceID
                    configuration.sub2APIDataSourceConfiguration = dataSource
                }
                page.configurations[keyID] = configuration
            }
            pages[pageID] = page
        }
        normalizeSub2APIDataSources()
    }

    private mutating func normalizeSub2APIDataSources() {
        let configurationsByInstanceID = activeSub2APIDataSourceConfigurationsByInstanceID()
        let invalidInstanceIDs = Sub2APIDataSourceGraph.invalidReferenceInstanceIDs(
            in: configurationsByInstanceID
        )
        guard !invalidInstanceIDs.isEmpty else { return }

        for pageID in pages.keys.sorted() {
            guard var page = pages[pageID] else { continue }
            for keyID in page.configurations.keys.sorted() {
                guard var configuration = page.configurations[keyID],
                      configuration.function.isSub2APIQuery,
                      invalidInstanceIDs.contains(
                        configuration.sub2APIDataSourceConfiguration.instanceID
                      ),
                      configuration.sub2APIDataSourceConfiguration.dataSourceInstanceID != nil
                else { continue }

                var dataSource = configuration.sub2APIDataSourceConfiguration
                dataSource.dataSourceInstanceID = nil
                dataSource.baseURL = ""
                dataSource.bearerKey = ""
                dataSource.credentialID = nil
                configuration.sub2APIDataSourceConfiguration = dataSource
                if configuration.function == .sub2API {
                    configuration.sub2API.lastResult = nil
                    configuration.sub2API.lastSuccessfulRefreshAt = nil
                    configuration.sub2API.lastSuccessfulSnapshot = nil
                    configuration.sub2API.groupListState = .idle
                } else if configuration.function == .sub2APIBalance {
                    configuration.sub2APIBalance.lastResult = nil
                    configuration.sub2APIBalance.lastSuccessfulRefreshAt = nil
                    configuration.sub2APIBalance.lastSuccessfulSnapshot = nil
                } else {
                    configuration.sub2APIDailyCost.lastResult = nil
                    configuration.sub2APIDailyCost.lastSuccessfulRefreshAt = nil
                    configuration.sub2APIDailyCost.lastSuccessfulSnapshot = nil
                }
                page.configurations[keyID] = configuration
            }
            pages[pageID] = page
        }
    }

    private mutating func ensureUniqueSub2APIInstanceID(for keyID: Int) {
        let existingInstanceIDs = Set(
            pages.flatMap { pageID, page in
                page.configurations.compactMap { candidateKeyID, configuration -> String? in
                    guard configuration.function.isSub2APIQuery,
                          pageID != currentPageID || candidateKeyID != keyID
                    else {
                        return nil
                    }
                    return configuration.sub2APIDataSourceConfiguration.instanceID
                }
            }
        )
        let instanceID = configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration.instanceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if instanceID.isEmpty || existingInstanceIDs.contains(instanceID) {
            var dataSource = configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration
            dataSource.instanceID = UUID().uuidString
            configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        } else {
            var dataSource = configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration
            dataSource.instanceID = instanceID
            configurations[keyID, default: .tallyDefault].sub2APIDataSourceConfiguration = dataSource
        }
    }

    private mutating func ensureUniqueNewAPIInstanceID(for keyID: Int) {
        let existingInstanceIDs = Set(
            pages.flatMap { pageID, page in
                page.configurations.compactMap { candidateKeyID, configuration -> String? in
                    guard configuration.function == .newAPIModelAvailability,
                          pageID != currentPageID || candidateKeyID != keyID else { return nil }
                    return configuration.newAPIModelAvailability.instanceID
                }
            }
        )
        var configuration = configurations[keyID, default: .tallyDefault].newAPIModelAvailability
        let instanceID = configuration.instanceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if instanceID.isEmpty || existingInstanceIDs.contains(instanceID) {
            configuration.instanceID = UUID().uuidString
            configurations[keyID, default: .tallyDefault].newAPIModelAvailability = configuration
        }
    }

    private func firstSelectableKeyID() -> Int? {
        layout.keys.first?.id
    }

    private func navigationPathPageIDs() -> [String] {
        var path: [String] = []
        var nextPageID: String? = currentPageID
        var visitedPageIDs: Set<String> = []

        while let pageID = nextPageID,
              !visitedPageIDs.contains(pageID) {
            visitedPageIDs.insert(pageID)
            path.append(pageID)

            if rootPageIDs.contains(pageID) {
                break
            }

            nextPageID = pages[pageID]?.parentID
        }

        if let last = path.last, !rootPageIDs.contains(last) {
            path.append(currentRootPageID)
        }

        return path.reversed()
    }

    private func pageDepth(pageID: String) -> Int {
        if rootPageIDs.contains(pageID) {
            return 0
        }

        var depth = 0
        var nextPageID = pages[pageID]?.parentID
        var visitedPageIDs: Set<String> = [pageID]

        while let pageID = nextPageID,
              !rootPageIDs.contains(pageID),
              !visitedPageIDs.contains(pageID) {
            visitedPageIDs.insert(pageID)
            depth += 1
            nextPageID = pages[pageID]?.parentID
        }

        if let nextPageID, rootPageIDs.contains(nextPageID) {
            return depth + 1
        }

        return depth
    }

    private func rootPageID(containing pageID: String) -> String? {
        if rootPageIDs.contains(pageID) {
            return pageID
        }

        var nextPageID = pages[pageID]?.parentID
        var visitedPageIDs: Set<String> = [pageID]
        while let pageID = nextPageID,
              !visitedPageIDs.contains(pageID) {
            if rootPageIDs.contains(pageID) {
                return pageID
            }

            visitedPageIDs.insert(pageID)
            nextPageID = pages[pageID]?.parentID
        }

        return nil
    }

    private func makeRootPageID() -> String {
        var index = 2
        while true {
            let pageID = "root-\(index)"
            if pages[pageID] == nil && !rootPageIDs.contains(pageID) {
                return pageID
            }
            index += 1
        }
    }

    private func makeChildPageID() -> String {
        var pageID: String
        repeat {
            pageID = "page-\(UUID().uuidString)"
        } while pages[pageID] != nil

        return pageID
    }

    private static func defaultConfiguration(for function: DeckKeyFunction, pageID: String? = nil) -> DeckKeyConfiguration {
        var configuration = DeckKeyConfiguration(function: function)
        if function == .pageFolder {
            configuration.pageFolder = DeckKeyPageFolderConfiguration(pageID: pageID)
        }
        configuration.refreshDefaultButtonBackgroundSnapshot()
        return configuration
    }

    private mutating func removeChildPageIfNeeded(for keyID: Int) {
        guard let pageID = pageID(for: keyID) else {
            return
        }

        removePageSubtree(pageID)
    }

    private mutating func removePageSubtree(_ pageID: String) {
        let childPageIDs = pages.values
            .filter { $0.parentID == pageID }
            .map(\.id)
        for childPageID in childPageIDs {
            removePageSubtree(childPageID)
        }
        pages[pageID] = nil
    }

    func display(for key: DeckGridLayout.Key) -> DeckKeyDisplay {
        DeckKeyDisplay(
            key: key,
            configuration: configurations[key.id, default: .tallyDefault],
            isSelected: selectedKeyID == key.id,
            isPressed: isPressed(keyID: key.id)
        )
    }

    func displays(for layout: DeckGridLayout) -> [DeckKeyDisplay] {
        layout.keys.map { key in
            display(for: key)
        }
    }
}
