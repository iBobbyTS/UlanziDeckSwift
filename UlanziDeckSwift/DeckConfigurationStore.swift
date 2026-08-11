import Foundation

nonisolated protocol DeckConfigurationStoring {
    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState?
    @discardableResult
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) -> DeckConfigurationSaveResult
    func loadBrightnessPercent() -> Int?
    func saveBrightnessPercent(_ percent: Int)
    func loadFollowsBuiltInDisplayBrightness() -> Bool
    func saveFollowsBuiltInDisplayBrightness(_ follows: Bool)
}

nonisolated enum DeckConfigurationSaveResult: Equatable {
    case success
    case credentialFailure(String)
}

extension DeckConfigurationStoring {
    nonisolated func loadBrightnessPercent() -> Int? { nil }
    nonisolated func saveBrightnessPercent(_ percent: Int) {}
    nonisolated func loadFollowsBuiltInDisplayBrightness() -> Bool { false }
    nonisolated func saveFollowsBuiltInDisplayBrightness(_ follows: Bool) {}
}

nonisolated struct UserDefaultsDeckConfigurationStore: DeckConfigurationStoring {
    static let defaultStorageKey = "com.iBobby.UlanziDeckSwift.h200.deckConfiguration.v1"
    static let defaultBrightnessStorageKey = "com.iBobby.UlanziDeckSwift.h200.brightness.v1"
    static let defaultBrightnessFollowStorageKey = "com.iBobby.UlanziDeckSwift.h200.brightnessFollow.v1"

    private let defaults: UserDefaults
    private let storageKey: String
    private let brightnessStorageKey: String
    private let brightnessFollowStorageKey: String
    private let credentialIndexStorageKey: String
    private let credentialStore: Sub2APICredentialStoring
    private let credentialBaseline = Sub2APICredentialPersistenceBaseline()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = Self.defaultStorageKey,
        brightnessStorageKey: String = Self.defaultBrightnessStorageKey,
        brightnessFollowStorageKey: String = Self.defaultBrightnessFollowStorageKey,
        credentialIndexStorageKey: String? = nil,
        credentialStore: Sub2APICredentialStoring = KeychainSub2APICredentialStore()
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.brightnessStorageKey = brightnessStorageKey
        self.brightnessFollowStorageKey = brightnessFollowStorageKey
        self.credentialIndexStorageKey = credentialIndexStorageKey ?? "\(storageKey).sub2APICredentialIDs"
        self.credentialStore = credentialStore
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        guard let data = defaults.data(forKey: storageKey) else {
            reconcileCredentialIndexAfterLoad(referencedCredentialIDs: [])
            return nil
        }

        guard let stored = try? decoder.decode(StoredDeckConfiguration.self, from: data) else {
            if Self.containsUnsupportedVersion(in: data),
               !Self.containsRecognizablePlaintextCredential(in: data) {
                return nil
            }

            discardStoredConfigurationAndTrackedCredentials()
            return nil
        }

        guard stored.layoutIdentifier == layout.identifier else {
            sanitizeLegacyCredentialsForUnmatchedLayout(in: stored, originalData: data)
            return nil
        }

        switch stored.version {
        case 1:
            var configurations: [Int: DeckKeyConfiguration] = [:]
            for key in stored.keys {
                configurations[key.id] = key.configuration
            }
            let normalizedState = DeckGridInteractionState(layout: layout, configurations: configurations)
            let state = hydrateSub2APICredentials(in: normalizedState, for: layout)
            persistSanitizedStoredConfiguration(storedConfiguration(for: state, layout: layout))
            reconcileCredentialIndexAfterLoad(in: state)
            return state

        case StoredDeckConfiguration.currentVersion:
            let pages = stored.pages.map { page in
                var configurations: [Int: DeckKeyConfiguration] = [:]
                for key in page.keys {
                    configurations[key.id] = key.configuration
                }
                return DeckGridPage(
                    id: page.id,
                    parentID: page.parentID,
                    configurations: configurations
                )
            }
            let normalizedState = DeckGridInteractionState(
                layout: layout,
                pages: pages,
                rootPageIDs: stored.rootPageIDs
            )
            let state = hydrateSub2APICredentials(in: normalizedState, for: layout)
            persistSanitizedStoredConfiguration(storedConfiguration(for: state, layout: layout))
            reconcileCredentialIndexAfterLoad(in: state)
            return state

        default:
            if Self.containsRecognizablePlaintextCredential(in: data) {
                discardStoredConfigurationAndTrackedCredentials()
            }
            return nil
        }
    }

    @discardableResult
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) -> DeckConfigurationSaveResult {
        let credentialResult = persistSub2APICredentials(in: state)
        let stored = storedConfiguration(for: state, layout: layout)
        guard let data = try? encoder.encode(stored) else {
            return .credentialFailure("无法编码按键配置")
        }

        defaults.set(data, forKey: storageKey)
        return credentialResult
    }

    private func storedConfiguration(
        for state: DeckGridInteractionState,
        layout: DeckGridLayout
    ) -> StoredDeckConfiguration {
        let pages = state.persistedPages.map { page in
            let keys = layout.keys.compactMap { key -> StoredDeckKeyConfiguration? in
                guard let configuration = page.configurations[key.id] else {
                    return nil
                }

                return StoredDeckKeyConfiguration(id: key.id, configuration: configuration)
            }

            return StoredDeckPage(id: page.id, parentID: page.parentID, keys: keys)
        }

        return StoredDeckConfiguration(
            layoutIdentifier: layout.identifier,
            pages: pages,
            rootPageIDs: state.rootPageIDs
        )
    }

    private func sanitizeLegacyCredentialsForUnmatchedLayout(
        in stored: StoredDeckConfiguration,
        originalData: Data
    ) {
        let allConfigurations = stored.keys.map(\.configuration)
            + stored.pages.flatMap { $0.keys.map(\.configuration) }
        let containsLegacyBearerKey = allConfigurations.contains {
            !$0.sub2API.bearerKey.isEmpty
        }
        let containsRecognizableCredential = containsLegacyBearerKey
            || Self.containsRecognizablePlaintextCredential(in: originalData)
        guard containsRecognizableCredential else {
            return
        }

        guard stored.version == 1 || stored.version == StoredDeckConfiguration.currentVersion else {
            // 未知版本无法无损重写；一旦识别出明文凭据，安全优先删除整个 payload。
            discardStoredConfigurationAndTrackedCredentials()
            return
        }

        var claimedCredentialIDs = Set(allConfigurations.compactMap { configuration -> String? in
            guard configuration.sub2API.bearerKey.isEmpty else {
                return nil
            }
            return normalizedCredentialID(configuration.sub2API.credentialID)
        })

        func sanitizedKey(_ key: StoredDeckKeyConfiguration) -> StoredDeckKeyConfiguration {
            var configuration = key.configuration
            if !configuration.sub2API.bearerKey.isEmpty {
                for var dataSource in configuration.allSub2APIDataSourceConfigurations {
                    hydrateSub2APICredential(
                        in: &dataSource,
                        claimedCredentialIDs: &claimedCredentialIDs
                    )
                    configuration.sub2APIDataSourceConfiguration = dataSource
                }
            }
            return StoredDeckKeyConfiguration(id: key.id, configuration: configuration)
        }

        let sanitized = StoredDeckConfiguration(
            version: stored.version,
            layoutIdentifier: stored.layoutIdentifier,
            keys: stored.keys.map(sanitizedKey),
            pages: stored.pages.map { page in
                StoredDeckPage(
                    id: page.id,
                    parentID: page.parentID,
                    keys: page.keys.map(sanitizedKey)
                )
            },
            rootPageIDs: stored.rootPageIDs
        )
        persistSanitizedStoredConfiguration(sanitized)

        let migratedCredentialIDs = Set(
            (sanitized.keys + sanitized.pages.flatMap(\.keys)).compactMap { key in
                normalizedCredentialID(key.configuration.sub2API.credentialID)
            }
        )
        let previouslyTrackedCredentialIDs = Set(
            defaults.stringArray(forKey: credentialIndexStorageKey) ?? []
        )
        defaults.set(
            previouslyTrackedCredentialIDs.union(migratedCredentialIDs).sorted(),
            forKey: credentialIndexStorageKey
        )
    }

    private static func containsRecognizablePlaintextCredential(in data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }

        return containsRecognizablePlaintextCredential(in: object)
    }

    private static func containsUnsupportedVersion(in data: Data) -> Bool {
        guard let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawVersion = dictionary["version"],
              !(rawVersion is Bool),
              let version = rawVersion as? Int
        else {
            return false
        }

        return version != 1 && version != StoredDeckConfiguration.currentVersion
    }

    private static func containsRecognizablePlaintextCredential(in object: Any) -> Bool {
        if let dictionary = object as? [String: Any] {
            if let bearerKey = dictionary["bearerKey"] as? String,
               !bearerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }

            if let smbServer = dictionary["smbServer"] as? [String: Any],
               let address = smbServer["address"] as? String,
               DeckKeySMBServerConfiguration.containsUserInfo(in: address) {
                return true
            }

            return dictionary.values.contains {
                containsRecognizablePlaintextCredential(in: $0)
            }
        }

        if let array = object as? [Any] {
            return array.contains {
                containsRecognizablePlaintextCredential(in: $0)
            }
        }

        return false
    }

    private func hydrateSub2APICredentials(
        in state: DeckGridInteractionState,
        for layout: DeckGridLayout
    ) -> DeckGridInteractionState {
        var claimedCredentialIDs: Set<String> = []
        let pages = state.persistedPages.map { page in
            var configurations = page.configurations
            for key in layout.keys {
                guard var configuration = configurations[key.id] else {
                    continue
                }
                for var dataSource in configuration.allSub2APIDataSourceConfigurations {
                    hydrateSub2APICredential(
                        in: &dataSource,
                        claimedCredentialIDs: &claimedCredentialIDs
                    )
                    configuration.sub2APIDataSourceConfiguration = dataSource
                }
                configurations[key.id] = configuration
            }
            return DeckGridPage(
                id: page.id,
                parentID: page.parentID,
                configurations: configurations
            )
        }

        return DeckGridInteractionState(
            layout: layout,
            pages: pages,
            rootPageIDs: state.rootPageIDs
        )
    }

    private func hydrateSub2APICredential(
        in dataSource: inout Sub2APIDataSourceConfiguration,
        claimedCredentialIDs: inout Set<String>
    ) {
        let legacyBearerKey = dataSource.bearerKey
        if !legacyBearerKey.isEmpty {
            let existingCredentialID = normalizedCredentialID(dataSource.credentialID)
            let credentialID: String
            if let existingCredentialID,
               let persisted = credentialBaseline.persistedBearerKey(credentialID: existingCredentialID),
               persisted != legacyBearerKey {
                credentialID = UUID().uuidString
            } else {
                credentialID = existingCredentialID ?? UUID().uuidString
            }
            do {
                if credentialBaseline.persistedBearerKey(credentialID: credentialID) != legacyBearerKey {
                    try credentialStore.saveBearerKey(legacyBearerKey, credentialID: credentialID)
                }
                credentialBaseline.recordPersistedBearerKey(
                    legacyBearerKey,
                    credentialID: credentialID
                )
                dataSource.credentialID = credentialID
                claimedCredentialIDs.insert(credentialID)
            } catch {
                dataSource.bearerKey = ""
                dataSource.credentialID = nil
            }
            return
        }

        guard let credentialID = normalizedCredentialID(dataSource.credentialID) else {
            dataSource.bearerKey = ""
            dataSource.credentialID = nil
            return
        }

        guard claimedCredentialIDs.contains(credentialID) else {
            claimedCredentialIDs.insert(credentialID)
            do {
                guard let bearerKey = try credentialStore.loadBearerKey(credentialID: credentialID),
                      !bearerKey.isEmpty
                else {
                    credentialBaseline.remove(credentialID: credentialID)
                    dataSource.bearerKey = ""
                    dataSource.credentialID = nil
                    return
                }

                credentialBaseline.recordPersistedBearerKey(
                    bearerKey,
                    credentialID: credentialID
                )
                dataSource.credentialID = credentialID
                dataSource.bearerKey = bearerKey
            } catch {
                credentialBaseline.remove(credentialID: credentialID)
                dataSource.credentialID = credentialID
                dataSource.bearerKey = ""
                NSLog("无法从 Keychain 加载 Sub2API Bearer Key：%@", String(describing: error))
            }
            return
        }

        guard let bearerKey = credentialBaseline.persistedBearerKey(credentialID: credentialID)
        else {
            dataSource.bearerKey = ""
            dataSource.credentialID = nil
            return
        }

        // 同一 credential ID 的多个消费者是合法共享，不再人为复制 Keychain 项。
        dataSource.bearerKey = bearerKey
        dataSource.credentialID = credentialID
    }

    private func normalizedCredentialID(_ credentialID: String?) -> String? {
        guard let credentialID,
              !credentialID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return credentialID
    }

    private func persistSub2APICredentials(in state: DeckGridInteractionState) -> DeckConfigurationSaveResult {
        var referencedCredentialIDs: Set<String> = []
        // 一个 credential ID 只有一个逻辑 owner。按稳定的页面/按键顺序选定
        // 首个持有者，其他共享消费者即使仍带着刷新前的 bearer 也没有写权限。
        var bearerCandidates: [String: [String]] = [:]
        for page in state.persistedPages {
            for keyID in page.configurations.keys.sorted() {
                guard let configuration = page.configurations[keyID] else { continue }
                for dataSource in configuration.allSub2APIDataSourceConfigurations {
                    guard let credentialID = normalizedCredentialID(dataSource.credentialID) else {
                        continue
                    }
                    referencedCredentialIDs.insert(credentialID)
                    guard !dataSource.bearerKey.isEmpty else { continue }
                    bearerCandidates[credentialID, default: []].append(dataSource.bearerKey)
                }
            }
        }

        var firstErrorMessage: String?
        var credentialWriteFailed = false
        for credentialID in bearerCandidates.keys.sorted() {
            guard let bearerKey = bearerCandidates[credentialID]?.first,
                  !credentialBaseline.matchesPersistedBearerKey(
                    bearerKey,
                    credentialID: credentialID
                  )
            else { continue }

            do {
                try credentialStore.saveBearerKey(bearerKey, credentialID: credentialID)
                credentialBaseline.recordPersistedBearerKey(bearerKey, credentialID: credentialID)
            } catch {
                credentialWriteFailed = true
                NSLog("无法保存 Sub2API Bearer Key 到 Keychain：%@", String(describing: error))
                firstErrorMessage = firstErrorMessage ?? "无法安全保存 Bearer Key：\(error.localizedDescription)"
            }
        }

        let previousCredentialIDs = Set(defaults.stringArray(forKey: credentialIndexStorageKey) ?? [])
        var trackedCredentialIDs = referencedCredentialIDs
        if credentialWriteFailed {
            trackedCredentialIDs.formUnion(previousCredentialIDs)
        } else {
            for credentialID in previousCredentialIDs.subtracting(referencedCredentialIDs) {
                do {
                    try credentialStore.deleteBearerKey(credentialID: credentialID)
                    credentialBaseline.remove(credentialID: credentialID)
                } catch {
                    trackedCredentialIDs.insert(credentialID)
                    NSLog("无法从 Keychain 删除 Sub2API Bearer Key：%@", String(describing: error))
                    firstErrorMessage = firstErrorMessage ?? "无法安全删除 Bearer Key：\(error.localizedDescription)"
                }
            }
        }
        defaults.set(trackedCredentialIDs.sorted(), forKey: credentialIndexStorageKey)
        if let firstErrorMessage {
            return .credentialFailure(firstErrorMessage)
        }
        return .success
    }

    private func reconcileCredentialIndexAfterLoad(in state: DeckGridInteractionState) {
        let referencedCredentialIDs = Set(state.persistedPages.flatMap { page in
            page.configurations.values.flatMap { configuration in
                configuration.allSub2APIDataSourceConfigurations.compactMap { dataSource in
                    normalizedCredentialID(dataSource.credentialID)
                }
            }
        })

        reconcileCredentialIndexAfterLoad(referencedCredentialIDs: referencedCredentialIDs)
    }

    private func reconcileCredentialIndexAfterLoad(referencedCredentialIDs: Set<String>) {
        let previousCredentialIDs = Set(defaults.stringArray(forKey: credentialIndexStorageKey) ?? [])
        var trackedCredentialIDs = referencedCredentialIDs
        for credentialID in previousCredentialIDs.subtracting(referencedCredentialIDs) {
            do {
                try credentialStore.deleteBearerKey(credentialID: credentialID)
                credentialBaseline.remove(credentialID: credentialID)
            } catch {
                trackedCredentialIDs.insert(credentialID)
                NSLog("加载配置时无法清理 Sub2API Bearer Key：%@", String(describing: error))
            }
        }
        defaults.set(trackedCredentialIDs.sorted(), forKey: credentialIndexStorageKey)
    }

    private func discardStoredConfigurationAndTrackedCredentials() {
        defaults.removeObject(forKey: storageKey)
        reconcileCredentialIndexAfterLoad(referencedCredentialIDs: [])
    }

    private func persistSanitizedStoredConfiguration(_ stored: StoredDeckConfiguration) {
        if let sanitizedData = try? encoder.encode(stored) {
            defaults.set(sanitizedData, forKey: storageKey)
        } else {
            // 安全优先：绝不保留仍可能含旧版明文 Bearer Key 的 payload。
            defaults.removeObject(forKey: storageKey)
        }
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

    func loadFollowsBuiltInDisplayBrightness() -> Bool {
        defaults.bool(forKey: brightnessFollowStorageKey)
    }

    func saveFollowsBuiltInDisplayBrightness(_ follows: Bool) {
        defaults.set(follows, forKey: brightnessFollowStorageKey)
    }
}

nonisolated private final class Sub2APICredentialPersistenceBaseline: @unchecked Sendable {
    private let lock = NSLock()
    private var persistedBearerKeys: [String: String] = [:]

    func persistedBearerKey(credentialID: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return persistedBearerKeys[credentialID]
    }

    func matchesPersistedBearerKey(_ bearerKey: String, credentialID: String) -> Bool {
        persistedBearerKey(credentialID: credentialID) == bearerKey
    }

    func recordPersistedBearerKey(_ bearerKey: String, credentialID: String) {
        lock.lock()
        persistedBearerKeys[credentialID] = bearerKey
        lock.unlock()
    }

    func remove(credentialID: String) {
        lock.lock()
        persistedBearerKeys[credentialID] = nil
        lock.unlock()
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

    init(
        version: Int,
        layoutIdentifier: String,
        keys: [StoredDeckKeyConfiguration],
        pages: [StoredDeckPage],
        rootPageIDs: [String]
    ) {
        self.version = version
        self.layoutIdentifier = layoutIdentifier
        self.keys = keys
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

    enum CodingKeys: CodingKey {
        case id
        case configuration
    }

    init(id: Int, configuration: DeckKeyConfiguration) {
        self.id = id
        self.configuration = configuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        configuration = (try? container.decode(
            DeckKeyConfiguration.self,
            forKey: .configuration
        )) ?? .empty
    }
}

nonisolated private struct StoredDeckPage: Codable, Equatable {
    let id: String
    let parentID: String?
    let keys: [StoredDeckKeyConfiguration]
}
