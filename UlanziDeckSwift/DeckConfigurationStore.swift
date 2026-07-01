import Foundation

nonisolated protocol DeckConfigurationStoring {
    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState?
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout)
    func loadBrightnessPercent() -> Int?
    func saveBrightnessPercent(_ percent: Int)
}

extension DeckConfigurationStoring {
    nonisolated func loadBrightnessPercent() -> Int? { nil }
    nonisolated func saveBrightnessPercent(_ percent: Int) {}
}

nonisolated struct UserDefaultsDeckConfigurationStore: DeckConfigurationStoring {
    static let defaultStorageKey = "com.iBobby.UlanziDeckSwift.h200.deckConfiguration.v1"
    static let defaultBrightnessStorageKey = "com.iBobby.UlanziDeckSwift.h200.brightness.v1"

    private let defaults: UserDefaults
    private let storageKey: String
    private let brightnessStorageKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = Self.defaultStorageKey,
        brightnessStorageKey: String = Self.defaultBrightnessStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.brightnessStorageKey = brightnessStorageKey
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? decoder.decode(StoredDeckConfiguration.self, from: data),
              stored.layoutIdentifier == layout.identifier
        else {
            return nil
        }

        switch stored.version {
        case 1:
            var configurations: [Int: DeckKeyConfiguration] = [:]
            for key in stored.keys {
                configurations[key.id] = key.configuration
            }
            return DeckGridInteractionState(layout: layout, configurations: configurations)

        case StoredDeckConfiguration.currentVersion:
            let pages = stored.pages.map { page in
                DeckGridPage(
                    id: page.id,
                    parentID: page.parentID,
                    configurations: Dictionary(uniqueKeysWithValues: page.keys.map { ($0.id, $0.configuration) })
                )
            }
            return DeckGridInteractionState(layout: layout, pages: pages, rootPageIDs: stored.rootPageIDs)

        default:
            return nil
        }
    }

    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) {
        let pages = state.persistedPages.map { page in
            let keys = layout.keys.compactMap { key -> StoredDeckKeyConfiguration? in
                guard let configuration = page.configurations[key.id] else {
                    return nil
                }

                return StoredDeckKeyConfiguration(id: key.id, configuration: configuration)
            }

            return StoredDeckPage(id: page.id, parentID: page.parentID, keys: keys)
        }

        let stored = StoredDeckConfiguration(
            layoutIdentifier: layout.identifier,
            pages: pages,
            rootPageIDs: state.rootPageIDs
        )
        guard let data = try? encoder.encode(stored) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    func loadBrightnessPercent() -> Int? {
        guard let number = defaults.object(forKey: brightnessStorageKey) as? NSNumber else {
            return nil
        }

        return DeckBrightnessConfiguration.clamped(number.intValue)
    }

    func saveBrightnessPercent(_ percent: Int) {
        defaults.set(DeckBrightnessConfiguration.clamped(percent), forKey: brightnessStorageKey)
    }
}

nonisolated private struct StoredDeckConfiguration: Codable, Equatable {
    static let currentVersion = 2

    let version: Int
    let layoutIdentifier: String
    let keys: [StoredDeckKeyConfiguration]
    let pages: [StoredDeckPage]
    let rootPageIDs: [String]

    init(layoutIdentifier: String, pages: [StoredDeckPage], rootPageIDs: [String]) {
        version = Self.currentVersion
        self.layoutIdentifier = layoutIdentifier
        keys = []
        self.pages = pages
        self.rootPageIDs = rootPageIDs
    }

    enum CodingKeys: CodingKey {
        case version
        case layoutIdentifier
        case keys
        case pages
        case rootPageIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        layoutIdentifier = try container.decode(String.self, forKey: .layoutIdentifier)
        keys = try container.decodeIfPresent([StoredDeckKeyConfiguration].self, forKey: .keys) ?? []
        pages = try container.decodeIfPresent([StoredDeckPage].self, forKey: .pages) ?? []
        rootPageIDs = try container.decodeIfPresent([String].self, forKey: .rootPageIDs) ?? []
    }
}

nonisolated private struct StoredDeckKeyConfiguration: Codable, Equatable {
    let id: Int
    let configuration: DeckKeyConfiguration
}

nonisolated private struct StoredDeckPage: Codable, Equatable {
    let id: String
    let parentID: String?
    let keys: [StoredDeckKeyConfiguration]
}
