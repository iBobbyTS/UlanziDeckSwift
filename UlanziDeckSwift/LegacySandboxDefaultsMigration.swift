import Foundation

nonisolated enum LegacySandboxDefaultsMigration {
    static let markerKey = "com.iBobby.UlanziDeckSwift.sandboxDefaultsMigration.v1"
    static let credentialIndexStorageKey =
        "\(UserDefaultsDeckConfigurationStore.defaultStorageKey).sub2APICredentialIDs"

    static var defaultSourceURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers/com.iBobby.UlanziDeckSwift")
            .appending(path: "Data/Library/Preferences/com.iBobby.UlanziDeckSwift.plist")
    }

    static func migrateIfNeeded(
        defaults: UserDefaults = .standard,
        sourceURL: URL = defaultSourceURL
    ) {
        guard !defaults.bool(forKey: markerKey) else {
            return
        }

        guard defaults.object(
            forKey: UserDefaultsDeckConfigurationStore.defaultStorageKey
        ) == nil else {
            defaults.set(true, forKey: markerKey)
            return
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            defaults.set(true, forKey: markerKey)
            return
        }

        guard let sourceData = try? Data(contentsOf: sourceURL),
        let sourceDefaults = try? PropertyListSerialization.propertyList(
            from: sourceData,
            options: [],
            format: nil
        ) as? [String: Any]
        else {
            return
        }

        let keys = [
            UserDefaultsDeckConfigurationStore.defaultStorageKey,
            UserDefaultsDeckConfigurationStore.defaultBrightnessStorageKey,
            UserDefaultsDeckConfigurationStore.defaultBrightnessFollowStorageKey,
            credentialIndexStorageKey,
        ]
        for key in keys {
            if let value = sourceDefaults[key] {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: markerKey)
    }
}
