import Foundation

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

nonisolated enum DeckKeyPressRuntimeAction: Equatable {
    case none
    case incrementTally
    case openFolder
    case connectSMBServer
    case refreshSub2API
    case refreshMihoyoGame
}

nonisolated enum DeckKeyScheduledRuntime: Equatable {
    case sub2API
    case mihoyoGame
}

extension DeckKeyFunction {
    var pressRuntimeAction: DeckKeyPressRuntimeAction {
        switch self {
        case .tally:
            return .incrementTally
        case .openFolder:
            return .openFolder
        case .connectSMBServer:
            return .connectSMBServer
        case .sub2API:
            return .refreshSub2API
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return .refreshMihoyoGame
        case .brightness, .none:
            return .none
        }
    }

    var scheduledRuntime: DeckKeyScheduledRuntime? {
        switch self {
        case .sub2API:
            return .sub2API
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return .mihoyoGame
        case .tally, .openFolder, .connectSMBServer, .brightness, .none:
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
    var bookmarkData: Data?

    init(path: String? = nil, bookmarkData: Data? = nil) {
        self.path = Self.normalizedPath(path)
        self.bookmarkData = bookmarkData
    }

    init(folderURL: URL) throws {
        self.path = Self.normalizedPath(folderURL.path)
        self.bookmarkData = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    var displayName: String {
        guard let path, !path.isEmpty else {
            return "选择文件夹"
        }

        let name = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
        return name.isEmpty ? path : name
    }

    var needsReselection: Bool {
        guard let path, !path.isEmpty else {
            return false
        }

        return bookmarkData == nil
    }

    var canOpen: Bool {
        bookmarkData != nil
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        return path
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

        guard let parsedBaseURL = try? Sub2APIBaseURL(trimmedBaseURL) else {
            return trimmedBaseURL
        }

        return parsedBaseURL.host
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
