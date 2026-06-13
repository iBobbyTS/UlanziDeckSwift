import Foundation

struct DeckGridLayout: Equatable {
    struct Key: Identifiable, Equatable {
        let id: Int
        let row: Int
        let column: Int
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
                column: zeroBasedIndex % 5
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

struct DeckGridInteractionState: Equatable {
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
}
