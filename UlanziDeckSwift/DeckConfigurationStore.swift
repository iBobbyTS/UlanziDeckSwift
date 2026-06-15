import Foundation

nonisolated protocol DeckConfigurationStoring {
    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState?
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout)
}

nonisolated struct UserDefaultsDeckConfigurationStore: DeckConfigurationStoring {
    static let defaultStorageKey = "com.iBobby.UlanziDeckSwift.h200.deckConfiguration.v1"

    private let defaults: UserDefaults
    private let storageKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, storageKey: String = Self.defaultStorageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? decoder.decode(StoredDeckConfiguration.self, from: data),
              stored.version == StoredDeckConfiguration.currentVersion,
              stored.layoutIdentifier == layout.identifier
        else {
            return nil
        }

        var configurations: [Int: DeckKeyConfiguration] = [:]
        for key in stored.keys {
            configurations[key.id] = key.configuration
        }

        return DeckGridInteractionState(layout: layout, configurations: configurations)
    }

    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) {
        let keys = layout.keys.compactMap { key -> StoredDeckKeyConfiguration? in
            guard let configuration = state.configuration(for: key.id) else {
                return nil
            }

            return StoredDeckKeyConfiguration(id: key.id, configuration: configuration)
        }

        let stored = StoredDeckConfiguration(layoutIdentifier: layout.identifier, keys: keys)
        guard let data = try? encoder.encode(stored) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

nonisolated private struct StoredDeckConfiguration: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let layoutIdentifier: String
    let keys: [StoredDeckKeyConfiguration]

    init(layoutIdentifier: String, keys: [StoredDeckKeyConfiguration]) {
        version = Self.currentVersion
        self.layoutIdentifier = layoutIdentifier
        self.keys = keys
    }
}

nonisolated private struct StoredDeckKeyConfiguration: Codable, Equatable {
    let id: Int
    let configuration: DeckKeyConfiguration
}
