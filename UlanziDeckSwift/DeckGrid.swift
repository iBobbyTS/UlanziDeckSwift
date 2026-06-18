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
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isPressed: Bool

    init(key: DeckGridLayout.Key, configuration: DeckKeyConfiguration, isSelected: Bool, isPressed: Bool) {
        id = key.id
        row = key.row
        column = key.column
        columnSpan = key.columnSpan
        switch configuration.function {
        case .none:
            title = ""
            subtitle = ""
        case .tally:
            title = "\(configuration.tally.value)"
            subtitle = "默认 \(configuration.tally.defaultValue)"
        case .openFolder:
            title = "打开"
            subtitle = configuration.openFolder.displayName
        case .connectSMBServer:
            title = "连接"
            subtitle = configuration.smbServer.displayName
        case .brightness:
            title = ""
            subtitle = ""
        case .sub2API:
            if case let .success(item) = configuration.sub2API.lastResult {
                title = item.groupName
                subtitle = "可用 \(item.availableConcurrency)"
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
                subtitle = configuration.sub2API.displayName
            }
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            if case let .success(status) = configuration.mihoyoGame.lastResult {
                title = status.buttonTitle
                subtitle = status.buttonSubtitle
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
            title: title,
            subtitle: subtitle,
            devicePixelSize: devicePixelSize
        )
    }
}

nonisolated struct DeckKeyRenderIdentity: Equatable {
    let id: Int
    let row: Int
    let column: Int
    let columnSpan: Int
    let title: String
    let subtitle: String
    let devicePixelSize: H200DeviceTarget.PixelSize
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

nonisolated enum DeckKeyFunction: String, Codable, Equatable, CaseIterable {
    case none
    case tally
    case openFolder
    case connectSMBServer
    case brightness
    case sub2API
    case genshinStatus
    case starRailStatus
    case zenlessZoneStatus

    static let assignableCases: [DeckKeyFunction] = [
        .tally,
        .openFolder,
        .connectSMBServer,
        .sub2API,
        .genshinStatus,
        .starRailStatus,
        .zenlessZoneStatus,
    ]

    var title: String {
        switch self {
        case .none:
            return "无功能"
        case .tally:
            return "计数器"
        case .openFolder:
            return "打开文件夹"
        case .connectSMBServer:
            return "连接 SMB"
        case .brightness:
            return "亮度调节"
        case .sub2API:
            return "Sub2API 号池查询"
        case .genshinStatus:
            return "原神状态"
        case .starRailStatus:
            return "星铁状态"
        case .zenlessZoneStatus:
            return "绝区零状态"
        }
    }

    var systemImageName: String {
        switch self {
        case .none:
            return "minus.circle"
        case .tally:
            return "number.square"
        case .openFolder:
            return "folder"
        case .connectSMBServer:
            return "network"
        case .brightness:
            return "sun.max"
        case .sub2API:
            return "globe"
        case .genshinStatus:
            return "sparkles"
        case .starRailStatus:
            return "tram"
        case .zenlessZoneStatus:
            return "bolt"
        }
    }

    var game: MihoyoGame? {
        switch self {
        case .genshinStatus:
            return .genshin
        case .starRailStatus:
            return .starRail
        case .zenlessZoneStatus:
            return .zenlessZoneZero
        case .none, .tally, .openFolder, .connectSMBServer, .brightness, .sub2API:
            return nil
        }
    }
}

nonisolated struct DeckKeyTallyConfiguration: Codable, Equatable {
    var defaultValue: Int
    var value: Int

    init(defaultValue: Int = 0, value: Int? = nil) {
        self.defaultValue = defaultValue
        self.value = value ?? defaultValue
    }
}

nonisolated struct DeckKeyOpenFolderConfiguration: Codable, Equatable {
    var path: String?

    init(path: String? = nil) {
        self.path = path
    }

    var displayName: String {
        guard let path, !path.isEmpty else {
            return "选择文件夹"
        }

        let name = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
        return name.isEmpty ? path : name
    }
}

nonisolated struct DeckKeySMBServerConfiguration: Codable, Equatable {
    var address: String

    init(address: String = "") {
        self.address = Self.normalizedAddress(address)
    }

    var displayName: String {
        address.isEmpty ? "填写地址" : address
    }

    var fullURLString: String? {
        guard !address.isEmpty else {
            return nil
        }

        return "smb://\(address)"
    }

    static func normalizedAddress(_ rawValue: String) -> String {
        var address = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        while address.range(of: "smb://", options: [.caseInsensitive, .anchored]) != nil {
            address.removeFirst("smb://".count)
            address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        while address.hasPrefix("/") {
            address.removeFirst()
        }

        return address
    }
}

nonisolated struct DeckKeySub2APIConfiguration: Codable, Equatable {
    var baseURL: String
    var targetGroupID: Int
    var refreshInterval: Int
    var bearerKey: String

    /// 最近一次成功查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: Sub2APICapacityResult?

    init(
        baseURL: String = "",
        targetGroupID: Int = 0,
        refreshInterval: Int = 30,
        bearerKey: String = "",
        lastResult: Sub2APICapacityResult? = nil
    ) {
        self.baseURL = baseURL
        self.targetGroupID = targetGroupID
        self.refreshInterval = refreshInterval
        self.bearerKey = bearerKey
        self.lastResult = lastResult
    }

    var displayName: String {
        targetGroupID == 0 ? "未配置" : "分组 \(targetGroupID)"
    }

    enum CodingKeys: CodingKey {
        case baseURL
        case targetGroupID
        case refreshInterval
        case bearerKey
    }
}

nonisolated enum DeckBrightnessConfiguration {
    static let defaultPercent = 100

    nonisolated static func clamped(_ percent: Int) -> Int {
        min(100, max(0, percent))
    }
}

nonisolated struct DeckKeyMihoyoGameConfiguration: Codable, Equatable {
    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: MihoyoGameStatusResult?

    init(lastResult: MihoyoGameStatusResult? = nil) {
        self.lastResult = lastResult
    }

    enum CodingKeys: CodingKey {}

    init(from decoder: Decoder) throws {
        lastResult = nil
    }

    func encode(to encoder: Encoder) throws {}
}

nonisolated struct DeckKeyConfiguration: Codable, Equatable {
    var function: DeckKeyFunction
    var tally: DeckKeyTallyConfiguration
    var openFolder: DeckKeyOpenFolderConfiguration
    var smbServer: DeckKeySMBServerConfiguration
    var sub2API: DeckKeySub2APIConfiguration
    var mihoyoGame: DeckKeyMihoyoGameConfiguration

    static let empty = DeckKeyConfiguration(
        function: .none,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration()
    )

    static let tallyDefault = DeckKeyConfiguration(
        function: .tally,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration()
    )

    init(
        function: DeckKeyFunction,
        tally: DeckKeyTallyConfiguration = DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration = DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration = DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration = DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration = DeckKeyMihoyoGameConfiguration()
    ) {
        self.function = function
        self.tally = tally
        self.openFolder = openFolder
        self.smbServer = smbServer
        self.sub2API = sub2API
        self.mihoyoGame = mihoyoGame
    }

    enum CodingKeys: CodingKey {
        case function
        case tally
        case openFolder
        case smbServer
        case sub2API
        case mihoyoGame
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decode(DeckKeyFunction.self, forKey: .function)
        tally = try container.decodeIfPresent(DeckKeyTallyConfiguration.self, forKey: .tally) ?? DeckKeyTallyConfiguration()
        openFolder = try container.decodeIfPresent(DeckKeyOpenFolderConfiguration.self, forKey: .openFolder) ?? DeckKeyOpenFolderConfiguration()
        smbServer = try container.decodeIfPresent(DeckKeySMBServerConfiguration.self, forKey: .smbServer) ?? DeckKeySMBServerConfiguration()
        sub2API = try container.decodeIfPresent(DeckKeySub2APIConfiguration.self, forKey: .sub2API) ?? DeckKeySub2APIConfiguration()
        mihoyoGame = try container.decodeIfPresent(DeckKeyMihoyoGameConfiguration.self, forKey: .mihoyoGame) ?? DeckKeyMihoyoGameConfiguration()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(function, forKey: .function)
        try container.encode(tally, forKey: .tally)
        try container.encode(openFolder, forKey: .openFolder)
        try container.encode(smbServer, forKey: .smbServer)
        try container.encode(sub2API, forKey: .sub2API)
        try container.encode(mihoyoGame, forKey: .mihoyoGame)
    }
}

nonisolated struct DeckGridInteractionState: Equatable {
    private(set) var selectedKeyID: Int?
    private(set) var configurations: [Int: DeckKeyConfiguration]
    private(set) var pressedKeyIDs: Set<Int>
    private let validKeyIDs: Set<Int>

    init(layout: DeckGridLayout) {
        selectedKeyID = layout.keys.first?.id
        configurations = Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
        pressedKeyIDs = []
        validKeyIDs = Set(layout.keys.map(\.id))
    }

    init(layout: DeckGridLayout, configurations storedConfigurations: [Int: DeckKeyConfiguration]) {
        let validKeyIDs = Set(layout.keys.map(\.id))

        selectedKeyID = layout.keys.first?.id
        configurations = Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, .tallyDefault) })
        pressedKeyIDs = []
        self.validKeyIDs = validKeyIDs

        for keyID in validKeyIDs {
            if let configuration = storedConfigurations[keyID] {
                configurations[keyID] = Self.normalized(configuration)
            }
        }
    }

    private static func normalized(_ configuration: DeckKeyConfiguration) -> DeckKeyConfiguration {
        guard configuration.function == .brightness else {
            return configuration
        }

        return .empty
    }

    mutating func select(keyID: Int) {
        guard validKeyIDs.contains(keyID) else {
            return
        }

        selectedKeyID = keyID
    }

    mutating func beginPress(keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
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

    func smbServerAddress(for keyID: Int) -> String {
        configurations[keyID, default: .tallyDefault].smbServer.address
    }

    func sub2APIConfiguration(for keyID: Int) -> DeckKeySub2APIConfiguration {
        configurations[keyID, default: .tallyDefault].sub2API
    }

    func mihoyoGame(for keyID: Int) -> MihoyoGame? {
        configurations[keyID, default: .tallyDefault].function.game
    }

    @discardableResult
    mutating func setSub2APIBaseURL(_ baseURL: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .sub2API
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].sub2API.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
        configurations[keyID, default: .tallyDefault].sub2API.bearerKey = bearerKey
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
    mutating func resetTally(keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
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
    mutating func setFolderPath(_ path: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .openFolder
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].openFolder.path = path
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
    mutating func assign(_ function: DeckKeyFunction, to keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              DeckKeyFunction.assignableCases.contains(function)
        else {
            return false
        }

        selectedKeyID = keyID
        configurations[keyID, default: .tallyDefault].function = function
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

    func display(for key: DeckGridLayout.Key) -> DeckKeyDisplay {
        DeckKeyDisplay(
            key: key,
            configuration: configurations[key.id, default: .tallyDefault],
            isSelected: selectedKeyID == key.id,
            isPressed: isPressed(keyID: key.id)
        )
    }

    func displays(for layout: DeckGridLayout) -> [DeckKeyDisplay] {
        layout.keys.map(display(for:))
    }
}
