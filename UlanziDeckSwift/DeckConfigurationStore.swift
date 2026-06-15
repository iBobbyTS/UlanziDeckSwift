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
