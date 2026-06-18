import Foundation
import Darwin
import Testing
@testable import UlanziDeckSwift

struct UlanziDeckSwiftTests {
    @Test func h200PrototypeLayoutContainsFourteenNumberedKeys() {
        let layout = DeckGridLayout.h200Prototype

        #expect(layout.keys.map(\.id) == Array(1...14))
        #expect(layout.rows.map(\.count) == [5, 5, 4])
        #expect(layout.columnCount == 5)
        #expect(layout.keys.last?.columnSpan == 2)
        #expect(layout.keyID(forSequentialInputIndex: 0) == 1)
        #expect(layout.keyID(forSequentialInputIndex: 13) == 14)
        #expect(layout.keyID(forSequentialInputIndex: 14) == nil)
    }

    @Test func fileSingleInstanceLockerRejectsDuplicateBundleIdentifier() throws {
        let lockDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UlanziDeckSwiftTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: lockDirectory)
        }

        let secondLocker = FileSingleInstanceLocker(lockDirectory: lockDirectory)

        do {
            let firstLocker = FileSingleInstanceLocker(lockDirectory: lockDirectory)

            #expect(firstLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
            #expect(!secondLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
        }

        #expect(secondLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
    }

    @Test func singleInstanceGuardActivatesExistingApplicationWhenLockIsBusy() {
        let locker = FakeSingleInstanceLocker(results: [false])
        let activator = FakeExistingApplicationActivator()
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            activator: activator
        )

        #expect(!guardInstance.acquireOrActivateExisting())
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
        #expect(activator.activationRequests == [
            FakeExistingApplicationActivator.ActivationRequest(
                bundleIdentifier: "com.iBobby.UlanziDeckSwift",
                latestLaunchDate: nil
            )
        ])
    }

    @Test func singleInstanceGuardRejectsWhenOlderApplicationAlreadyExists() {
        let locker = FakeSingleInstanceLocker(results: [true])
        let activator = FakeExistingApplicationActivator(results: [true])
        let launchDate = Date(timeIntervalSince1970: 100)
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            activator: activator,
            currentLaunchDate: launchDate,
            existingApplicationGraceInterval: 2
        )

        #expect(!guardInstance.acquireOrActivateExisting())
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
        #expect(activator.activationRequests == [
            FakeExistingApplicationActivator.ActivationRequest(
                bundleIdentifier: "com.iBobby.UlanziDeckSwift",
                latestLaunchDate: launchDate.addingTimeInterval(-2)
            )
        ])
    }

    @Test func singleInstanceGuardAllowsLaunchWhenNoExistingApplicationIsFound() {
        let locker = FakeSingleInstanceLocker(results: [true])
        let activator = FakeExistingApplicationActivator(results: [false])
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            activator: activator,
            currentLaunchDate: Date(timeIntervalSince1970: 100),
            existingApplicationGraceInterval: 2
        )

        #expect(guardInstance.acquireOrActivateExisting())
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
    }

    @Test func appSkipsSingleInstanceGuardDuringTests() {
        #expect(UlanziDeckSwiftApp.isRunningTests)
    }

    @Test func previewGridMetricsKeepsWideKeyRowAligned() {
        let layout = DeckGridLayout.h200Prototype
        let metrics = DeckPreviewGridMetrics.h200
        let layoutMetrics = DeckPreviewLayoutMetrics.h200

        #expect(metrics.slotWidth(columnSpan: 1) == 82)
        #expect(metrics.slotWidth(columnSpan: 2) == 180)
        #expect(layout.rows.map { metrics.rowWidth(for: $0) } == [474, 474, 474])
        #expect(metrics.gridHeight(rowCount: layout.rows.count) == 278)
        #expect(layoutMetrics.gridContentWidth(for: layout) == 474)
        #expect(layoutMetrics.gridContentHeight(for: layout) == 278)
        #expect(layoutMetrics.deckSurfaceWidth(for: layout) == 530)
        #expect(layoutMetrics.deckSurfaceHeight(for: layout) == 334)
        #expect(layoutMetrics.previewAreaMinimumWidth(for: layout) == 586)
        #expect(layoutMetrics.previewAreaHeight(for: layout) == 434)
    }

    @Test func shortPressingAKeyDoesNotChangeUISelectionAndIncrementsTally() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 14)

        #expect(state.selectedKeyID == 1)
        #expect(state.tallyValue(for: 7) == 2)
        #expect(state.tallyValue(for: 14) == 1)
    }

    @Test func displayModelUsesTheSameTextAsTheStartupPackage() {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let displays = state.displays(for: layout)

        #expect(displays.map(\.title) == Array(repeating: "0", count: 14))
        #expect(displays.allSatisfy { $0.subtitle == "默认 0" })
        #expect(displays.first?.isSelected == true)
        #expect(displays.last?.isWide == true)
        #expect(displays.last?.devicePixelSize == H200DeviceTarget.smallWindowIconSize)
    }

    @Test func uiSelectionDoesNotChangeDisplayRenderIdentity() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let initiallySelectedIdentity = state.display(for: layout.keys[0]).renderIdentity

        state.select(keyID: 2)
        let unselectedIdentity = state.display(for: layout.keys[0]).renderIdentity
        state.triggerShortPress(keyID: 1)
        let updatedContentIdentity = state.display(for: layout.keys[0]).renderIdentity

        #expect(initiallySelectedIdentity == unselectedIdentity)
        #expect(initiallySelectedIdentity != updatedContentIdentity)
    }

    @Test func clearingFunctionMakesKeyEmptyAndInactive() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        let didClear = state.clearFunction(keyID: 7)
        let didBeginPress = state.beginPress(keyID: 7)
        let didTriggerShortPress = state.triggerShortPress(keyID: 7)
        let didReset = state.resetTally(keyID: 7)

        let display = state.display(for: layout.keys[6])
        #expect(didClear)
        #expect(!didBeginPress)
        #expect(!didTriggerShortPress)
        #expect(!didReset)
        #expect(state.selectedKeyID == 7)
        #expect(state.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(state.tallyValue(for: 7) == 0)
        #expect(state.pressedKeyIDs.isEmpty)
        #expect(display.title.isEmpty)
        #expect(display.subtitle.isEmpty)
    }

    @Test func unknownKeyDoesNotChangeTallyState() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 99)

        #expect(state.selectedKeyID == 1)
        #expect(state.configurations.values.allSatisfy { $0.tally.value == 0 })
        #expect(state.pressedKeyIDs.isEmpty)
    }

    @Test func tallyDefaultValueIsAlsoTheResetTarget() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.setTallyDefaultValue(12, for: 4)
        state.triggerShortPress(keyID: 4)
        state.resetTally(keyID: 4)

        #expect(state.selectedKeyID == 4)
        #expect(state.tallyDefaultValue(for: 4) == 12)
        #expect(state.tallyValue(for: 4) == 12)
    }

    @Test func openFolderFunctionDisplaysSelectedFolderName() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.openFolder, to: 5)
        state.setFolderPath("/Users/ibobby/Documents/Codex", for: 5)
        let display = state.display(for: layout.keys[4])

        #expect(display.title == "打开")
        #expect(display.subtitle == "Codex")
        #expect(state.folderPath(for: 5) == "/Users/ibobby/Documents/Codex")
    }

    @Test func connectSMBServerFunctionDisplaysNormalizedAddress() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.connectSMBServer, to: 5)
        state.setSMBServerAddress("smb://server.local/share", for: 5)
        let display = state.display(for: layout.keys[4])

        #expect(display.title == "连接")
        #expect(display.subtitle == "server.local/share")
        #expect(state.smbServerAddress(for: 5) == "server.local/share")
        #expect(state.configuration(for: 5)?.smbServer.fullURLString == "smb://server.local/share")
    }

    @Test func legacyBrightnessKeyFunctionIsNormalizedToNoFunction() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(
            layout: layout,
            configurations: [
                6: DeckKeyConfiguration(function: .brightness),
            ]
        )
        let display = state.display(for: layout.keys[5])
        let didBeginPress = state.beginPress(keyID: 6)

        #expect(state.configuration(for: 6)?.function == DeckKeyFunction.none)
        #expect(!didBeginPress)
        #expect(display.title.isEmpty)
        #expect(display.subtitle.isEmpty)
    }

    @Test func userDefaultsStoreRestoresSavedKeyConfiguration() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let layout = DeckGridLayout.h200Prototype
        let store = UserDefaultsDeckConfigurationStore(
            defaults: defaults,
            storageKey: "deckConfiguration",
            brightnessStorageKey: "brightness"
        )
        var state = DeckGridInteractionState(layout: layout)
        state.setTallyDefaultValue(6, for: 3)
        state.triggerShortPress(keyID: 3)
        state.clearFunction(keyID: 8)
        state.assign(.openFolder, to: 9)
        state.setFolderPath("/Users/ibobby/Documents", for: 9)
        state.assign(.connectSMBServer, to: 10)
        state.setSMBServerAddress("smb://nas.local/media", for: 10)

        store.saveInteractionState(state, for: layout)
        store.saveBrightnessPercent(140)

        let restored = try #require(store.loadInteractionState(for: layout))
        #expect(restored.tallyDefaultValue(for: 3) == 6)
        #expect(restored.tallyValue(for: 3) == 7)
        #expect(restored.configuration(for: 8)?.function == DeckKeyFunction.none)
        #expect(restored.configuration(for: 9)?.function == DeckKeyFunction.openFolder)
        #expect(restored.folderPath(for: 9) == "/Users/ibobby/Documents")
        #expect(restored.configuration(for: 10)?.function == DeckKeyFunction.connectSMBServer)
        #expect(restored.smbServerAddress(for: 10) == "nas.local/media")
        #expect(store.loadBrightnessPercent() == 100)
        #expect(restored.pressedKeyIDs.isEmpty)
        #expect(restored.selectedKeyID == 1)
    }

    @Test func userDefaultsStoreIgnoresBrokenConfigurationData() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "deckConfiguration"
        let store = UserDefaultsDeckConfigurationStore(defaults: defaults, storageKey: storageKey)
        defaults.set(Data("不是 JSON".utf8), forKey: storageKey)

        #expect(store.loadInteractionState(for: .h200Prototype) == nil)
    }

    @Test func h200ProtocolInterfaceMatchesObservedReportShape() {
        let identity = Self.protocolInterfaceIdentity()

        #expect(identity.isProtocolInterface)
    }

    @Test func h200KeyboardInterfaceIsNotProtocolInterface() {
        let identity = H200DeviceIdentity(
            vendorID: H200DeviceTarget.vendorID,
            productID: H200DeviceTarget.productID,
            locationID: 0x01124300,
            primaryUsagePage: 1,
            primaryUsage: 6,
            maxInputReportSize: 8,
            maxOutputReportSize: 1,
            serialNumber: "70973ca7355917c7",
            manufacturer: "rockchip",
            product: ""
        )

        #expect(!identity.isProtocolInterface)
    }

    @MainActor
    @Test func launchCheckShowsRetryAlertWhenH200IsMissing() {
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "未检测到 H200")
        #expect(syncer.sentDisplays.isEmpty)
    }

    @MainActor
    @Test func managerExclusiveAccessShowsOccupiedPortAlert() {
        let code = Self.exclusiveAccessReturnCode()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.communicationPortOccupied(code)]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()

        #expect(model.status == .communicationPortOccupied(code))
        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("有其他应用正在占用 H200 通信端口") == true)
        #expect(model.alert?.message.contains("kIOReturnExclusiveAccess") == true)
    }

    @Test func exclusiveAccessReturnCodeMeansOccupiedPort() {
        let code = Self.exclusiveAccessReturnCode()

        #expect(code.name == "kIOReturnExclusiveAccess")
        #expect(code.indicatesOccupiedPort)
    }

    @MainActor
    @Test func retryUpdatesStateWhenH200Appears() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 2048, packetCount: 2, displayCount: 14)),
        ])
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [
            .notConnected,
            .connected(connectedIdentity),
        ]), syncer: syncer, configurationStore: FakeDeckConfigurationStore())

        model.checkOnLaunch()
        model.retry()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.status == .connected(connectedIdentity))
        #expect(model.connectedDevice == connectedIdentity)
        #expect(model.syncSummary?.displayCount == 14)
        #expect(model.alert == nil)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func successfulLaunchSendsDisplaysMatchingTheVisibleGrid() {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: 14)),
        ])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()

        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.sentDisplays.first?.map(\.title) == Array(repeating: "0", count: 14))
        #expect(syncer.sentDisplays.first?.allSatisfy { $0.subtitle == "默认 0" } == true)
        #expect(syncer.sentDisplays.first?.last?.isWide == true)
        #expect(model.syncSummary?.packetCount == 4)
    }

    @MainActor
    @Test func launchUsesPersistedConfigurationWhenSyncingDevice() {
        let layout = DeckGridLayout.h200Prototype
        var persistedState = DeckGridInteractionState(layout: layout)
        persistedState.setTallyDefaultValue(4, for: 3)
        persistedState.triggerShortPress(keyID: 3)
        persistedState.clearFunction(keyID: 7)
        let store = FakeDeckConfigurationStore(loadedState: persistedState)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()

        #expect(model.interactionState.tallyDefaultValue(for: 3) == 4)
        #expect(model.interactionState.tallyValue(for: 3) == 5)
        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(syncer.sentDisplays.first?[2].title == "5")
        #expect(syncer.sentDisplays.first?[2].subtitle == "默认 4")
        #expect(syncer.sentDisplays.first?[6].title == "")
        #expect(syncer.sentDisplays.first?[6].subtitle == "")
    }

    @MainActor
    @Test func configurationChangesArePersisted() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 2)
        model.setSelectedTallyDefaultValue(3)
        syncer.emitInput(H200InputEvent(state: 1, index: 1, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 1, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        model.clearKeyFunction(keyID: 2)

        #expect(store.savedStates.count == 3)
        #expect(store.savedStates[0].tallyDefaultValue(for: 2) == 3)
        #expect(store.savedStates[1].tallyValue(for: 2) == 4)
        #expect(store.savedStates[2].configuration(for: 2)?.function == DeckKeyFunction.none)
    }

    @MainActor
    @Test func uiSelectionChangesParameterTargetWithoutSyncingDisplays() {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 8)

        #expect(model.interactionState.selectedKeyID == 8)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func clearingFunctionSyncsEmptyDisplayAndIgnoresPhysicalInput() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.clearKeyFunction(keyID: 7)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 7)
        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(model.interactionState.tallyValue(for: 7) == 0)
        #expect(model.interactionState.pressedKeyIDs.isEmpty)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 1)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "")
    }

    @MainActor
    @Test func selectingTheSameSidebarFunctionAgainClearsIt() {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 7)
        model.assignSelectedFunction(.tally)

        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 1)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "")
    }

    @MainActor
    @Test func sidebarFunctionCanRestoreClearedKey() {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.clearKeyFunction(keyID: 7)
        model.assignSelectedFunction(.tally)

        #expect(model.interactionState.selectedKeyID == 7)
        #expect(model.interactionState.configuration(for: 7)?.function == .tally)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 2)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "0")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "默认 0")
    }

    @MainActor
    @Test func selectingOpenFolderFunctionSyncsAndPersistsFolderPath() {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderPath("/Users/ibobby/Documents")

        #expect(model.interactionState.configuration(for: 4)?.function == DeckKeyFunction.openFolder)
        #expect(model.interactionState.folderPath(for: 4) == "/Users/ibobby/Documents")
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 2)
        #expect(syncer.partialDisplays.last?.map(\.id) == [4])
        #expect(syncer.partialDisplays.last?.first?.title == "打开")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "Documents")
        #expect(store.savedStates.last?.folderPath(for: 4) == "/Users/ibobby/Documents")
    }

    @MainActor
    @Test func selectingConnectSMBServerFunctionSyncsAndPersistsAddress() {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            smbServerConnector: FakeSMBServerConnector()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        model.setSelectedSMBServerAddress("smb://nas.local/media")

        #expect(model.interactionState.configuration(for: 4)?.function == DeckKeyFunction.connectSMBServer)
        #expect(model.interactionState.smbServerAddress(for: 4) == "nas.local/media")
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 2)
        #expect(syncer.partialDisplays.last?.map(\.id) == [4])
        #expect(syncer.partialDisplays.last?.first?.title == "连接")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "nas.local/media")
        #expect(store.savedStates.last?.smbServerAddress(for: 4) == "nas.local/media")
    }

    @MainActor
    @Test func topBrightnessSliderSendsLatestValueWithoutPilingUp() async throws {
        let syncer = FakeH200DeckSyncer(brightnessDelayNanoseconds: 100_000_000)
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        let sentDisplayCount = syncer.sentDisplays.count

        model.previewBrightnessPercent(10)
        model.previewBrightnessPercent(20)
        model.previewBrightnessPercent(30)
        model.commitBrightnessPercent(30)

        #expect(model.brightnessPercent == 30)
        #expect(store.savedBrightnessPercents == [30])
        try await Self.waitUntil {
            syncer.brightnessPercents == [10, 30]
                && syncer.sentDisplays.count == sentDisplayCount
        }
    }

    @MainActor
    @Test func topBrightnessSliderLoadsPersistedValue() {
        let store = FakeDeckConfigurationStore(loadedBrightnessPercent: 65)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        #expect(model.brightnessPercent == 65)
    }

    @MainActor
    @Test func successfulLaunchSendsPersistedBrightnessAfterStartup() async throws {
        let store = FakeDeckConfigurationStore(loadedBrightnessPercent: 65)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            syncer.brightnessPercents == [65]
        }
        #expect(model.brightnessPercent == 65)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func topBrightnessSliderFailureShowsAlert() async throws {
        let code = Self.exclusiveAccessReturnCode()
        let syncer = FakeH200DeckSyncer(brightnessFailures: [.communicationPortOccupied(code)])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        model.commitBrightnessPercent(25)
        try await Self.waitUntil {
            model.alert?.title == "H200 通信端口被占用"
        }

        #expect(syncer.brightnessPercents == [25])
        #expect(model.alert?.message.contains("有其他应用正在占用 H200 通信端口") == true)
    }

    @MainActor
    @Test func brightnessAdjustmentRequiresRunningAdjuster() {
        let adjuster = FakeBrightnessAdjuster()

        BrightnessAdjustmentRuntime.shared.register(adjuster)
        BrightnessAdjustmentRuntime.shared.unregister(adjuster)

        #expect(BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 25) == .appNotRunning)
        #expect(adjuster.appliedPercents.isEmpty)
    }

    @MainActor
    @Test func brightnessAdjustmentRequiresConnectedAndSyncedModel() {
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )
        BrightnessAdjustmentRuntime.shared.register(model)
        defer {
            BrightnessAdjustmentRuntime.shared.unregister(model)
        }

        #expect(BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 25) == .deviceNotReady)
        #expect(model.brightnessPercent == DeckBrightnessConfiguration.defaultPercent)
        #expect(store.savedBrightnessPercents.isEmpty)
    }

    @MainActor
    @Test func brightnessAdjustmentSendsWithoutPersisting() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )
        BrightnessAdjustmentRuntime.shared.register(model)
        defer {
            BrightnessAdjustmentRuntime.shared.unregister(model)
        }

        model.checkOnLaunch()
        let result = BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 35)

        #expect(result == .sent(35))
        #expect(model.brightnessPercent == 35)
        #expect(store.savedBrightnessPercents.isEmpty)
        try await Self.waitUntil {
            syncer.brightnessPercents == [35]
        }
    }

    @MainActor
    @Test func physicalButtonShortPressIncrementsTallyWithoutChangingUISelection() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 3)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 3)
        #expect(model.interactionState.tallyValue(for: 7) == 2)
    }

    @MainActor
    @Test func physicalButtonShortPressOpensConfiguredFolderWithoutSyncingDisplay() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderPath("/Users/ibobby/Documents")
        let sentDisplayCount = syncer.sentDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths == ["/Users/ibobby/Documents"])
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonOpenFolderWithoutFolderDoesNothing() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths.isEmpty)
    }

    @MainActor
    @Test func physicalButtonShortPressConnectsConfiguredSMBServerWithoutSyncingDisplay() async throws {
        let connector = FakeSMBServerConnector()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            smbServerConnector: connector
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        model.setSelectedSMBServerAddress("nas.local/media")
        let sentDisplayCount = syncer.sentDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(connector.connectedAddresses == ["nas.local/media"])
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonConnectSMBServerWithoutAddressDoesNothing() async throws {
        let connector = FakeSMBServerConnector()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            smbServerConnector: connector
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(connector.connectedAddresses.isEmpty)
    }

    @MainActor
    @Test func longPressOpenFolderIsNotSuppressedByTallyResetLogic() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener,
            longPressDurationNanoseconds: 10_000_000
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderPath("/Users/ibobby/Documents")
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 30_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths == ["/Users/ibobby/Documents"])
    }

    @MainActor
    @Test func physicalReleaseAndEncoderEventsDoNotTriggerGridPresses() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .release))
        syncer.emitInput(H200InputEvent(state: 1, index: 17, type: .encoder, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 1)
        #expect(model.interactionState.configurations.values.allSatisfy { $0.tally.value == 0 })
    }

    @MainActor
    @Test func longPressResetsTallyToConfiguredDefault() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            longPressDurationNanoseconds: 10_000_000
        )

        model.checkOnLaunch()
        model.setSelectedTallyDefaultValue(5)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 5_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 30_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.interactionState.tallyDefaultValue(for: 1) == 5)
        #expect(model.interactionState.tallyValue(for: 1) == 5)
        #expect(model.interactionState.pressedKeyIDs.isEmpty)
    }

    @MainActor
    @Test func syncFailureShowsPackageNotSentAlert() {
        let code = Self.exclusiveAccessReturnCode()
        let syncer = FakeH200DeckSyncer(results: [.failure(.communicationPortOccupied(code))])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()

        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("按键包尚未发送") == true)
        #expect(model.syncSummary == nil)
    }

    @MainActor
    @Test func buttonPackageManifestMatchesDisplays() throws {
        let displays = DeckGridInteractionState(layout: .h200Prototype).displays(for: .h200Prototype)
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: displays)
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let firstEntry = manifest["0_0"] as? [String: Any]
        let firstViewParam = (firstEntry?["ViewParam"] as? [[String: Any]])?.first
        let smallEntry = manifest["3_2"] as? [String: Any]
        let smallViewParam = (smallEntry?["ViewParam"] as? [[String: Any]])?.first

        #expect(package.displayCount == 14)
        #expect(Array(package.payload.prefix(4)) == [0x50, 0x4b, 0x03, 0x04])
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
        #expect(manifest.count == 14)
        #expect(firstViewParam?["Icon"] as? String == "Images/key_1.png")
        #expect(firstViewParam?["Text"] as? String == "")
        #expect(smallEntry?["SmallViewMode"] as? Int == 2)
        #expect(smallViewParam?["Icon"] as? String == "Images/key_14.png")
    }

    @Test func realButtonPackageBuilderCreatesSafePayload() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 7)
        state.setTallyDefaultValue(12, for: 14)

        let package = try H200ButtonPackageBuilder().buildPackage(displays: state.displays(for: layout))

        #expect(package.displayCount == 14)
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
    }

    @Test func realIconRendererCreatesPNGForWideDisplay() throws {
        let display = DeckGridInteractionState(layout: .h200Prototype)
            .displays(for: .h200Prototype)
            .last!

        let png = try H200ButtonIconRenderer().pngData(for: display)

        #expect(Array(png.prefix(4)) == [0x89, 0x50, 0x4e, 0x47])
        #expect(!png.isEmpty)
    }

    @Test func iconRendererDoesNotTintSelectedDisplay() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let selectedDisplay = state.display(for: layout.keys[0])
        state.select(keyID: 2)
        let unselectedDisplay = state.display(for: layout.keys[0])
        let renderer = H200ButtonIconRenderer()

        #expect(selectedDisplay.isSelected)
        #expect(!unselectedDisplay.isSelected)
        #expect(try renderer.pngData(for: selectedDisplay) == renderer.pngData(for: unselectedDisplay))
    }

    @Test func chunkedPacketsUseTheObservedH200FrameFormat() {
        let payload = Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2)

        let packets = H200PacketBuilder.buildChunkedPackets(command: H200Command.outSetButtons, payload: payload)

        #expect(packets.count == 2)
        #expect(packets.allSatisfy { $0.count == H200PacketBuilder.packetSize })
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(packets[0][4] == UInt8(payload.count & 0xff))
        #expect(packets[0][5] == UInt8((payload.count >> 8) & 0xff))
        #expect(packets[1][0] == 0xab)
        #expect(packets[1][1] == 0xab)
        #expect(packets[1][2] == 0x00)
    }

    @Test func startupPacketsSetButtonsThenSmallWindowBackgroundMode() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 14
        )

        let packets = H200StartupPacketBuilder.buildStartupPackets(package: package)
        let smallWindowPacket = packets.last!
        let smallWindowLength = Self.payloadLength(in: smallWindowPacket)
        let smallWindowPayload = smallWindowPacket.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + smallWindowLength))

        #expect(packets.count == 3)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(Array(smallWindowPacket.prefix(4)) == [0x7c, 0x7c, 0x00, 0x06])
        #expect(smallWindowPayload == H200SmallWindowDataPacketBuilder.backgroundModePayload)
        #expect(String(data: smallWindowPayload, encoding: .utf8) == "2|0|0|00:00:00|0|24H|")
    }

    @Test func partialUpdatePacketsUsePartialUpdateCommand() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 1
        )

        let packets = H200PartialUpdatePacketBuilder.buildPartialUpdatePackets(package: package)

        #expect(packets.count == 2)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x0d])
    }

    @MainActor
    @Test func partialButtonPackageManifestContainsOnlyRequestedDisplay() throws {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let display = state.display(for: layout.keys[6])
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: [display])
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let entry = manifest["1_1"] as? [String: Any]
        let viewParam = (entry?["ViewParam"] as? [[String: Any]])?.first

        #expect(package.displayCount == 1)
        #expect(manifest.count == 1)
        #expect(viewParam?["Icon"] as? String == "Images/key_7.png")
    }

    @Test func brightnessPacketUsesObservedSimpleFrame() {
        let packet = H200BrightnessPacketBuilder.packet(percent: 140)
        let payloadLength = Self.payloadLength(in: packet)
        let payload = packet.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + payloadLength))

        #expect(packet.count == H200PacketBuilder.packetSize)
        #expect(Array(packet.prefix(4)) == [0x7c, 0x7c, 0x00, 0x0a])
        #expect(String(data: payload, encoding: .utf8) == "100")
    }

    @Test func inputReportParserRecognizesButtonPressReports() {
        let report = Self.inputReport(state: 0x01, index: 13, type: 0x01, action: 0x01)

        let event = H200InputReportParser.parse(report)

        #expect(event == H200InputEvent(state: 0x01, index: 13, type: .button, action: .press))
        #expect(H200DeckInputMapper.keyID(for: event!, layout: .h200Prototype) == 14)
    }

    @Test func inputReportParserIgnoresUnknownReportsAndMapsRelease() {
        var wrongCommand = Self.inputReport(state: 0x01, index: 0, type: 0x01, action: 0x01)
        wrongCommand[3] = 0x02
        let release = Self.inputReport(state: 0x00, index: 0, type: 0x01, action: 0x00)

        let releaseEvent = H200InputReportParser.parse(release)

        #expect(H200InputReportParser.parse(wrongCommand) == nil)
        #expect(releaseEvent == H200InputEvent(state: 0x00, index: 0, type: .button, action: .release))
        #expect(H200DeckInputMapper.keyID(for: releaseEvent!, layout: .h200Prototype) == 1)
    }

    @MainActor
    @Test func smbConnectorFallsBackToWorkspaceWhenNetFSReturnsPermissionError() {
        let mounter = FakeNetFSMounter(status: Int(EPERM))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "smb://ibobby-nas.local")

        #expect(didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
    }

    @MainActor
    @Test func smbConnectorFallsBackToWorkspaceWhenAsyncNetFSCompletionReturnsPermissionError() {
        let mounter = FakeNetFSMounter(status: 0, completionStatus: Int(EPERM))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "smb://ibobby-nas.local")
        mounter.completePendingMount()

        #expect(didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
    }

    @MainActor
    @Test func smbConnectorDoesNotFallbackForOtherNetFSErrors() {
        let mounter = FakeNetFSMounter(status: Int(ENOENT))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "ibobby-nas.local")

        #expect(!didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.isEmpty)
    }

    private static func protocolInterfaceIdentity() -> H200DeviceIdentity {
        H200DeviceIdentity(
            vendorID: H200DeviceTarget.vendorID,
            productID: H200DeviceTarget.productID,
            locationID: 0x01124300,
            primaryUsagePage: H200DeviceTarget.primaryUsagePage,
            primaryUsage: H200DeviceTarget.primaryUsage,
            maxInputReportSize: H200DeviceTarget.reportSize,
            maxOutputReportSize: H200DeviceTarget.reportSize,
            serialNumber: "70973ca7355917c7",
            manufacturer: "rockchip",
            product: ""
        )
    }

    private static func exclusiveAccessReturnCode() -> HIDReturnCode {
        HIDReturnCode(rawValue: Int32(bitPattern: 0xe00002c5))
    }

    private static func payloadLength(in packet: Data) -> Int {
        Int(packet[4])
            | (Int(packet[5]) << 8)
            | (Int(packet[6]) << 16)
            | (Int(packet[7]) << 24)
    }

    private static func inputReport(state: UInt8, index: UInt8, type: UInt8, action: UInt8) -> Data {
        var report = Data()
        report.append(0x7c)
        report.append(0x7c)
        report.appendUInt16BE(H200Command.inButton)
        report.appendUInt32LE(4)
        report.append(state)
        report.append(index)
        report.append(type)
        report.append(action)
        report.append(Data(repeating: 0, count: H200DeviceTarget.reportSize - report.count))
        return report
    }

    private static func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0..<60 {
            if condition() {
                return
            }

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(condition())
    }
}

private final class FakeH200DeckSyncer: H200DeckSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [H200DeckSyncResult]
    private var brightnessResults: [H200DeckSyncFailure?]
    private var storedSentDisplays: [[DeckKeyDisplay]] = []
    private var storedPartialDisplays: [[DeckKeyDisplay]] = []
    private var storedBrightnessPercents: [Int] = []
    private var inputHandler: H200InputHandler?
    private let brightnessDelayNanoseconds: UInt64

    var sentDisplays: [[DeckKeyDisplay]] {
        locked { storedSentDisplays }
    }

    var partialDisplays: [[DeckKeyDisplay]] {
        locked { storedPartialDisplays }
    }

    var brightnessPercents: [Int] {
        locked { storedBrightnessPercents }
    }

    init(
        results: [H200DeckSyncResult] = [],
        brightnessFailures: [H200DeckSyncFailure] = [],
        brightnessResults: [H200DeckSyncFailure?]? = nil,
        brightnessDelayNanoseconds: UInt64 = 0
    ) {
        self.results = results
        self.brightnessResults = brightnessResults ?? brightnessFailures.map { Optional.some($0) }
        self.brightnessDelayNanoseconds = brightnessDelayNanoseconds
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        locked {
            storedSentDisplays.append(displays)

            guard !results.isEmpty else {
                return .success(H200DeckSyncSummary(
                    payloadByteCount: displays.count,
                    packetCount: 1,
                    displayCount: displays.count
                ))
            }

            return results.removeFirst()
        }
    }

    func sendPartialPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        locked {
            storedPartialDisplays.append(displays)

            return .success(H200DeckSyncSummary(
                payloadByteCount: displays.count,
                packetCount: 1,
                displayCount: displays.count
            ))
        }
    }

    func setBrightness(percent: Int) -> H200DeckSyncFailure? {
        if brightnessDelayNanoseconds > 0 {
            Thread.sleep(forTimeInterval: Double(brightnessDelayNanoseconds) / 1_000_000_000)
        }

        return locked {
            storedBrightnessPercents.append(percent)
            guard !brightnessResults.isEmpty else {
                return nil
            }

            return brightnessResults.removeFirst()
        }
    }

    func setInputHandler(_ handler: H200InputHandler?) {
        locked {
            inputHandler = handler
        }
    }

    func emitInput(_ event: H200InputEvent) {
        let handler = locked { inputHandler }
        handler?(event)
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private struct FakeH200ButtonIconRenderer: H200ButtonIconRendering {
    func pngData(for display: DeckKeyDisplay) throws -> Data {
        Data([0x89, 0x50, 0x4e, 0x47, UInt8(display.id)])
    }
}

private final class FakeH200Discovery: H200Discovering {
    private var results: [H200DiscoveryResult]

    init(results: [H200DiscoveryResult]) {
        self.results = results
    }

    func discoverH200() -> H200DiscoveryResult {
        guard !results.isEmpty else {
            return .notConnected
        }

        return results.removeFirst()
    }
}

private final class FakeDeckConfigurationStore: DeckConfigurationStoring {
    private let loadedState: DeckGridInteractionState?
    private let loadedBrightnessPercent: Int?
    private(set) var savedStates: [DeckGridInteractionState] = []
    private(set) var savedBrightnessPercents: [Int] = []

    init(loadedState: DeckGridInteractionState? = nil, loadedBrightnessPercent: Int? = nil) {
        self.loadedState = loadedState
        self.loadedBrightnessPercent = loadedBrightnessPercent
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        loadedState
    }

    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) {
        savedStates.append(state)
    }

    func loadBrightnessPercent() -> Int? {
        loadedBrightnessPercent
    }

    func saveBrightnessPercent(_ percent: Int) {
        savedBrightnessPercents.append(percent)
    }
}

private final class FakeSingleInstanceLocker: SingleInstanceLocking {
    private var results: [Bool]
    private(set) var requestedIdentifiers: [String] = []

    init(results: [Bool]) {
        self.results = results
    }

    func tryAcquire(identifier: String) -> Bool {
        requestedIdentifiers.append(identifier)
        guard !results.isEmpty else {
            return false
        }

        return results.removeFirst()
    }
}

private final class FakeExistingApplicationActivator: ExistingApplicationActivating {
    struct ActivationRequest: Equatable {
        let bundleIdentifier: String
        let latestLaunchDate: Date?
    }

    private var results: [Bool]
    private(set) var activationRequests: [ActivationRequest] = []

    init(results: [Bool] = []) {
        self.results = results
    }

    func activateExistingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> Bool {
        activationRequests.append(ActivationRequest(
            bundleIdentifier: bundleIdentifier,
            latestLaunchDate: latestLaunchDate
        ))
        guard !results.isEmpty else {
            return false
        }

        return results.removeFirst()
    }
}

@MainActor
private final class FakeBrightnessAdjuster: BrightnessAdjusting {
    var canAdjustBrightness = true
    private(set) var appliedPercents: [Int] = []

    func adjustBrightness(to percent: Int) {
        appliedPercents.append(percent)
    }
}

@MainActor
private final class FakeFinderFolderOpener: FinderFolderOpening {
    private(set) var openedPaths: [String] = []

    func openFolder(at path: String) -> Bool {
        openedPaths.append(path)
        return true
    }
}

@MainActor
private final class FakeSMBServerConnector: SMBServerConnecting {
    private(set) var connectedAddresses: [String] = []

    func connect(to address: String) -> Bool {
        connectedAddresses.append(address)
        return true
    }
}

@MainActor
private final class FakeNetFSMounter: NetFSMounting {
    private let status: Int
    private let completionStatus: Int?
    private var pendingCompletion: ((Int) -> Void)?
    private(set) var mountedURLs: [URL] = []

    init(status: Int, completionStatus: Int? = nil) {
        self.status = status
        self.completionStatus = completionStatus
    }

    func mount(url: URL, completion: @escaping (Int) -> Void) -> Int {
        mountedURLs.append(url)
        pendingCompletion = completion
        return status
    }

    func completePendingMount() {
        guard let completionStatus, let pendingCompletion else {
            return
        }

        pendingCompletion(completionStatus)
        self.pendingCompletion = nil
    }
}

@MainActor
private final class FakeSMBURLOpener: SMBURLOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
