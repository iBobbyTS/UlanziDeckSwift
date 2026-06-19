import Foundation

nonisolated protocol DeckConfigurationStoring {
    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState?
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout)
    func loadBrightnessPercent() -> Int?
    func saveBrightnessPercent(_ percent: Int)
    func loadButtonBackgroundDimmingEnabled() -> Bool?
    func saveButtonBackgroundDimmingEnabled(_ enabled: Bool)
}

extension DeckConfigurationStoring {
    nonisolated func loadBrightnessPercent() -> Int? { nil }
    nonisolated func saveBrightnessPercent(_ percent: Int) {}
    nonisolated func loadButtonBackgroundDimmingEnabled() -> Bool? { nil }
    nonisolated func saveButtonBackgroundDimmingEnabled(_ enabled: Bool) {}
}

nonisolated struct UserDefaultsDeckConfigurationStore: DeckConfigurationStoring {
    static let defaultStorageKey = "com.iBobby.UlanziDeckSwift.h200.deckConfiguration.v1"
    static let defaultBrightnessStorageKey = "com.iBobby.UlanziDeckSwift.h200.brightness.v1"
    static let defaultButtonBackgroundDimmingStorageKey = "com.iBobby.UlanziDeckSwift.h200.buttonBackgroundDimming.v1"

    private let defaults: UserDefaults
    private let storageKey: String
    private let brightnessStorageKey: String
    private let buttonBackgroundDimmingStorageKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = Self.defaultStorageKey,
        brightnessStorageKey: String = Self.defaultBrightnessStorageKey,
        buttonBackgroundDimmingStorageKey: String = Self.defaultButtonBackgroundDimmingStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.brightnessStorageKey = brightnessStorageKey
        self.buttonBackgroundDimmingStorageKey = buttonBackgroundDimmingStorageKey
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
            return DeckGridInteractionState(layout: layout, pages: pages)

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

        let stored = StoredDeckConfiguration(layoutIdentifier: layout.identifier, pages: pages)
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

    func loadButtonBackgroundDimmingEnabled() -> Bool? {
        guard defaults.object(forKey: buttonBackgroundDimmingStorageKey) != nil else {
            return nil
        }

        return defaults.bool(forKey: buttonBackgroundDimmingStorageKey)
    }

    func saveButtonBackgroundDimmingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: buttonBackgroundDimmingStorageKey)
    }
}

nonisolated private struct StoredDeckConfiguration: Codable, Equatable {
    static let currentVersion = 2

    let version: Int
    let layoutIdentifier: String
    let keys: [StoredDeckKeyConfiguration]
    let pages: [StoredDeckPage]

    init(layoutIdentifier: String, pages: [StoredDeckPage]) {
        version = Self.currentVersion
        self.layoutIdentifier = layoutIdentifier
        keys = []
        self.pages = pages
    }

    enum CodingKeys: CodingKey {
        case version
        case layoutIdentifier
        case keys
        case pages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        layoutIdentifier = try container.decode(String.self, forKey: .layoutIdentifier)
        keys = try container.decodeIfPresent([StoredDeckKeyConfiguration].self, forKey: .keys) ?? []
        pages = try container.decodeIfPresent([StoredDeckPage].self, forKey: .pages) ?? []
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
