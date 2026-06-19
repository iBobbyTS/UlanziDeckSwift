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
    let smbServerButtonContent: SMBServerButtonContent?
    let isSelected: Bool
    let isPressed: Bool

    init(key: DeckGridLayout.Key, configuration: DeckKeyConfiguration, isSelected: Bool, isPressed: Bool) {
        id = key.id
        row = key.row
        column = key.column
        columnSpan = key.columnSpan
        displayMode = key.columnSpan > 1 ? configuration.displayMode : .function
        let configuredMihoyoGame = configuration.function.game
        var mihoyoGameButtonContent: MihoyoGameButtonContent?
        var sub2APIButtonContent: Sub2APIButtonContent?
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
                title = "打开"
                subtitle = configuration.openFolder.displayName
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
        self.smbServerButtonContent = smbServerButtonContent
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
            smbServerButtonContent: smbServerButtonContent,
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
    let smbServerButtonContent: SMBServerButtonContent?
    let devicePixelSize: H200DeviceTarget.PixelSize
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

nonisolated enum DeckKeyDisplayMode: String, Codable, Equatable, CaseIterable, Identifiable {
    case function
    case clock
    case systemStatus

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .function:
            return "功能"
        case .clock:
            return "时钟"
        case .systemStatus:
            return "系统状态"
        }
    }

    var systemImageName: String {
        switch self {
        case .function:
            return "square.grid.2x2"
        case .clock:
            return "clock"
        case .systemStatus:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var previewTitle: String {
        switch self {
        case .function:
            return ""
        case .clock:
            return "时钟"
        case .systemStatus:
            return "状态"
        }
    }

    var previewSubtitle: String {
        switch self {
        case .function:
            return ""
        case .clock:
            return "模拟表盘"
        case .systemStatus:
            return "CPU RAM GPU"
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
    var name: String

    init(address: String = "", name: String = "") {
        self.address = Self.normalizedAddress(address)
        self.name = Self.normalizedName(name)
    }

    var displayName: String {
        if !name.isEmpty {
            return name
        }

        if !address.isEmpty {
            return address
        }

        return "填写名字"
    }

    var fullURLString: String? {
        guard !address.isEmpty else {
            return nil
        }

        return "smb://\(address)"
    }

    enum CodingKeys: CodingKey {
        case address
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = Self.normalizedAddress(try container.decodeIfPresent(String.self, forKey: .address) ?? "")
        name = Self.normalizedName(try container.decodeIfPresent(String.self, forKey: .name) ?? "")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(name, forKey: .name)
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

    static func normalizedName(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum DeckKeySub2APIGroupListState: Equatable {
    case idle
    case loading
    case success(items: [Sub2APICapacityItem])
    case invalidToken
    case tokenExpired
    case networkError(String)

    var items: [Sub2APICapacityItem] {
        guard case let .success(items) = self else {
            return []
        }

        return items
    }
}

nonisolated enum Sub2APIAvailabilityLevel: Equatable {
    case healthy
    case warning
    case critical

    init(availableConcurrency: Int) {
        if availableConcurrency >= 500 {
            self = .healthy
        } else if availableConcurrency >= 50 {
            self = .warning
        } else {
            self = .critical
        }
    }
}

nonisolated struct Sub2APIButtonContent: Equatable {
    let serviceName: String
    let groupName: String
    let availableConcurrency: Int
    let availabilityLevel: Sub2APIAvailabilityLevel

    init(serviceName: String, groupName: String, availableConcurrency: Int) {
        self.serviceName = serviceName.isEmpty ? "Sub2API" : serviceName
        self.groupName = groupName.isEmpty ? "未命名号池" : groupName
        self.availableConcurrency = availableConcurrency
        self.availabilityLevel = Sub2APIAvailabilityLevel(availableConcurrency: availableConcurrency)
    }

    var availableConcurrencyText: String {
        "\(availableConcurrency)"
    }
}

nonisolated struct DeckKeySub2APIConfiguration: Codable, Equatable {
    var baseURL: String
    var targetGroupID: Int
    var refreshInterval: Int
    var bearerKey: String
    var customServiceName: String
    var customGroupName: String

    /// 最近一次成功查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: Sub2APICapacityResult?

    /// 从服务端获取的号池列表。不参与持久化，配置里仍只保存目标分组 ID。
    var groupListState: DeckKeySub2APIGroupListState = .idle

    init(
        baseURL: String = "",
        targetGroupID: Int = 0,
        refreshInterval: Int = 30,
        bearerKey: String = "",
        customServiceName: String = "",
        customGroupName: String = "",
        lastResult: Sub2APICapacityResult? = nil,
        groupListState: DeckKeySub2APIGroupListState = .idle
    ) {
        self.baseURL = baseURL
        self.targetGroupID = targetGroupID
        self.refreshInterval = refreshInterval
        self.bearerKey = bearerKey
        self.customServiceName = customServiceName
        self.customGroupName = customGroupName
        self.lastResult = lastResult
        self.groupListState = groupListState
    }

    var displayName: String {
        let trimmedCustomGroupName = customGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustomGroupName.isEmpty {
            return trimmedCustomGroupName
        }

        return automaticGroupDisplayName
    }

    var automaticGroupDisplayName: String {
        guard targetGroupID > 0 else {
            return "未配置"
        }

        return selectedGroupName ?? "分组 \(targetGroupID)"
    }

    var serviceDisplayName: String {
        let trimmedCustomServiceName = customServiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustomServiceName.isEmpty {
            return trimmedCustomServiceName
        }

        return automaticServiceDisplayName
    }

    var automaticServiceDisplayName: String {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            return "Sub2API"
        }

        let urlString: String
        if trimmedBaseURL.contains("://") {
            urlString = trimmedBaseURL
        } else {
            urlString = "https://\(trimmedBaseURL)"
        }

        guard let host = URL(string: urlString)?.host, !host.isEmpty else {
            return trimmedBaseURL
        }

        return host
    }

    var selectedGroupName: String? {
        if let option = groupListState.items.first(where: { $0.groupID == targetGroupID }) {
            return option.groupName.isEmpty ? nil : option.groupName
        }

        if case let .success(item) = lastResult, item.groupID == targetGroupID, !item.groupName.isEmpty {
            return item.groupName
        }

        return nil
    }

    enum CodingKeys: CodingKey {
        case baseURL
        case targetGroupID
        case refreshInterval
        case bearerKey
        case customServiceName
        case customGroupName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        targetGroupID = try container.decodeIfPresent(Int.self, forKey: .targetGroupID) ?? 0
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 30
        bearerKey = try container.decodeIfPresent(String.self, forKey: .bearerKey) ?? ""
        customServiceName = try container.decodeIfPresent(String.self, forKey: .customServiceName) ?? ""
        customGroupName = try container.decodeIfPresent(String.self, forKey: .customGroupName) ?? ""
        lastResult = nil
        groupListState = .idle
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(targetGroupID, forKey: .targetGroupID)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(bearerKey, forKey: .bearerKey)
        try container.encode(customServiceName, forKey: .customServiceName)
        try container.encode(customGroupName, forKey: .customGroupName)
    }
}

nonisolated enum DeckBrightnessConfiguration {
    static let defaultPercent = 100

    nonisolated static func clamped(_ percent: Int) -> Int {
        min(100, max(0, percent))
    }
}

nonisolated enum DeckKeyMihoyoGameRefreshConfiguration {
    static let defaultIntervalMinutes = 30
    static let minimumIntervalMinutes = 1
    static let maximumIntervalMinutes = 1_440

    nonisolated static func clamped(_ minutes: Int) -> Int {
        min(maximumIntervalMinutes, max(minimumIntervalMinutes, minutes))
    }
}

nonisolated struct DeckKeyMihoyoGameConfiguration: Codable, Equatable {
    var refreshIntervalMinutes: Int

    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: MihoyoGameStatusResult?

    init(
        refreshIntervalMinutes: Int = DeckKeyMihoyoGameRefreshConfiguration.defaultIntervalMinutes,
        lastResult: MihoyoGameStatusResult? = nil
    ) {
        self.refreshIntervalMinutes = DeckKeyMihoyoGameRefreshConfiguration.clamped(refreshIntervalMinutes)
        self.lastResult = lastResult
    }

    enum CodingKeys: CodingKey {
        case refreshIntervalMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalMinutes = DeckKeyMihoyoGameRefreshConfiguration.clamped(
            try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes)
                ?? DeckKeyMihoyoGameRefreshConfiguration.defaultIntervalMinutes
        )
        lastResult = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
    }
}

nonisolated struct DeckKeyConfiguration: Codable, Equatable {
    var function: DeckKeyFunction
    var displayMode: DeckKeyDisplayMode
    var tally: DeckKeyTallyConfiguration
    var openFolder: DeckKeyOpenFolderConfiguration
    var smbServer: DeckKeySMBServerConfiguration
    var sub2API: DeckKeySub2APIConfiguration
    var mihoyoGame: DeckKeyMihoyoGameConfiguration

    static let empty = DeckKeyConfiguration(
        function: .none,
        displayMode: .function,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration()
    )

    static let tallyDefault = DeckKeyConfiguration(
        function: .tally,
        displayMode: .function,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration()
    )

    init(
        function: DeckKeyFunction,
        displayMode: DeckKeyDisplayMode = .function,
        tally: DeckKeyTallyConfiguration = DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration = DeckKeyOpenFolderConfiguration(),
        smbServer: DeckKeySMBServerConfiguration = DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration = DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration = DeckKeyMihoyoGameConfiguration()
    ) {
        self.function = function
        self.displayMode = displayMode
        self.tally = tally
        self.openFolder = openFolder
        self.smbServer = smbServer
        self.sub2API = sub2API
        self.mihoyoGame = mihoyoGame
    }

    enum CodingKeys: CodingKey {
        case function
        case displayMode
        case tally
        case openFolder
        case smbServer
        case sub2API
        case mihoyoGame
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decode(DeckKeyFunction.self, forKey: .function)
        displayMode = try container.decodeIfPresent(DeckKeyDisplayMode.self, forKey: .displayMode) ?? .function
        tally = try container.decodeIfPresent(DeckKeyTallyConfiguration.self, forKey: .tally) ?? DeckKeyTallyConfiguration()
        openFolder = try container.decodeIfPresent(DeckKeyOpenFolderConfiguration.self, forKey: .openFolder) ?? DeckKeyOpenFolderConfiguration()
        smbServer = try container.decodeIfPresent(DeckKeySMBServerConfiguration.self, forKey: .smbServer) ?? DeckKeySMBServerConfiguration()
        sub2API = try container.decodeIfPresent(DeckKeySub2APIConfiguration.self, forKey: .sub2API) ?? DeckKeySub2APIConfiguration()
        mihoyoGame = try container.decodeIfPresent(DeckKeyMihoyoGameConfiguration.self, forKey: .mihoyoGame) ?? DeckKeyMihoyoGameConfiguration()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(function, forKey: .function)
        try container.encode(displayMode, forKey: .displayMode)
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
    mutating func setSMBServerName(_ name: String, for keyID: Int) -> Bool {
        guard validKeyIDs.contains(keyID),
              configurations[keyID, default: .tallyDefault].function == .connectSMBServer
        else {
            return false
        }

        selectedKeyID = keyID
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
