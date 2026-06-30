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
    let sub2APIButtonContent: Sub2APIButtonContent?
    let folderButtonContent: FolderButtonContent?
    let fileButtonContent: FileButtonContent?
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
        var sub2APIButtonContent: Sub2APIButtonContent?
        var folderButtonContent: FolderButtonContent?
        var fileButtonContent: FileButtonContent?
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
                let content = PageBackButtonContent(displayName: configuration.visual.displayName(fallback: "返回"))
                title = content.displayName
                subtitle = "上一级"
                pageBackButtonContent = content
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
        self.sub2APIButtonContent = sub2APIButtonContent
        self.folderButtonContent = folderButtonContent
        self.fileButtonContent = fileButtonContent
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
            sub2APIButtonContent: sub2APIButtonContent,
            folderButtonContent: folderButtonContent,
            fileButtonContent: fileButtonContent,
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
    let sub2APIButtonContent: Sub2APIButtonContent?
    let folderButtonContent: FolderButtonContent?
    let fileButtonContent: FileButtonContent?
    let smbServerButtonContent: SMBServerButtonContent?
    let pageFolderButtonContent: PageFolderButtonContent?
    let pageBackButtonContent: PageBackButtonContent?
    let buttonVisualContent: ButtonVisualContent
    let devicePixelSize: H200DeviceTarget.PixelSize
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

nonisolated struct DeckGridInteractionState: Equatable {
    static let rootPageID = "root"
    static let maximumNestedPageDepth = 3

    private(set) var selectedKeyID: Int?
    private(set) var currentPageID: String
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
            if first.id == Self.rootPageID {
                return true
            }
            if second.id == Self.rootPageID {
                return false
            }
            return first.id < second.id
        }
    }

    var currentPageDepth: Int {
        pageDepth(pageID: currentPageID)
    }

    var navigationPathTitles: [String] {
        navigationPathPageIDs().map { pageID in
            pageID == Self.rootPageID ? "主页" : DeckKeyPageFolderConfiguration.defaultDisplayName
        }
    }

    init(layout: DeckGridLayout) {
        selectedKeyID = layout.keys.first?.id
        currentPageID = Self.rootPageID
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
        let validKeyIDs = Set(layout.keys.map(\.id))
        let wideKeyIDs = Set(layout.keys.filter { $0.columnSpan > 1 }.map(\.id))
        self.layout = layout
        self.validKeyIDs = validKeyIDs
        self.wideKeyIDs = wideKeyIDs
        selectedKeyID = layout.keys.first?.id
        currentPageID = Self.rootPageID
        pressedKeyIDs = []

        var normalizedPages: [String: DeckGridPage] = [:]
        for page in storedPages where !page.id.isEmpty {
            let isRootPage = page.id == Self.rootPageID
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

        if normalizedPages[Self.rootPageID] == nil {
            normalizedPages[Self.rootPageID] = DeckGridPage(
                id: Self.rootPageID,
                parentID: nil,
                configurations: Self.rootConfigurations(for: layout)
            )
        }
        for pageID in Array(normalizedPages.keys) where pageID != Self.rootPageID {
            let configurations = normalizedPages[pageID]?.configurations ?? [:]
            normalizedPages[pageID]?.configurations = Self.ensureBackKey(
                in: configurations,
                layout: layout
            )
        }
        pages = normalizedPages
    }

    private static func rootConfigurations(for layout: DeckGridLayout) -> [Int: DeckKeyConfiguration] {
        Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
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

        guard let key = layout.keys.first(where: { $0.columnSpan == 1 }) else {
            return configurations
        }

        var updatedConfigurations = configurations
        updatedConfigurations[key.id] = .pageBack
        return updatedConfigurations
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

    func smbServerAddress(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].smbServer.address
    }

    func smbServerName(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].smbServer.name
    }

    func sub2APIConfiguration(for keyID: Int) -> DeckKeySub2APIConfiguration {
        configurations[keyID, default: .tallyDefault].sub2API
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
        guard currentPageID != Self.rootPageID else {
            return false
        }

        currentPageID = Self.rootPageID
        selectedKeyID = firstSelectableKeyID()
        pressedKeyIDs.removeAll()
        return true
    }

    @discardableResult
    mutating func setSub2APIBaseURL(_ baseURL: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if configurations[keyID, default: .tallyDefault].sub2API.baseURL != normalizedBaseURL {
            configurations[keyID, default: .tallyDefault].sub2API.groupListState = .idle
            configurations[keyID, default: .tallyDefault].sub2API.lastResult = nil
        }
        configurations[keyID, default: .tallyDefault].sub2API.baseURL = normalizedBaseURL
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
        }
        configurations[keyID, default: .tallyDefault].sub2API.targetGroupID = groupID
        return true
    }

    @discardableResult
    mutating func setSub2APIRefreshInterval(_ interval: Int, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2API.refreshInterval = max(5, interval)
        return true
    }

    @discardableResult
    mutating func setSub2APIBearerKey(_ bearerKey: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        if configurations[keyID, default: .tallyDefault].sub2API.bearerKey != bearerKey {
            configurations[keyID, default: .tallyDefault].sub2API.groupListState = .idle
            configurations[keyID, default: .tallyDefault].sub2API.lastResult = nil
        }
        configurations[keyID, default: .tallyDefault].sub2API.bearerKey = bearerKey
        return true
    }

    @discardableResult
    mutating func setSub2APIServiceName(_ serviceName: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2API.customServiceName =
            serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
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
        configurations[keyID, default: .tallyDefault].sub2API.groupListState = .idle
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
    mutating func setSMBServerAddress(_ address: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .connectSMBServer
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].smbServer.address = DeckKeySMBServerConfiguration.normalizedAddress(address)
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
        configurations[keyID, default: .tallyDefault].displayMode = .function
        configurations[keyID, default: .tallyDefault].function = function
        configurations[keyID, default: .tallyDefault].refreshDefaultButtonBackgroundSnapshot()
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
        if displayMode != .function {
            configurations[keyID] = .empty
        }
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

            if pageID == Self.rootPageID {
                break
            }

            nextPageID = pages[pageID]?.parentID
        }

        if path.last != Self.rootPageID {
            path.append(Self.rootPageID)
        }

        return path.reversed()
    }

    private func pageDepth(pageID: String) -> Int {
        var depth = 0
        var nextPageID = pages[pageID]?.parentID
        var visitedPageIDs: Set<String> = [pageID]

        while let pageID = nextPageID,
              pageID != Self.rootPageID,
              !visitedPageIDs.contains(pageID) {
            visitedPageIDs.insert(pageID)
            depth += 1
            nextPageID = pages[pageID]?.parentID
        }

        return nextPageID == Self.rootPageID ? depth + 1 : depth
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
