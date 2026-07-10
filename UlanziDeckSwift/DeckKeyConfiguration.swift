import Foundation

nonisolated enum DeckKeyFunction: String, Codable, Equatable, CaseIterable {
    case none
    case tally
    case openFolder
    case openFile
    case openWebPage
    case connectSMBServer
    case brightness
    case sub2API
    case genshinStatus
    case starRailStatus
    case zenlessZoneStatus
    case pageFolder
    case pageBack
    case previousPage
    case nextPage

    static let assignableCases: [DeckKeyFunction] = [
        .tally,
        .openFolder,
        .openFile,
        .openWebPage,
        .connectSMBServer,
        .sub2API,
        .genshinStatus,
        .starRailStatus,
        .zenlessZoneStatus,
        .pageFolder,
        .previousPage,
        .nextPage,
    ]

    var title: String {
        switch self {
        case .none:
            return "无功能"
        case .tally:
            return "计数器"
        case .openFolder:
            return "打开文件夹"
        case .openFile:
            return "打开文件"
        case .openWebPage:
            return "打开网页"
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
        case .pageFolder:
            return DeckKeyPageFolderConfiguration.defaultDisplayName
        case .pageBack:
            return "返回"
        case .previousPage:
            return "上一页"
        case .nextPage:
            return "下一页"
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
        case .openFile:
            return "doc"
        case .openWebPage:
            return "globe"
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
        case .pageFolder:
            return "folder"
        case .pageBack:
            return "arrow.uturn.left"
        case .previousPage:
            return "chevron.left"
        case .nextPage:
            return "chevron.right"
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
        case .none, .tally, .openFolder, .openFile, .openWebPage, .connectSMBServer, .brightness, .sub2API, .pageFolder, .pageBack, .previousPage, .nextPage:
            return nil
        }
    }
}

nonisolated enum DeckKeyPressRuntimeAction: Equatable {
    case none
    case incrementTally
    case openFolder
    case openFile
    case openWebPage
    case connectSMBServer
    case refreshSub2API
    case refreshMihoyoGame
    case enterPage
    case goBackPage
    case previousRootPage
    case nextRootPage
}

nonisolated enum DeckKeyScheduledRuntime: Equatable {
    case sub2API
    case mihoyoGame
}

extension DeckKeyFunction {
    nonisolated var pressRuntimeAction: DeckKeyPressRuntimeAction {
        switch self {
        case .tally:
            return .incrementTally
        case .openFolder:
            return .openFolder
        case .openFile:
            return .openFile
        case .openWebPage:
            return .openWebPage
        case .connectSMBServer:
            return .connectSMBServer
        case .sub2API:
            return .refreshSub2API
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return .refreshMihoyoGame
        case .pageFolder:
            return .enterPage
        case .pageBack:
            return .goBackPage
        case .previousPage:
            return .previousRootPage
        case .nextPage:
            return .nextRootPage
        case .brightness, .none:
            return .none
        }
    }

    nonisolated var scheduledRuntime: DeckKeyScheduledRuntime? {
        switch self {
        case .sub2API:
            return .sub2API
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return .mihoyoGame
        case .tally, .openFolder, .openFile, .openWebPage, .connectSMBServer, .brightness, .none, .pageFolder, .pageBack, .previousPage, .nextPage:
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

nonisolated enum DeckKeySecurityScopedBookmarkOptions {
    static let readOnlyCreation: URL.BookmarkCreationOptions = [
        .withSecurityScope,
        .securityScopeAllowOnlyReadAccess,
    ]
    static let resolution: URL.BookmarkResolutionOptions = [
        .withSecurityScope,
    ]
}

nonisolated struct DeckKeyVisualConfiguration: Codable, Equatable {
    var name: String
    var backgroundPNGData: Data?
    var blurredBackgroundPNGData: Data?
    var usesBlurredBackground: Bool
    var dimsBackground: Bool

    init(
        name: String = "",
        backgroundPNGData: Data? = nil,
        blurredBackgroundPNGData: Data? = nil,
        usesBlurredBackground: Bool = false,
        dimsBackground: Bool = true
    ) {
        self.name = Self.normalizedName(name)
        self.backgroundPNGData = backgroundPNGData
        self.blurredBackgroundPNGData = blurredBackgroundPNGData
        self.dimsBackground = dimsBackground
        self.usesBlurredBackground = usesBlurredBackground
    }

    var canUseBlurredBackground: Bool {
        backgroundPNGData != nil && blurredBackgroundPNGData != nil
    }

    var selectedBackgroundPNGData: Data? {
        if usesBlurredBackground {
            return blurredBackgroundPNGData ?? backgroundPNGData
        }

        return backgroundPNGData
    }

    var hasCustomBackground: Bool {
        backgroundPNGData != nil
    }

    func displayName(fallback: String) -> String {
        name.isEmpty ? fallback : name
    }

    enum CodingKeys: CodingKey {
        case name
        case backgroundPNGData
        case blurredBackgroundPNGData
        case usesBlurredBackground
        case dimsBackground
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = Self.normalizedName(try container.decodeIfPresent(String.self, forKey: .name) ?? "")
        backgroundPNGData = try container.decodeIfPresent(Data.self, forKey: .backgroundPNGData)
        blurredBackgroundPNGData = try container.decodeIfPresent(Data.self, forKey: .blurredBackgroundPNGData)
        usesBlurredBackground = try container.decodeIfPresent(Bool.self, forKey: .usesBlurredBackground) ?? false
        dimsBackground = try container.decodeIfPresent(Bool.self, forKey: .dimsBackground) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(backgroundPNGData, forKey: .backgroundPNGData)
        try container.encodeIfPresent(blurredBackgroundPNGData, forKey: .blurredBackgroundPNGData)
        try container.encode(usesBlurredBackground, forKey: .usesBlurredBackground)
        try container.encode(dimsBackground, forKey: .dimsBackground)
    }

    static func normalizedName(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct DeckKeyOpenFolderConfiguration: Codable, Equatable {
    static let securityScopedBookmarkCreationOptions = DeckKeySecurityScopedBookmarkOptions.readOnlyCreation
    static let securityScopedBookmarkResolutionOptions = DeckKeySecurityScopedBookmarkOptions.resolution

    var path: String?
    var bookmarkData: Data?
    var visual: DeckKeyVisualConfiguration

    init(
        path: String? = nil,
        bookmarkData: Data? = nil,
        name: String = "",
        backgroundPNGData: Data? = nil,
        blurredBackgroundPNGData: Data? = nil,
        usesBlurredBackground: Bool = false,
        dimsBackground: Bool = true,
        visual: DeckKeyVisualConfiguration? = nil
    ) {
        self.path = Self.normalizedPath(path)
        self.bookmarkData = bookmarkData
        self.visual = visual ?? DeckKeyVisualConfiguration(
            name: name,
            backgroundPNGData: backgroundPNGData,
            blurredBackgroundPNGData: blurredBackgroundPNGData,
            usesBlurredBackground: usesBlurredBackground,
            dimsBackground: dimsBackground
        )
    }

    init(folderURL: URL, name: String = "", visual: DeckKeyVisualConfiguration? = nil) throws {
        self.path = Self.normalizedPath(folderURL.path)
        self.bookmarkData = try folderURL.bookmarkData(
            options: Self.securityScopedBookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.visual = visual ?? DeckKeyVisualConfiguration(name: name)
    }

    var name: String {
        get {
            visual.name
        }
        set {
            visual.name = DeckKeyVisualConfiguration.normalizedName(newValue)
        }
    }

    var backgroundPNGData: Data? {
        get {
            visual.backgroundPNGData
        }
        set {
            visual.backgroundPNGData = newValue
            if newValue == nil {
                visual.blurredBackgroundPNGData = nil
                visual.usesBlurredBackground = false
            }
        }
    }

    var blurredBackgroundPNGData: Data? {
        get {
            visual.blurredBackgroundPNGData
        }
        set {
            visual.blurredBackgroundPNGData = newValue
            if newValue == nil {
                visual.usesBlurredBackground = false
            }
        }
    }

    var usesBlurredBackground: Bool {
        get {
            visual.usesBlurredBackground
        }
        set {
            visual.usesBlurredBackground = newValue && visual.canUseBlurredBackground
        }
    }

    var dimsBackground: Bool {
        get {
            visual.dimsBackground
        }
        set {
            visual.dimsBackground = newValue
        }
    }

    var canUseBlurredBackground: Bool {
        visual.canUseBlurredBackground
    }

    var selectedBackgroundPNGData: Data? {
        visual.selectedBackgroundPNGData
    }

    var displayName: String {
        visual.displayName(fallback: automaticDisplayName)
    }

    var automaticDisplayName: String {
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

    enum CodingKeys: CodingKey {
        case path
        case bookmarkData
        case name
        case backgroundPNGData
        case blurredBackgroundPNGData
        case usesBlurredBackground
        case dimsBackground
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = Self.normalizedPath(try container.decodeIfPresent(String.self, forKey: .path))
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        if let visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual) {
            self.visual = visual
        } else {
            visual = DeckKeyVisualConfiguration(
                name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
                backgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .backgroundPNGData),
                blurredBackgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .blurredBackgroundPNGData),
                usesBlurredBackground: try container.decodeIfPresent(Bool.self, forKey: .usesBlurredBackground) ?? false,
                dimsBackground: try container.decodeIfPresent(Bool.self, forKey: .dimsBackground) ?? true
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(visual, forKey: .visual)
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        return path
    }

    static func normalizedName(_ rawValue: String) -> String {
        DeckKeyVisualConfiguration.normalizedName(rawValue)
    }
}

nonisolated struct DeckKeyOpenFileConfiguration: Codable, Equatable {
    static let securityScopedBookmarkCreationOptions = DeckKeySecurityScopedBookmarkOptions.readOnlyCreation
    static let securityScopedBookmarkResolutionOptions = DeckKeySecurityScopedBookmarkOptions.resolution

    var path: String?
    var bookmarkData: Data?
    var visual: DeckKeyVisualConfiguration

    init(
        path: String? = nil,
        bookmarkData: Data? = nil,
        name: String = "",
        iconPNGData: Data? = nil,
        blurredIconPNGData: Data? = nil,
        usesBlurredIcon: Bool = false,
        dimsBackground: Bool = true,
        visual: DeckKeyVisualConfiguration? = nil
    ) {
        self.path = Self.normalizedPath(path)
        self.bookmarkData = bookmarkData
        self.visual = visual ?? DeckKeyVisualConfiguration(
            name: name,
            backgroundPNGData: iconPNGData,
            blurredBackgroundPNGData: blurredIconPNGData,
            usesBlurredBackground: usesBlurredIcon,
            dimsBackground: dimsBackground
        )
    }

    init(
        fileURL: URL,
        name: String = "",
        iconSnapshot: FileIconSnapshotData? = nil,
        visual: DeckKeyVisualConfiguration? = nil
    ) throws {
        self.path = Self.normalizedPath(fileURL.path)
        self.bookmarkData = try fileURL.bookmarkData(
            options: Self.securityScopedBookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        if let visual {
            self.visual = visual
        } else {
            self.visual = DeckKeyVisualConfiguration(
                name: name,
                backgroundPNGData: iconSnapshot?.iconPNGData,
                blurredBackgroundPNGData: iconSnapshot?.blurredIconPNGData
            )
        }
    }

    var name: String {
        get {
            visual.name
        }
        set {
            visual.name = DeckKeyVisualConfiguration.normalizedName(newValue)
        }
    }

    var iconPNGData: Data? {
        get {
            visual.backgroundPNGData
        }
        set {
            visual.backgroundPNGData = newValue
            if newValue == nil {
                visual.blurredBackgroundPNGData = nil
                visual.usesBlurredBackground = false
            }
        }
    }

    var blurredIconPNGData: Data? {
        get {
            visual.blurredBackgroundPNGData
        }
        set {
            visual.blurredBackgroundPNGData = newValue
            if newValue == nil {
                visual.usesBlurredBackground = false
            }
        }
    }

    var usesBlurredIcon: Bool {
        get {
            visual.usesBlurredBackground
        }
        set {
            visual.usesBlurredBackground = newValue && visual.canUseBlurredBackground
        }
    }

    var dimsBackground: Bool {
        get {
            visual.dimsBackground
        }
        set {
            visual.dimsBackground = newValue
        }
    }

    var displayName: String {
        visual.displayName(fallback: automaticDisplayName)
    }

    var automaticDisplayName: String {
        guard let path, !path.isEmpty else {
            return "选择文件"
        }

        let name = URL(fileURLWithPath: path, isDirectory: false).lastPathComponent
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

    var canUseIconBlur: Bool {
        visual.canUseBlurredBackground
    }

    var selectedIconPNGData: Data? {
        visual.selectedBackgroundPNGData
    }

    enum CodingKeys: CodingKey {
        case path
        case bookmarkData
        case name
        case iconPNGData
        case blurredIconPNGData
        case usesBlurredIcon
        case dimsBackground
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = Self.normalizedPath(try container.decodeIfPresent(String.self, forKey: .path))
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        if let visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual) {
            self.visual = visual
        } else {
            visual = DeckKeyVisualConfiguration(
                name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
                backgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .iconPNGData),
                blurredBackgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .blurredIconPNGData),
                usesBlurredBackground: try container.decodeIfPresent(Bool.self, forKey: .usesBlurredIcon) ?? false,
                dimsBackground: try container.decodeIfPresent(Bool.self, forKey: .dimsBackground) ?? true
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(visual, forKey: .visual)
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        return path
    }

    static func normalizedName(_ rawValue: String) -> String {
        DeckKeyVisualConfiguration.normalizedName(rawValue)
    }
}

nonisolated struct DeckKeyOpenWebPageConfiguration: Codable, Equatable {
    var urlString: String
    var title: String
    var visual: DeckKeyVisualConfiguration

    init(urlString: String = "", title: String = "", iconSnapshot: FileIconSnapshotData? = nil, visual: DeckKeyVisualConfiguration? = nil) {
        self.urlString = Self.normalizedURLString(urlString)
        self.title = DeckKeyVisualConfiguration.normalizedName(title)
        self.visual = visual ?? DeckKeyVisualConfiguration(
            backgroundPNGData: iconSnapshot?.iconPNGData,
            blurredBackgroundPNGData: iconSnapshot?.blurredIconPNGData
        )
    }

    var iconPNGData: Data? {
        get {
            visual.backgroundPNGData
        }
        set {
            visual.backgroundPNGData = newValue
            if newValue == nil {
                visual.blurredBackgroundPNGData = nil
                visual.usesBlurredBackground = false
            }
        }
    }

    var blurredIconPNGData: Data? {
        get {
            visual.blurredBackgroundPNGData
        }
        set {
            visual.blurredBackgroundPNGData = newValue
            if newValue == nil {
                visual.usesBlurredBackground = false
            }
        }
    }

    var usesBlurredIcon: Bool {
        get {
            visual.usesBlurredBackground
        }
        set {
            visual.usesBlurredBackground = newValue && visual.canUseBlurredBackground
        }
    }

    var displayName: String {
        visual.displayName(fallback: automaticDisplayName)
    }

    var automaticDisplayName: String {
        title
    }

    var url: URL? {
        try? WebPageURL(urlString).url
    }

    var canOpen: Bool {
        url != nil
    }

    enum CodingKeys: CodingKey {
        case urlString
        case title
        case iconPNGData
        case blurredIconPNGData
        case usesBlurredIcon
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urlString = Self.normalizedURLString(try container.decodeIfPresent(String.self, forKey: .urlString) ?? "")
        let decodedTitle = DeckKeyVisualConfiguration.normalizedName(try container.decodeIfPresent(String.self, forKey: .title) ?? "")
        if let visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual) {
            var decodedVisual = visual
            title = decodedTitle.isEmpty ? decodedVisual.name : decodedTitle
            decodedVisual.name = ""
            self.visual = decodedVisual
        } else {
            title = decodedTitle
            visual = DeckKeyVisualConfiguration(
                backgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .iconPNGData),
                blurredBackgroundPNGData: try container.decodeIfPresent(Data.self, forKey: .blurredIconPNGData),
                usesBlurredBackground: try container.decodeIfPresent(Bool.self, forKey: .usesBlurredIcon) ?? false
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(urlString, forKey: .urlString)
        try container.encode(title, forKey: .title)
        try container.encode(visual, forKey: .visual)
    }

    static func normalizedURLString(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct DeckKeySMBServerConfiguration: Codable, Equatable {
    var address: String
    var visual: DeckKeyVisualConfiguration

    init(address: String = "", name: String = "", visual: DeckKeyVisualConfiguration? = nil) {
        self.address = Self.validatedAddress(address) ?? ""
        self.visual = visual ?? DeckKeyVisualConfiguration(name: name)
    }

    var name: String {
        get {
            visual.name
        }
        set {
            visual.name = DeckKeyVisualConfiguration.normalizedName(newValue)
        }
    }

    var displayName: String {
        visual.displayName(fallback: automaticDisplayName)
    }

    var automaticDisplayName: String {
        if !address.isEmpty {
            return address
        }

        return "填写名字"
    }

    var fullURLString: String? {
        guard let validatedAddress = Self.validatedAddress(address),
              !validatedAddress.isEmpty
        else {
            return nil
        }

        return "smb://\(validatedAddress)"
    }

    enum CodingKeys: CodingKey {
        case address
        case name
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = Self.validatedAddress(
            try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        ) ?? ""
        visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual)
            ?? DeckKeyVisualConfiguration(name: try container.decodeIfPresent(String.self, forKey: .name) ?? "")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(visual, forKey: .visual)
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

    static func validatedAddress(_ rawValue: String) -> String? {
        let address = normalizedAddress(rawValue)
        guard !address.isEmpty else {
            return ""
        }

        guard !containsUserInfo(in: address),
              let components = URLComponents(string: "smb://\(address)"),
              components.scheme?.lowercased() == "smb",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.host,
              !host.isEmpty,
              isValidDecodedHost(host),
              isValidAuthority(in: address),
              components.url != nil
        else {
            return nil
        }

        return address
    }

    static func containsUserInfo(in rawValue: String) -> Bool {
        let address = normalizedAddress(rawValue)
        guard !address.isEmpty else {
            return false
        }

        if let components = URLComponents(string: "smb://\(address)"),
           components.user != nil || components.password != nil {
            return true
        }

        let authority = authority(in: address)
        let decodedAuthority = fullyRemovingPercentEncoding(from: String(authority))
        return decodedAuthority.contains("@")
    }

    private static func fullyRemovingPercentEncoding(from value: String) -> String {
        var decodedValue = value
        while let nextValue = decodedValue.removingPercentEncoding,
              nextValue != decodedValue {
            decodedValue = nextValue
        }
        return decodedValue
    }

    private static func authority(in address: String) -> Substring {
        address.prefix { character in
            character != "/" && character != "?" && character != "#"
        }
    }

    private static func isValidDecodedHost(_ host: String) -> Bool {
        guard !host.contains("@"),
              !host.contains("/"),
              !host.contains("?"),
              !host.contains("#")
        else {
            return false
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            return host.count > 2
        }

        return !host.contains(":")
    }

    private static func isValidAuthority(in address: String) -> Bool {
        let authority = authority(in: address)
        guard !authority.isEmpty else {
            return false
        }

        let portText: Substring?
        if authority.first == "[" {
            guard let closingBracket = authority.firstIndex(of: "]") else {
                return false
            }
            let suffix = authority[authority.index(after: closingBracket)...]
            guard suffix.isEmpty || suffix.first == ":" else {
                return false
            }
            portText = suffix.isEmpty ? nil : suffix.dropFirst()
        } else {
            let components = authority.split(separator: ":", omittingEmptySubsequences: false)
            guard components.count <= 2 else {
                return false
            }
            portText = components.count == 2 ? components[1] : nil
        }

        guard let portText else {
            return true
        }
        guard !portText.isEmpty,
              portText.allSatisfy(\.isNumber),
              let port = Int(portText),
              (1...65_535).contains(port)
        else {
            return false
        }

        return true
    }

    static func normalizedName(_ rawValue: String) -> String {
        DeckKeyVisualConfiguration.normalizedName(rawValue)
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
    var credentialID: String?
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
        credentialID: String? = nil,
        customServiceName: String = "",
        customGroupName: String = "",
        lastResult: Sub2APICapacityResult? = nil,
        groupListState: DeckKeySub2APIGroupListState = .idle
    ) {
        self.baseURL = baseURL
        self.targetGroupID = targetGroupID
        self.refreshInterval = refreshInterval
        self.bearerKey = bearerKey
        self.credentialID = credentialID ?? (bearerKey.isEmpty ? nil : UUID().uuidString)
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
        case credentialID
        case customServiceName
        case customGroupName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        targetGroupID = try container.decodeIfPresent(Int.self, forKey: .targetGroupID) ?? 0
        refreshInterval = try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 30
        bearerKey = try container.decodeIfPresent(String.self, forKey: .bearerKey) ?? ""
        credentialID = try container.decodeIfPresent(String.self, forKey: .credentialID)
            ?? (bearerKey.isEmpty ? nil : UUID().uuidString)
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
        try container.encodeIfPresent(credentialID, forKey: .credentialID)
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
    var visual: DeckKeyVisualConfiguration

    /// 最近一次查询的结果。不参与持久化，反序列化时使用空值。
    var lastResult: MihoyoGameStatusResult?

    init(
        refreshIntervalMinutes: Int = DeckKeyMihoyoGameRefreshConfiguration.defaultIntervalMinutes,
        lastResult: MihoyoGameStatusResult? = nil,
        visual: DeckKeyVisualConfiguration = DeckKeyVisualConfiguration()
    ) {
        self.refreshIntervalMinutes = DeckKeyMihoyoGameRefreshConfiguration.clamped(refreshIntervalMinutes)
        self.visual = visual
        self.lastResult = lastResult
    }

    enum CodingKeys: CodingKey {
        case refreshIntervalMinutes
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalMinutes = DeckKeyMihoyoGameRefreshConfiguration.clamped(
            try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes)
                ?? DeckKeyMihoyoGameRefreshConfiguration.defaultIntervalMinutes
        )
        visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual)
            ?? DeckKeyVisualConfiguration()
        lastResult = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
        try container.encode(visual, forKey: .visual)
    }
}

nonisolated struct DeckKeyPageFolderConfiguration: Codable, Equatable {
    static let defaultDisplayName = "功能夹"
    private static let legacyDefaultDisplayName = "文件夹"

    var pageID: String?
    var visual: DeckKeyVisualConfiguration

    init(pageID: String? = nil, visual: DeckKeyVisualConfiguration = DeckKeyVisualConfiguration(name: Self.defaultDisplayName)) {
        self.pageID = pageID
        self.visual = visual
    }

    var displayName: String {
        visual.displayName(fallback: Self.defaultDisplayName)
    }

    enum CodingKeys: CodingKey {
        case pageID
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageID = try container.decodeIfPresent(String.self, forKey: .pageID)
        visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual)
            ?? DeckKeyVisualConfiguration(name: Self.defaultDisplayName)
        visual = Self.migratingLegacyDefaultName(in: visual)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(pageID, forKey: .pageID)
        try container.encode(visual, forKey: .visual)
    }

    static func migratingLegacyDefaultName(in visual: DeckKeyVisualConfiguration) -> DeckKeyVisualConfiguration {
        var migratedVisual = visual
        if migratedVisual.name == legacyDefaultDisplayName {
            migratedVisual.name = defaultDisplayName
        }
        return migratedVisual
    }
}

nonisolated struct DeckKeyConfiguration: Codable, Equatable {
    var function: DeckKeyFunction
    var displayMode: DeckKeyDisplayMode
    var tally: DeckKeyTallyConfiguration
    var openFolder: DeckKeyOpenFolderConfiguration
    var openFile: DeckKeyOpenFileConfiguration
    var openWebPage: DeckKeyOpenWebPageConfiguration
    var smbServer: DeckKeySMBServerConfiguration
    var sub2API: DeckKeySub2APIConfiguration
    var mihoyoGame: DeckKeyMihoyoGameConfiguration
    var pageFolder: DeckKeyPageFolderConfiguration
    var visual: DeckKeyVisualConfiguration

    static let empty = DeckKeyConfiguration(
        function: .none,
        displayMode: .function,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        openFile: DeckKeyOpenFileConfiguration(),
        openWebPage: DeckKeyOpenWebPageConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration(),
        pageFolder: DeckKeyPageFolderConfiguration()
    )

    static let tallyDefault = DeckKeyConfiguration(
        function: .tally,
        displayMode: .function,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        openFile: DeckKeyOpenFileConfiguration(),
        openWebPage: DeckKeyOpenWebPageConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration(),
        pageFolder: DeckKeyPageFolderConfiguration()
    )

    static let pageBack = DeckKeyConfiguration(
        function: .pageBack,
        displayMode: .function,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration(),
        openFile: DeckKeyOpenFileConfiguration(),
        openWebPage: DeckKeyOpenWebPageConfiguration(),
        smbServer: DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration(),
        pageFolder: DeckKeyPageFolderConfiguration(),
        visual: DeckKeyVisualConfiguration(dimsBackground: false)
    )

    init(
        function: DeckKeyFunction,
        displayMode: DeckKeyDisplayMode = .function,
        tally: DeckKeyTallyConfiguration = DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration = DeckKeyOpenFolderConfiguration(),
        openFile: DeckKeyOpenFileConfiguration = DeckKeyOpenFileConfiguration(),
        openWebPage: DeckKeyOpenWebPageConfiguration = DeckKeyOpenWebPageConfiguration(),
        smbServer: DeckKeySMBServerConfiguration = DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration = DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration = DeckKeyMihoyoGameConfiguration(),
        pageFolder: DeckKeyPageFolderConfiguration = DeckKeyPageFolderConfiguration(),
        visual: DeckKeyVisualConfiguration = DeckKeyVisualConfiguration()
    ) {
        self.function = function
        self.displayMode = displayMode
        self.tally = tally
        self.openFolder = openFolder
        self.openFile = openFile
        self.openWebPage = openWebPage
        self.smbServer = smbServer
        self.sub2API = sub2API
        self.mihoyoGame = mihoyoGame
        self.pageFolder = pageFolder
        self.visual = visual
    }

    init(
        function: DeckKeyFunction,
        displayMode: DeckKeyDisplayMode = .function,
        tally: DeckKeyTallyConfiguration = DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration = DeckKeyOpenFolderConfiguration(),
        openFile: DeckKeyOpenFileConfiguration = DeckKeyOpenFileConfiguration(),
        openWebPage: DeckKeyOpenWebPageConfiguration = DeckKeyOpenWebPageConfiguration(),
        smbServer: DeckKeySMBServerConfiguration = DeckKeySMBServerConfiguration(),
        sub2API: DeckKeySub2APIConfiguration = DeckKeySub2APIConfiguration(),
        mihoyoGame: DeckKeyMihoyoGameConfiguration = DeckKeyMihoyoGameConfiguration(),
        pageFolder: DeckKeyPageFolderConfiguration = DeckKeyPageFolderConfiguration()
    ) {
        self.init(
            function: function,
            displayMode: displayMode,
            tally: tally,
            openFolder: openFolder,
            openFile: openFile,
            openWebPage: openWebPage,
            smbServer: smbServer,
            sub2API: sub2API,
            mihoyoGame: mihoyoGame,
            pageFolder: pageFolder,
            visual: DeckKeyVisualConfiguration()
        )
    }

    enum CodingKeys: CodingKey {
        case function
        case displayMode
        case tally
        case openFolder
        case openFile
        case openWebPage
        case smbServer
        case sub2API
        case mihoyoGame
        case pageFolder
        case visual
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decode(DeckKeyFunction.self, forKey: .function)
        displayMode = try container.decodeIfPresent(DeckKeyDisplayMode.self, forKey: .displayMode) ?? .function
        tally = try container.decodeIfPresent(DeckKeyTallyConfiguration.self, forKey: .tally) ?? DeckKeyTallyConfiguration()
        openFolder = try container.decodeIfPresent(DeckKeyOpenFolderConfiguration.self, forKey: .openFolder) ?? DeckKeyOpenFolderConfiguration()
        openFile = try container.decodeIfPresent(DeckKeyOpenFileConfiguration.self, forKey: .openFile) ?? DeckKeyOpenFileConfiguration()
        openWebPage = try container.decodeIfPresent(DeckKeyOpenWebPageConfiguration.self, forKey: .openWebPage) ?? DeckKeyOpenWebPageConfiguration()
        smbServer = try container.decodeIfPresent(DeckKeySMBServerConfiguration.self, forKey: .smbServer) ?? DeckKeySMBServerConfiguration()
        sub2API = try container.decodeIfPresent(DeckKeySub2APIConfiguration.self, forKey: .sub2API) ?? DeckKeySub2APIConfiguration()
        mihoyoGame = try container.decodeIfPresent(DeckKeyMihoyoGameConfiguration.self, forKey: .mihoyoGame) ?? DeckKeyMihoyoGameConfiguration()
        pageFolder = try container.decodeIfPresent(DeckKeyPageFolderConfiguration.self, forKey: .pageFolder) ?? DeckKeyPageFolderConfiguration()
        visual = try container.decodeIfPresent(DeckKeyVisualConfiguration.self, forKey: .visual)
            ?? Self.migratedButtonVisual(
                function: function,
                openFolder: openFolder,
                openFile: openFile,
                openWebPage: openWebPage,
                smbServer: smbServer,
                pageFolder: pageFolder
            )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(function, forKey: .function)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(tally, forKey: .tally)
        try container.encode(openFolder, forKey: .openFolder)
        try container.encode(openFile, forKey: .openFile)
        try container.encode(openWebPage, forKey: .openWebPage)
        try container.encode(smbServer, forKey: .smbServer)
        try container.encode(sub2API, forKey: .sub2API)
        try container.encode(mihoyoGame, forKey: .mihoyoGame)
        try container.encode(pageFolder, forKey: .pageFolder)
        try container.encode(visual, forKey: .visual)
    }

    var buttonVisualConfiguration: DeckKeyVisualConfiguration? {
        visual
    }

    @discardableResult
    mutating func setButtonVisualConfiguration(_ visual: DeckKeyVisualConfiguration) -> Bool {
        self.visual = visual
        if self.visual.usesBlurredBackground && !buttonVisualCanUseBlurredBackground {
            self.visual.usesBlurredBackground = false
        }
        return true
    }

    var buttonVisualCanUseBlurredBackground: Bool {
        visual.canUseBlurredBackground || defaultButtonBlurredBackgroundPNGData != nil
    }

    var selectedButtonBackgroundPNGData: Data? {
        if visual.hasCustomBackground {
            return visual.selectedBackgroundPNGData
        }

        if visual.usesBlurredBackground {
            return defaultButtonBlurredBackgroundPNGData ?? defaultButtonBackgroundPNGData
        }

        return defaultButtonBackgroundPNGData
    }

    var defaultButtonBackgroundPNGData: Data? {
        switch function {
        case .openFolder:
            return openFolder.visual.backgroundPNGData
        case .openFile:
            return openFile.visual.backgroundPNGData
        case .openWebPage:
            return openWebPage.visual.backgroundPNGData
        case .connectSMBServer:
            return smbServer.visual.backgroundPNGData
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return mihoyoGame.visual.backgroundPNGData
        case .pageFolder:
            return pageFolder.visual.backgroundPNGData
        case .pageBack:
            return visual.backgroundPNGData
        case .none, .tally, .brightness, .sub2API:
            return nil
        case .previousPage, .nextPage:
            return visual.backgroundPNGData
        }
    }

    var defaultButtonBlurredBackgroundPNGData: Data? {
        switch function {
        case .openFolder:
            return openFolder.visual.blurredBackgroundPNGData
        case .openFile:
            return openFile.visual.blurredBackgroundPNGData
        case .openWebPage:
            return openWebPage.visual.blurredBackgroundPNGData
        case .connectSMBServer:
            return smbServer.visual.blurredBackgroundPNGData
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return mihoyoGame.visual.blurredBackgroundPNGData
        case .pageFolder:
            return pageFolder.visual.blurredBackgroundPNGData
        case .pageBack:
            return visual.blurredBackgroundPNGData
        case .none, .tally, .brightness, .sub2API:
            return nil
        case .previousPage, .nextPage:
            return visual.blurredBackgroundPNGData
        }
    }

    var automaticButtonDisplayName: String {
        switch function {
        case .none:
            return ""
        case .tally:
            return "\(tally.value)"
        case .openFolder:
            return openFolder.automaticDisplayName
        case .openFile:
            return openFile.automaticDisplayName
        case .openWebPage:
            return openWebPage.automaticDisplayName
        case .connectSMBServer:
            return smbServer.automaticDisplayName
        case .brightness:
            return ""
        case .sub2API:
            return sub2API.displayName
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return function.game?.shortDisplayName ?? "游戏"
        case .pageFolder:
            return DeckKeyPageFolderConfiguration.defaultDisplayName
        case .pageBack:
            return ""
        case .previousPage, .nextPage:
            return function.title
        }
    }

    private static func migratedButtonVisual(
        function: DeckKeyFunction,
        openFolder: DeckKeyOpenFolderConfiguration,
        openFile: DeckKeyOpenFileConfiguration,
        openWebPage: DeckKeyOpenWebPageConfiguration,
        smbServer: DeckKeySMBServerConfiguration,
        pageFolder: DeckKeyPageFolderConfiguration
    ) -> DeckKeyVisualConfiguration {
        switch function {
        case .openFolder:
            return openFolder.visual
        case .openFile:
            return DeckKeyVisualConfiguration(
                name: openFile.visual.name,
                usesBlurredBackground: openFile.visual.usesBlurredBackground,
                dimsBackground: openFile.visual.dimsBackground
            )
        case .openWebPage:
            return DeckKeyVisualConfiguration(
                usesBlurredBackground: openWebPage.visual.usesBlurredBackground,
                dimsBackground: openWebPage.visual.dimsBackground
            )
        case .connectSMBServer:
            return smbServer.visual
        case .pageFolder:
            return DeckKeyPageFolderConfiguration.migratingLegacyDefaultName(in: pageFolder.visual)
        case .pageBack:
            return DeckKeyVisualConfiguration(dimsBackground: false)
        case .none, .tally, .brightness, .sub2API, .genshinStatus, .starRailStatus, .zenlessZoneStatus, .previousPage, .nextPage:
            return DeckKeyVisualConfiguration()
        }
    }
}
