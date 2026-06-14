import Foundation

nonisolated struct DeckGridLayout: Equatable {
    nonisolated struct Key: Identifiable, Equatable {
        let id: Int
        let row: Int
        let column: Int
        let columnSpan: Int
    }

    let name: String
    let columnCount: Int
    let keys: [Key]

    static let h200Prototype = DeckGridLayout(
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
}

nonisolated struct DeckKeyDisplay: Equatable, Identifiable {
    let id: Int
    let row: Int
    let column: Int
    let columnSpan: Int
    let title: String
    let subtitle: String
    let isSelected: Bool

    init(key: DeckGridLayout.Key, tapCount: Int, isSelected: Bool) {
        id = key.id
        row = key.row
        column = key.column
        columnSpan = key.columnSpan
        title = "\(key.id)"
        subtitle = tapCount == 0 ? "就绪" : "\(tapCount) 次"
        self.isSelected = isSelected
    }

    var isWide: Bool {
        columnSpan > 1
    }

    var devicePixelSize: H200DeviceTarget.PixelSize {
        isWide ? H200DeviceTarget.smallWindowIconSize : H200DeviceTarget.buttonIconSize
    }
}

nonisolated struct DeckGridInteractionState: Equatable {
    private(set) var selectedKeyID: Int?
    private(set) var tapCounts: [Int: Int]
    private let validKeyIDs: Set<Int>

    init(layout: DeckGridLayout) {
        selectedKeyID = nil
        tapCounts = Dictionary(uniqueKeysWithValues: layout.keys.map { ($0.id, 0) })
        validKeyIDs = Set(layout.keys.map(\.id))
    }

    mutating func press(keyID: Int) {
        guard validKeyIDs.contains(keyID) else {
            return
        }

        selectedKeyID = keyID
        tapCounts[keyID, default: 0] += 1
    }

    func tapCount(for keyID: Int) -> Int {
        tapCounts[keyID, default: 0]
    }

    func display(for key: DeckGridLayout.Key) -> DeckKeyDisplay {
        DeckKeyDisplay(
            key: key,
            tapCount: tapCount(for: key.id),
            isSelected: selectedKeyID == key.id
        )
    }

    func displays(for layout: DeckGridLayout) -> [DeckKeyDisplay] {
        layout.keys.map(display(for:))
    }
}
