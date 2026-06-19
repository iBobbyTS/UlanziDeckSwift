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
    let smbServerButtonContent: SMBServerButtonContent?
    let buttonBackgroundDimmingEnabled: Bool
    let isSelected: Bool
    let isPressed: Bool

    init(
        key: DeckGridLayout.Key,
        configuration: DeckKeyConfiguration,
        buttonBackgroundDimmingEnabled: Bool = true,
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
        var smbServerButtonContent: SMBServerButtonContent?

        if key.columnSpan > 1 && configuration.displayMode != .function {
            title = configuration.displayMode.previewTitle
            subtitle = configuration.displayMode.previewSubtitle
            mihoyoGame = nil
        } else {
            mihoyoGame = configuredMihoyoGame
            switch configuration.function {
            case .none:
                title = ""
                subtitle = ""
            case .tally:
                title = "\(configuration.tally.value)"
                subtitle = "默认 \(configuration.tally.defaultValue)"
            case .openFolder:
                let content = FolderButtonContent(displayName: configuration.openFolder.displayName)
                title = content.displayName
                subtitle = configuration.openFolder.path ?? ""
                folderButtonContent = content
            case .connectSMBServer:
                let content = SMBServerButtonContent(displayName: configuration.smbServer.displayName)
                title = content.displayName
                subtitle = configuration.smbServer.address
                smbServerButtonContent = content
            case .brightness:
                title = ""
                subtitle = ""
            case .sub2API:
                if case let .success(item) = configuration.sub2API.lastResult {
                    let content = Sub2APIButtonContent(
                        serviceName: configuration.sub2API.serviceDisplayName,
                        groupName: configuration.sub2API.displayName,
                        availableConcurrency: item.availableConcurrency
                    )
                    title = content.availableConcurrencyText
                    subtitle = "\(content.serviceName) \(content.groupName)"
                    sub2APIButtonContent = content
                } else if case .invalidToken = configuration.sub2API.lastResult {
                    title = "令牌"
                    subtitle = "无效"
                } else if case .tokenExpired = configuration.sub2API.lastResult {
                    title = "令牌"
                    subtitle = "已过期"
                } else if case .notFound = configuration.sub2API.lastResult {
                    title = "未找到"
                    subtitle = "分组 \(configuration.sub2API.targetGroupID)"
                } else if case .networkError = configuration.sub2API.lastResult {
                    title = "网络"
                    subtitle = "错误"
                } else {
                    title = "号池"
                    subtitle = "未配置"
                }
            case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
                if case let .success(status) = configuration.mihoyoGame.lastResult {
                    title = status.buttonTitle
                    subtitle = status.buttonSubtitle
                    mihoyoGameButtonContent = status.buttonContent
                } else if case .loginRequired = configuration.mihoyoGame.lastResult {
                    title = configuration.function.game?.shortDisplayName ?? "游戏"
                    subtitle = "未登录"
                } else if case .loginExpired = configuration.mihoyoGame.lastResult {
                    title = configuration.function.game?.shortDisplayName ?? "游戏"
                    subtitle = "需重登"
                } else if case .noBoundRole = configuration.mihoyoGame.lastResult {
                    title = configuration.function.game?.shortDisplayName ?? "游戏"
                    subtitle = "无角色"
                } else if case .networkError = configuration.mihoyoGame.lastResult {
                    title = configuration.function.game?.shortDisplayName ?? "游戏"
                    subtitle = "查询失败"
                } else {
                    title = configuration.function.game?.shortDisplayName ?? "游戏"
                    subtitle = "未查询"
                }
            }
        }
        self.mihoyoGameButtonContent = mihoyoGameButtonContent
        self.sub2APIButtonContent = sub2APIButtonContent
        self.folderButtonContent = folderButtonContent
        self.smbServerButtonContent = smbServerButtonContent
        self.buttonBackgroundDimmingEnabled = buttonBackgroundDimmingEnabled
        self.isSelected = isSelected
        self.isPressed = isPressed
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
            smbServerButtonContent: smbServerButtonContent,
            buttonBackgroundDimmingEnabled: buttonBackgroundDimmingEnabled,
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
    let smbServerButtonContent: SMBServerButtonContent?
    let buttonBackgroundDimmingEnabled: Bool
    let devicePixelSize: H200DeviceTarget.PixelSize
}

nonisolated struct FolderButtonContent: Equatable {
    static let backgroundAssetName = "FolderBackground"

    let displayName: String
}

nonisolated struct SMBServerButtonContent: Equatable {
    static let backgroundAssetName = "SMBServerBackground"

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

nonisolated struct DeckGridInteractionState: Equatable {
    private(set) var selectedKeyID: Int?
    private(set) var configurations: [Int: DeckKeyConfiguration]
    private(set) var pressedKeyIDs: Set<Int>
    private let validKeyIDs: Set<Int>
    private let wideKeyIDs: Set<Int>

    init(layout: DeckGridLayout) {
        selectedKeyID = layout.keys.first?.id
        configurations = Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
        pressedKeyIDs = []
        validKeyIDs = Set(layout.keys.map(\.id))
        wideKeyIDs = Set(layout.keys.filter { $0.columnSpan > 1 }.map(\.id))
    }

    init(layout: DeckGridLayout, configurations storedConfigurations: [Int: DeckKeyConfiguration]) {
        let validKeyIDs = Set(layout.keys.map(\.id))
        let wideKeyIDs = Set(layout.keys.filter { $0.columnSpan > 1 }.map(\.id))

        selectedKeyID = layout.keys.first?.id
        configurations = Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
        pressedKeyIDs = []
        self.validKeyIDs = validKeyIDs
        self.wideKeyIDs = wideKeyIDs

        for keyID in validKeyIDs {
            if let configuration = storedConfigurations[keyID] {
                configurations[keyID] = Self.normalized(configuration, isWide: wideKeyIDs.contains(keyID))
            }
        }
    }

    private static func normalized(_ configuration: DeckKeyConfiguration, isWide: Bool) -> DeckKeyConfiguration {
        var normalizedConfiguration = configuration
        if normalizedConfiguration.function == .brightness {
            normalizedConfiguration = .empty
        }

        if !isWide {
            normalizedConfiguration.displayMode = .function
        }

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
              DeckKeyFunction.assignableCases.contains(configurations[keyID, default: .tallyDefault].function),
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
        }
        configurations[keyID, default: .tallyDefault].openFolder = configuration
        return true
    }

    @discardableResult
    mutating func setFolderName(_ name: String, for keyID: Int, selectsKey: Bool = true) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openFolder
        else {
            return false
        }

        if selectsKey {
            selectedKeyID = keyID
        }
        configurations[keyID, default: .tallyDefault].openFolder.name =
            DeckKeyOpenFolderConfiguration.normalizedName(name)
        return true
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
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .connectSMBServer
        else {
            return false
        }

        if selectsKey {
            selectedKeyID = keyID
        }
        configurations[keyID, default: .tallyDefault].smbServer.name = DeckKeySMBServerConfiguration.normalizedName(name)
        return true
    }

    @discardableResult
    mutating func assign(_ function: DeckKeyFunction, to keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              DeckKeyFunction.assignableCases.contains(function)
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].displayMode = .function
        configurations[keyID, default: .tallyDefault].function = function
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
        guard validKeyIDs.contains(keyID) else {
            return false
        }

        selectedKeyID = keyID
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

    func display(for key: DeckGridLayout.Key, buttonBackgroundDimmingEnabled: Bool = true) -> DeckKeyDisplay {
        DeckKeyDisplay(
            key: key,
            configuration: configurations[key.id, default: .tallyDefault],
            buttonBackgroundDimmingEnabled: buttonBackgroundDimmingEnabled,
            isSelected: selectedKeyID == key.id,
            isPressed: isPressed(keyID: key.id)
        )
    }

    func displays(for layout: DeckGridLayout, buttonBackgroundDimmingEnabled: Bool = true) -> [DeckKeyDisplay] {
        layout.keys.map { key in
            display(for: key, buttonBackgroundDimmingEnabled: buttonBackgroundDimmingEnabled)
        }
    }
}
