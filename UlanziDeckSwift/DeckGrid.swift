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
        case .brightness:
            title = ""
            subtitle = ""
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
}

nonisolated enum DeckKeyFunction: String, Codable, Equatable, CaseIterable {
    case none
    case tally
    case openFolder
    case brightness

    static let assignableCases: [DeckKeyFunction] = [.tally, .openFolder]

    var title: String {
        switch self {
        case .none:
            return "无功能"
        case .tally:
            return "计数器"
        case .openFolder:
            return "打开文件夹"
        case .brightness:
            return "亮度调节"
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
        case .brightness:
            return "sun.max"
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

nonisolated enum DeckBrightnessConfiguration {
    static let defaultPercent = 50

    nonisolated static func clamped(_ percent: Int) -> Int {
        min(100, max(0, percent))
    }
}

nonisolated struct DeckKeyConfiguration: Codable, Equatable {
    var function: DeckKeyFunction
    var tally: DeckKeyTallyConfiguration
    var openFolder: DeckKeyOpenFolderConfiguration

    static let empty = DeckKeyConfiguration(
        function: .none,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration()
    )

    static let tallyDefault = DeckKeyConfiguration(
        function: .tally,
        tally: DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration()
    )

    init(
        function: DeckKeyFunction,
        tally: DeckKeyTallyConfiguration = DeckKeyTallyConfiguration(),
        openFolder: DeckKeyOpenFolderConfiguration = DeckKeyOpenFolderConfiguration()
    ) {
        self.function = function
        self.tally = tally
        self.openFolder = openFolder
    }

    enum CodingKeys: CodingKey {
        case function
        case tally
        case openFolder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decode(DeckKeyFunction.self, forKey: .function)
        tally = try container.decodeIfPresent(DeckKeyTallyConfiguration.self, forKey: .tally) ?? DeckKeyTallyConfiguration()
        openFolder = try container.decodeIfPresent(DeckKeyOpenFolderConfiguration.self, forKey: .openFolder) ?? DeckKeyOpenFolderConfiguration()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(function, forKey: .function)
        try container.encode(tally, forKey: .tally)
        try container.encode(openFolder, forKey: .openFolder)
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
