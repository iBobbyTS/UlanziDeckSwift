import AppKit
import Combine
import Foundation

private nonisolated struct RuntimeSlotID: Hashable {
    let pageID: String
    let keyID: Int
}

private nonisolated struct RuntimeInstanceID: Hashable {
    let rawValue: Int
}

@MainActor
final class H200ConnectionModel: ObservableObject {
    @Published private(set) var status: H200ConnectionStatus = .checking
    @Published private(set) var syncSummary: H200DeckSyncSummary?
    @Published private(set) var interactionState = DeckGridInteractionState(layout: .h200Prototype)
    @Published private(set) var brightnessPercent = DeckBrightnessConfiguration.defaultPercent
    @Published private(set) var mihoyoLoginState: MihoyoLoginState = .notLoggedIn
    @Published var alert: H200ConnectionAlert?

    private let layout = DeckGridLayout.h200Prototype
    private let discovery: H200Discovering
    private let syncer: H200DeckSyncing
    private let configurationStore: DeckConfigurationStoring
    private let folderOpener: FinderFolderOpening
    private let fileOpener: FinderFileOpening
    private let webPageOpener: WebPageOpening
    private let webPageMetadataFetcher: WebPageMetadataFetching
    private let smbServerConnector: SMBServerConnecting
    private let sub2APIFetcher: Sub2APIFetching
    private let mihoyoGameService: MihoyoGameServicing
    private let mihoyoSessionStore: MihoyoSessionStoring
    private var hasPersistedBrightnessPercent: Bool
    private var mihoyoSession: MihoyoLoginSession?
    private let longPressDurationNanoseconds: UInt64
    private let mihoyoLoginPollNanoseconds: UInt64
    private let deviceCommandQueue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.H200DeviceCommands")
    private var longPressTasks: [Int: Task<Void, Never>] = [:]
    private var longPressResetKeyIDs: Set<Int> = []
    private var brightnessUpdateRevision = 0
    private var brightnessUpdateInProgress = false
    private var latestBrightnessUpdate: BrightnessUpdateRequest?
    private var deviceCommandGeneration = 0
    private var displayRevision = 0
    private var needsFullDisplaySyncAfterStartup = false
    private var nextRuntimeInstanceRawValue = 0
    private var runtimeInstancesBySlot: [RuntimeSlotID: RuntimeInstanceID] = [:]
    private var runtimeSlotsByInstance: [RuntimeInstanceID: RuntimeSlotID] = [:]
    private var runtimeKindsByInstance: [RuntimeInstanceID: DeckKeyScheduledRuntime] = [:]
    private var sub2APITimers: [RuntimeInstanceID: Timer] = [:]
    private var sub2APINextFireNanoseconds: [RuntimeInstanceID: UInt64] = [:]
    private var sub2APIFetchTasks: [RuntimeInstanceID: Task<Void, Never>] = [:]
    private var sub2APIGroupListTasks: [RuntimeInstanceID: Task<Void, Never>] = [:]
    private var sub2APIGroupListRefreshTasks: [RuntimeInstanceID: Task<Void, Never>] = [:]
    private var sub2APIGroupListRefreshFireNanoseconds: [RuntimeInstanceID: UInt64] = [:]
    private var sub2APIGroupListLastRequestNanoseconds: [RuntimeInstanceID: UInt64] = [:]
    private var sub2APITokenPausedInstances: Set<RuntimeInstanceID> = []
    private var webPageMetadataTasks: [Int: Task<Void, Never>] = [:]
    private var webPageMetadataFetchedURLStrings: [Int: String] = [:]
    private var mihoyoLoginTask: Task<Void, Never>?
    private var mihoyoGameTimers: [RuntimeInstanceID: Timer] = [:]
    private var mihoyoGameNextFireNanoseconds: [RuntimeInstanceID: UInt64] = [:]
    private var mihoyoGameFetchTasks: [RuntimeInstanceID: Task<Void, Never>] = [:]
    private let sub2APIRefreshSecondDuration: TimeInterval
    private let sub2APIGroupListMinimumIntervalNanoseconds: UInt64
    private let mihoyoGameRefreshMinuteDuration: TimeInterval

    private struct BrightnessUpdateRequest {
        let percent: Int
    }

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        folderOpener: FinderFolderOpening? = nil,
        fileOpener: FinderFileOpening? = nil,
        webPageOpener: WebPageOpening? = nil,
        webPageMetadataFetcher: WebPageMetadataFetching = WebPageMetadataFetcher(),
        smbServerConnector: SMBServerConnecting? = nil,
        sub2APIFetcher: Sub2APIFetching = Sub2APIFetcher(),
        mihoyoGameService: MihoyoGameServicing = MihoyoGameClient(),
        mihoyoSessionStore: MihoyoSessionStoring = KeychainMihoyoSessionStore(),
        longPressDurationNanoseconds: UInt64 = 1_000_000_000,
        mihoyoLoginPollNanoseconds: UInt64 = 2_000_000_000,
        sub2APIRefreshSecondDuration: TimeInterval = 1,
        sub2APIGroupListMinimumIntervalNanoseconds: UInt64 = 2_000_000_000,
        mihoyoGameRefreshMinuteDuration: TimeInterval = 60
    ) {
        self.discovery = discovery
        self.syncer = syncer
        self.configurationStore = configurationStore
        self.folderOpener = folderOpener ?? FinderFolderOpener()
        self.fileOpener = fileOpener ?? FinderFileOpener()
        self.webPageOpener = webPageOpener ?? WebPageOpener()
        self.webPageMetadataFetcher = webPageMetadataFetcher
        self.smbServerConnector = smbServerConnector ?? SMBServerConnector()
        self.sub2APIFetcher = sub2APIFetcher
        self.mihoyoGameService = mihoyoGameService
        self.mihoyoSessionStore = mihoyoSessionStore
        self.longPressDurationNanoseconds = longPressDurationNanoseconds
        self.mihoyoLoginPollNanoseconds = mihoyoLoginPollNanoseconds
        self.sub2APIRefreshSecondDuration = sub2APIRefreshSecondDuration
        self.sub2APIGroupListMinimumIntervalNanoseconds = sub2APIGroupListMinimumIntervalNanoseconds
        self.mihoyoGameRefreshMinuteDuration = mihoyoGameRefreshMinuteDuration
        interactionState = configurationStore.loadInteractionState(for: layout) ?? DeckGridInteractionState(layout: layout)
        let loadedBrightnessPercent = configurationStore.loadBrightnessPercent()
        hasPersistedBrightnessPercent = loadedBrightnessPercent != nil
        brightnessPercent = loadedBrightnessPercent ?? DeckBrightnessConfiguration.defaultPercent
        if brightnessPercent == 0 {
            syncer.setInternalRefreshPaused(true)
        }
        mihoyoSession = mihoyoSessionStore.loadSession()
        if let mihoyoSession {
            mihoyoLoginState = .loggedIn(accountID: mihoyoSession.accountID)
        }
        self.syncer.setInputHandler { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleInputEvent(event)
            }
        }
    }

    deinit {
        let syncer = syncer
        mihoyoLoginTask?.cancel()
        for timer in sub2APITimers.values {
            timer.invalidate()
        }
        for task in sub2APIFetchTasks.values {
            task.cancel()
        }
        for task in sub2APIGroupListTasks.values {
            task.cancel()
        }
        for task in sub2APIGroupListRefreshTasks.values {
            task.cancel()
        }
        for task in webPageMetadataTasks.values {
            task.cancel()
        }
        for timer in mihoyoGameTimers.values {
            timer.invalidate()
        }
        for task in mihoyoGameFetchTasks.values {
            task.cancel()
        }
        syncer.setInputHandler(nil)
        deviceCommandQueue.async {
            syncer.close()
        }
    }

    var connectedDevice: H200DeviceIdentity? {
        if case let .connected(device) = status {
            return device
        }

        return nil
    }

    func checkOnLaunch() {
        guard status == .checking else {
            return
        }

        refresh()
        if canRunInternalRefresh, mihoyoSession != nil {
            refreshAssignedMihoyoGameStatuses()
        }
    }

    func retry() {
        alert = nil
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func selectKey(keyID: Int) {
        interactionState.select(keyID: keyID)
    }

    func clearKeyFunction(keyID: Int) {
        guard interactionState.canDeleteFunction(keyID: keyID) else {
            return
        }

        cancelWebPageMetadataTask(for: keyID)
        webPageMetadataFetchedURLStrings[keyID] = nil
        destroyRuntimeInstance(for: keyID, clearsConfigurationRuntimeState: true)
        guard interactionState.clearFunction(keyID: keyID) else {
            return
        }

        reconcileRuntimeInstancesWithInteractionState()
        persistCurrentConfiguration()
        syncKeyDisplay(keyID: keyID)
    }

    func swapSquareKeyConfigurations(sourceKeyID: Int, targetKeyID: Int) {
        guard interactionState.canSwapSquareConfigurations(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID) else {
            return
        }

        let pageID = interactionState.currentPageID
        _ = ensureRuntimeInstance(for: sourceKeyID)
        _ = ensureRuntimeInstance(for: targetKeyID)
        cancelLongPressRuntime(for: sourceKeyID)
        cancelLongPressRuntime(for: targetKeyID)
        cancelWebPageMetadataTask(for: sourceKeyID)
        cancelWebPageMetadataTask(for: targetKeyID)
        webPageMetadataFetchedURLStrings[sourceKeyID] = nil
        webPageMetadataFetchedURLStrings[targetKeyID] = nil
        guard interactionState.swapSquareConfigurations(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID) else {
            return
        }
        swapRuntimeInstances(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID, pageID: pageID)
        reconcileRuntimeInstancesWithInteractionState()

        persistCurrentConfiguration()
        resumeCurrentPageRuntime()
        syncKeyDisplays(keyIDs: [sourceKeyID, targetKeyID])
    }

    func navigateKey(keyID: Int) {
        switch interactionState.configuration(for: keyID)?.function {
        case .pageFolder:
            enterPageFolder(for: keyID)
        case .pageBack:
            goBackPage()
        case .previousPage, .nextPage:
            return
        default:
            return
        }
    }

    func setKeyDisplayMode(_ displayMode: DeckKeyDisplayMode, for keyID: Int) {
        guard interactionState.setDisplayMode(displayMode, for: keyID) else {
            return
        }

        if displayMode != .function {
            if let instanceID = runtimeInstanceID(for: keyID) {
                pauseRuntimeInstance(instanceID)
            }
        } else {
            resumeCurrentPageRuntime()
        }
        reconcileRuntimeInstancesWithInteractionState()
        persistCurrentConfiguration()
        syncKeyDisplay(keyID: keyID)
    }

    private func enterPageFolder(for keyID: Int) {
        guard interactionState.pageID(for: keyID) != nil else {
            return
        }

        cancelCurrentPageRuntime()
        cancelAllWebPageMetadataTasks()
        webPageMetadataFetchedURLStrings.removeAll()
        guard interactionState.enterPageFolder(keyID: keyID) else {
            startCurrentPageRuntime()
            return
        }

        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    private func goBackPage() {
        guard !interactionState.isOnRootPage else {
            return
        }

        cancelCurrentPageRuntime()
        cancelAllWebPageMetadataTasks()
        webPageMetadataFetchedURLStrings.removeAll()
        guard interactionState.goBackPage() else {
            startCurrentPageRuntime()
            return
        }

        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    func addRootPageAfterCurrent() {
        guard interactionState.canAddRootPage else {
            return
        }

        cancelCurrentPageRuntime()
        cancelAllWebPageMetadataTasks()
        webPageMetadataFetchedURLStrings.removeAll()
        guard interactionState.addRootPageAfterCurrent() else {
            startCurrentPageRuntime()
            return
        }

        reconcileRuntimeInstancesWithInteractionState()
        persistCurrentConfiguration()
        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    func deleteCurrentRootPage() {
        guard interactionState.canDeleteCurrentRootPage else {
            return
        }

        cancelCurrentPageRuntime()
        cancelAllWebPageMetadataTasks()
        webPageMetadataFetchedURLStrings.removeAll()
        guard interactionState.deleteCurrentRootPage() else {
            startCurrentPageRuntime()
            return
        }

        reconcileRuntimeInstancesWithInteractionState()
        persistCurrentConfiguration()
        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    func selectRootPage(pageID: String) {
        guard interactionState.canGoToRootPage(id: pageID) else {
            return
        }

        navigateRootPage {
            $0.goToRootPage(id: pageID)
        }
    }

    private func goToPreviousRootPage() {
        guard interactionState.canGoToPreviousRootPage else {
            return
        }

        navigateRootPage {
            $0.goToPreviousRootPage()
        }
    }

    private func goToNextRootPage() {
        guard interactionState.canGoToNextRootPage else {
            return
        }

        navigateRootPage {
            $0.goToNextRootPage()
        }
    }

    private func navigateRootPage(_ navigate: (inout DeckGridInteractionState) -> Bool) {
        guard interactionState.isOnRootPage else {
            return
        }

        cancelCurrentPageRuntime()
        cancelAllWebPageMetadataTasks()
        webPageMetadataFetchedURLStrings.removeAll()
        guard navigate(&interactionState) else {
            startCurrentPageRuntime()
            return
        }

        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    private func beginKeyPress(keyID: Int) {
        guard interactionState.beginPress(keyID: keyID) else {
            return
        }

        longPressResetKeyIDs.remove(keyID)
        longPressTasks[keyID]?.cancel()
        let longPressDurationNanoseconds = longPressDurationNanoseconds
        longPressTasks[keyID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: longPressDurationNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            self?.completeLongPress(keyID: keyID)
        }
    }

    private func endKeyPress(keyID: Int) {
        guard interactionState.isPressed(keyID: keyID) else {
            return
        }

        longPressTasks[keyID]?.cancel()
        longPressTasks[keyID] = nil
        let didResetByLongPress = longPressResetKeyIDs.remove(keyID) != nil
        interactionState.endPress(keyID: keyID)

        guard !didResetByLongPress else {
            return
        }

        let runtimeAction = interactionState.configuration(for: keyID)?.function.pressRuntimeAction ?? .none
        switch runtimeAction {
        case .incrementTally:
            if interactionState.triggerShortPress(keyID: keyID) {
                persistCurrentConfiguration()
                syncKeyDisplay(keyID: keyID)
            }
        case .openFolder:
            openFolder(for: keyID)
        case .openFile:
            openFile(for: keyID)
        case .openWebPage:
            openWebPage(for: keyID)
        case .connectSMBServer:
            connectSMBServer(for: keyID)
        case .refreshSub2API:
            fetchSub2API(for: keyID)
        case .refreshMihoyoGame:
            fetchMihoyoGameStatus(for: keyID)
        case .enterPage:
            enterPageFolder(for: keyID)
        case .goBackPage:
            goBackPage()
        case .previousRootPage:
            goToPreviousRootPage()
        case .nextRootPage:
            goToNextRootPage()
        case .none:
            return
        }
    }

    func assignSelectedFunction(_ function: DeckKeyFunction) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.configuration(for: selectedKeyID)?.function == function {
            clearKeyFunction(keyID: selectedKeyID)
            return
        }

        let previousInstanceID = runtimeInstanceID(for: selectedKeyID)
        cancelWebPageMetadataTask(for: selectedKeyID)
        webPageMetadataFetchedURLStrings[selectedKeyID] = nil
        if interactionState.assign(function, to: selectedKeyID) {
            if let previousInstanceID {
                destroyRuntimeInstance(previousInstanceID, clearsConfigurationRuntimeState: true)
            }
            clearConfigurationRuntimeState(
                for: runtimeSlotID(for: selectedKeyID),
                kind: function.scheduledRuntime
            )
            reconcileRuntimeInstancesWithInteractionState()
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
            if function == .sub2API {
                _ = ensureRuntimeInstance(for: selectedKeyID)
                fetchSub2API(for: selectedKeyID)
                scheduleSub2APIGroupListRefresh(for: selectedKeyID)
            }
            if function.game != nil {
                _ = ensureRuntimeInstance(for: selectedKeyID)
                startMihoyoGameTimer(for: selectedKeyID)
                fetchMihoyoGameStatus(for: selectedKeyID)
            }
        }
    }

    func setSelectedTallyDefaultValue(_ value: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setTallyDefaultValue(value, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedFolderConfiguration(_ configuration: DeckKeyOpenFolderConfiguration) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setFolderConfiguration(configuration, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedFolderName(_ name: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        setFolderName(name, for: selectedKeyID)
    }

    func previewButtonVisualName(_ name: String, for keyID: Int) {
        if interactionState.setButtonVisualName(name, for: keyID, selectsKey: false) {
            syncKeyDisplay(keyID: keyID)
        }
    }

    func setButtonVisualName(_ name: String, for keyID: Int) {
        if interactionState.setButtonVisualName(name, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: keyID)
        }
    }

    func setButtonVisualConfiguration(_ visual: DeckKeyVisualConfiguration, for keyID: Int) {
        if interactionState.setButtonVisualConfiguration(visual, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: keyID)
        }
    }

    func setButtonVisualBlurEnabled(_ enabled: Bool, for keyID: Int) {
        if interactionState.setButtonVisualBlurEnabled(enabled, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: keyID)
        }
    }

    func setButtonVisualDimmingEnabled(_ enabled: Bool, for keyID: Int) {
        if interactionState.setButtonVisualDimmingEnabled(enabled, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: keyID)
        }
    }

    func previewFolderName(_ name: String, for keyID: Int) {
        previewButtonVisualName(name, for: keyID)
    }

    func setFolderName(_ name: String, for keyID: Int) {
        setButtonVisualName(name, for: keyID)
    }

    func setFolderBackgroundPNGData(_ backgroundPNGData: Data?, for keyID: Int) {
        guard var visual = interactionState.buttonVisualConfiguration(for: keyID) else {
            return
        }

        visual.backgroundPNGData = backgroundPNGData
        if backgroundPNGData == nil {
            visual.blurredBackgroundPNGData = nil
            visual.usesBlurredBackground = false
        }
        setButtonVisualConfiguration(visual, for: keyID)
    }

    func setSelectedFileConfiguration(_ configuration: DeckKeyOpenFileConfiguration) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setFileConfiguration(configuration, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedFileName(_ name: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        setFileName(name, for: selectedKeyID)
    }

    func previewFileName(_ name: String, for keyID: Int) {
        previewButtonVisualName(name, for: keyID)
    }

    func setFileName(_ name: String, for keyID: Int) {
        setButtonVisualName(name, for: keyID)
    }

    func setFileIconBlurEnabled(_ enabled: Bool, for keyID: Int) {
        setButtonVisualBlurEnabled(enabled, for: keyID)
    }

    func setSelectedWebPageURLString(_ urlString: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let normalizedURLString = DeckKeyOpenWebPageConfiguration.normalizedURLString(urlString)
        guard interactionState.openWebPageConfiguration(for: selectedKeyID).urlString != normalizedURLString else {
            return
        }

        if interactionState.setWebPageURLString(urlString, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
            cancelWebPageMetadataTask(for: selectedKeyID)
            webPageMetadataFetchedURLStrings[selectedKeyID] = nil
        }
    }

    func submitSelectedWebPageURLString() {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let urlString = interactionState.openWebPageConfiguration(for: selectedKeyID).urlString
        fetchWebPageMetadata(for: selectedKeyID, urlString: urlString)
    }

    func previewWebPageTitle(_ title: String, for keyID: Int) {
        previewButtonVisualName(title, for: keyID)
    }

    func setWebPageTitle(_ title: String, for keyID: Int) {
        setButtonVisualName(title, for: keyID)
    }

    func setSelectedSMBServerAddress(_ address: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setSMBServerAddress(address, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedSMBServerName(_ name: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        setSMBServerName(name, for: selectedKeyID)
    }

    func previewSMBServerName(_ name: String, for keyID: Int) {
        previewButtonVisualName(name, for: keyID)
    }

    func setSMBServerName(_ name: String, for keyID: Int) {
        setButtonVisualName(name, for: keyID)
    }

    func setSelectedSub2APIBaseURL(_ baseURL: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard interactionState.sub2APIConfiguration(for: selectedKeyID).baseURL != normalizedBaseURL else {
            return
        }

        if interactionState.setSub2APIBaseURL(baseURL, for: selectedKeyID) {
            let instanceID = ensureRuntimeInstance(for: selectedKeyID)
            persistCurrentConfiguration()
            if let instanceID {
                stopSub2APITimer(for: instanceID, preservesNextFire: false)
                sub2APIFetchTasks[instanceID]?.cancel()
                sub2APIFetchTasks[instanceID] = nil
                sub2APIGroupListTasks[instanceID]?.cancel()
                sub2APIGroupListTasks[instanceID] = nil
                stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: false)
            }
            syncKeyDisplay(keyID: selectedKeyID)
            scheduleSub2APIGroupListRefresh(for: selectedKeyID)
        }
    }

    func setSelectedSub2APITargetGroupID(_ groupID: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        guard interactionState.sub2APIConfiguration(for: selectedKeyID).targetGroupID != groupID else {
            return
        }

        if interactionState.setSub2APITargetGroupID(groupID, for: selectedKeyID) {
            let instanceID = ensureRuntimeInstance(for: selectedKeyID)
            persistCurrentConfiguration()
            if let instanceID {
                stopSub2APITimer(for: instanceID, preservesNextFire: false)
                sub2APIFetchTasks[instanceID]?.cancel()
                sub2APIFetchTasks[instanceID] = nil
            }
            if groupID > 0 {
                fetchSub2API(for: selectedKeyID)
            } else {
                syncKeyDisplay(keyID: selectedKeyID)
            }
        }
    }

    func setSelectedSub2APIRefreshInterval(_ interval: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let clampedInterval = max(5, interval)
        guard interactionState.sub2APIConfiguration(for: selectedKeyID).refreshInterval != clampedInterval else {
            return
        }

        if interactionState.setSub2APIRefreshInterval(interval, for: selectedKeyID) {
            persistCurrentConfiguration()
            restartSub2APITimer(for: selectedKeyID)
        }
    }

    func setSelectedSub2APIBearerKey(_ bearerKey: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let previousCredential = interactionState.sub2APIConfiguration(for: selectedKeyID)
        guard previousCredential.bearerKey != bearerKey else {
            return
        }

        if interactionState.setSub2APIBearerKey(bearerKey, for: selectedKeyID) {
            let instanceID = ensureRuntimeInstance(for: selectedKeyID)
            let saveResult = persistCurrentConfiguration()
            if case let .credentialFailure(message) = saveResult {
                _ = interactionState.restoreSub2APICredential(
                    bearerKey: previousCredential.bearerKey,
                    credentialID: previousCredential.credentialID,
                    for: selectedKeyID
                )
                _ = persistCurrentConfiguration()
                interactionState.setSub2APIGroupListState(.networkError(message), for: selectedKeyID)
                return
            }
            resumeSub2APIAfterBearerChange(for: selectedKeyID)
            if let instanceID {
                stopSub2APITimer(for: instanceID, preservesNextFire: false)
                sub2APIFetchTasks[instanceID]?.cancel()
                sub2APIFetchTasks[instanceID] = nil
                sub2APIGroupListTasks[instanceID]?.cancel()
                sub2APIGroupListTasks[instanceID] = nil
                stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: false)
            }
            syncKeyDisplay(keyID: selectedKeyID)
            scheduleSub2APIGroupListRefresh(for: selectedKeyID)
            if interactionState.sub2APIConfiguration(for: selectedKeyID).targetGroupID > 0 {
                fetchSub2API(for: selectedKeyID)
            }
        }
    }

    func setSelectedSub2APIServiceName(_ serviceName: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setSub2APIServiceName(serviceName, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedSub2APIGroupName(_ groupName: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setSub2APIGroupName(groupName, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func refreshSelectedSub2APIGroupList() {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        fetchSub2APIGroupList(for: selectedKeyID)
    }

    func setSelectedMihoyoGameRefreshIntervalMinutes(_ minutes: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        let clampedMinutes = DeckKeyMihoyoGameRefreshConfiguration.clamped(minutes)
        guard interactionState.mihoyoGameConfiguration(for: selectedKeyID).refreshIntervalMinutes != clampedMinutes else {
            return
        }

        if interactionState.setMihoyoGameRefreshIntervalMinutes(minutes, for: selectedKeyID) {
            persistCurrentConfiguration()
            restartMihoyoGameTimer(for: selectedKeyID)
        }
    }

    func beginMihoyoQRCodeLogin() {
        mihoyoLoginTask?.cancel()
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = .creatingQRCode
        cancelAllMihoyoGameTimers(preservesNextFire: false)
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: .loginRequired)

        let service = mihoyoGameService
        let pollNanoseconds = mihoyoLoginPollNanoseconds
        mihoyoLoginTask = Task { @MainActor [weak self] in
            do {
                let qrSession = try await service.createQRCodeLogin()
                guard !Task.isCancelled else { return }

                self?.mihoyoLoginState = .waitingForScan(qrSession)
                let deadline = Date().addingTimeInterval(120)
                while Date() < deadline {
                    try await Task.sleep(nanoseconds: pollNanoseconds)
                    guard !Task.isCancelled else { return }

                    let result = try await service.queryQRCodeLogin(qrSession)
                    guard !Task.isCancelled else { return }

                    switch result {
                    case .waitingForScan:
                        self?.mihoyoLoginState = .waitingForScan(qrSession)
                    case .scanned:
                        self?.mihoyoLoginState = .scanned(qrSession)
                    case let .confirmed(session):
                        self?.finishMihoyoLogin(session)
                        return
                    case let .expired(message):
                        self?.expireMihoyoLogin(message)
                        return
                    case let .failed(message):
                        self?.failMihoyoLogin(message)
                        return
                    }
                }

                self?.expireMihoyoLogin("二维码已超时")
            } catch is CancellationError {
                return
            } catch {
                self?.failMihoyoLogin(error.localizedDescription)
            }
        }
    }

    func refreshSelectedMihoyoGameStatus() {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        fetchMihoyoGameStatus(for: selectedKeyID)
    }

    func previewBrightnessPercent(_ percent: Int) {
        updateBrightnessPercent(percent, persist: false)
    }

    func commitBrightnessPercent(_ percent: Int) {
        updateBrightnessPercent(percent, persist: true, forceSend: true)
    }

    func setBrightnessPercent(_ percent: Int, forceSend: Bool = false) {
        updateBrightnessPercent(percent, persist: true, forceSend: forceSend)
    }

    private func updateBrightnessPercent(_ percent: Int, persist: Bool, forceSend: Bool = false) {
        let clampedPercent = DeckBrightnessConfiguration.clamped(percent)
        let wasInternalRefreshPaused = isInternalRefreshPaused
        let didChange = brightnessPercent != clampedPercent

        brightnessPercent = clampedPercent
        if persist {
            hasPersistedBrightnessPercent = true
            configurationStore.saveBrightnessPercent(clampedPercent)
        }
        handleInternalRefreshPauseChange(wasPaused: wasInternalRefreshPaused)
        guard didChange || forceSend else {
            return
        }

        requestBrightnessUpdate(percent: clampedPercent)
    }

    private var isInternalRefreshPaused: Bool {
        brightnessPercent == 0
    }

    private var canRunInternalRefresh: Bool {
        !isInternalRefreshPaused
    }

    private func handleInternalRefreshPauseChange(wasPaused: Bool) {
        let isPaused = isInternalRefreshPaused
        guard wasPaused != isPaused else {
            return
        }

        if isPaused {
            pauseInternalRefresh()
        } else {
            resumeInternalRefresh()
        }
    }

    private func pauseInternalRefresh() {
        pauseAllRuntimeInstances()
        syncer.setInternalRefreshPaused(true)
    }

    private func resumeInternalRefresh() {
        syncer.setInternalRefreshPaused(false)
        startCurrentPageRuntime()
    }

    private func refresh() {
        pauseAllRuntimeInstances()
        _ = interactionState.goToRootPage()
        reconcileRuntimeInstancesWithInteractionState()
        deviceCommandGeneration += 1
        let generation = deviceCommandGeneration
        status = .checking
        syncSummary = nil
        alert = nil
        needsFullDisplaySyncAfterStartup = false
        if canRunInternalRefresh, mihoyoSession != nil {
            startAssignedMihoyoGameTimers()
        }

        let discovery = discovery
        let syncer = syncer
        let initialDisplays = interactionState.displays(for: layout)
        let startupDisplayRevision = displayRevision
        deviceCommandQueue.async { [weak self] in
            syncer.close()

            let discoveryResult = discovery.discoverH200()
            DispatchQueue.main.async { [weak self] in
                self?.finishDiscovery(discoveryResult, generation: generation)
            }

            guard case .connected = discoveryResult else {
                return
            }

            let syncResult = syncer.sendStartupPackage(displays: initialDisplays)
            DispatchQueue.main.async { [weak self] in
                self?.finishStartupSync(
                    syncResult,
                    generation: generation,
                    startupDisplayRevision: startupDisplayRevision
                )
            }
        }
    }

    private func finishDiscovery(_ result: H200DiscoveryResult, generation: Int) {
        guard generation == deviceCommandGeneration else {
            return
        }

        status = H200ConnectionStatus(result: result)
        alert = H200ConnectionAlert(result: result)
    }

    private func finishStartupSync(
        _ result: H200DeckSyncResult,
        generation: Int,
        startupDisplayRevision: Int
    ) {
        guard generation == deviceCommandGeneration else {
            return
        }

        switch result {
        case let .success(summary):
            syncSummary = summary
            if hasPersistedBrightnessPercent {
                requestBrightnessUpdate(percent: brightnessPercent)
            }
            if needsFullDisplaySyncAfterStartup || displayRevision != startupDisplayRevision {
                needsFullDisplaySyncAfterStartup = false
                syncCurrentDisplays()
            }
            if canRunInternalRefresh {
                refreshAssignedSub2APIStatuses()
            }
        case let .failure(error, _):
            alert = H200ConnectionAlert(syncFailure: error)
        }
    }

    private func handleInputEvent(_ event: H200InputEvent) {
        guard let keyID = H200DeckInputMapper.keyID(for: event, layout: layout) else {
            return
        }

        switch event.action {
        case .press:
            beginKeyPress(keyID: keyID)
        case .release:
            endKeyPress(keyID: keyID)
        }
    }

    private func completeLongPress(keyID: Int) {
        guard interactionState.isPressed(keyID: keyID) else {
            return
        }

        if interactionState.resetTally(keyID: keyID) {
            longPressResetKeyIDs.insert(keyID)
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: keyID)
        }
    }

    private func openFolder(for keyID: Int) {
        let configuration = interactionState.openFolderConfiguration(for: keyID)
        guard configuration.canOpen else {
            return
        }

        let result = folderOpener.openFolder(configuration)
        guard case let .opened(refreshedConfiguration) = result,
              var refreshedConfiguration
        else {
            return
        }

        refreshedConfiguration.visual = configuration.visual
        if interactionState.setFolderConfiguration(refreshedConfiguration, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
        }
    }

    private func openFile(for keyID: Int) {
        let configuration = interactionState.openFileConfiguration(for: keyID)
        guard configuration.canOpen else {
            return
        }

        let result = fileOpener.openFile(configuration)
        guard case let .opened(refreshedConfiguration) = result,
              var refreshedConfiguration
        else {
            return
        }

        refreshedConfiguration.visual = configuration.visual
        if interactionState.setFileConfiguration(refreshedConfiguration, for: keyID, selectsKey: false) {
            persistCurrentConfiguration()
        }
    }

    private func openWebPage(for keyID: Int) {
        let configuration = interactionState.openWebPageConfiguration(for: keyID)
        guard configuration.canOpen else {
            return
        }

        _ = webPageOpener.openWebPage(configuration)
    }

    private func connectSMBServer(for keyID: Int) {
        let address = interactionState.smbServerAddress(for: keyID)
        guard !address.isEmpty else {
            return
        }

        _ = smbServerConnector.connect(to: address)
    }

    private func fetchWebPageMetadata(for keyID: Int, urlString: String) {
        cancelWebPageMetadataTask(for: keyID)
        guard !urlString.isEmpty,
              (try? WebPageURL(urlString)) != nil,
              webPageMetadataFetchedURLStrings[keyID] != urlString,
              interactionState.configuration(for: keyID)?.function == .openWebPage
        else {
            return
        }

        let fetcher = webPageMetadataFetcher
        webPageMetadataTasks[keyID] = Task { @MainActor [weak self] in
            let metadata = await fetcher.fetchMetadata(for: urlString)
            guard !Task.isCancelled,
                  let self
            else {
                return
            }

            self.webPageMetadataTasks[keyID] = nil
            guard let metadata,
                  self.interactionState.setWebPageMetadata(metadata, for: keyID, matchingURLString: urlString)
            else {
                return
            }

            self.persistCurrentConfiguration()
            self.syncKeyDisplay(keyID: keyID)
            self.webPageMetadataFetchedURLStrings[keyID] = urlString
        }
    }

    private func cancelWebPageMetadataTask(for keyID: Int) {
        webPageMetadataTasks[keyID]?.cancel()
        webPageMetadataTasks[keyID] = nil
    }

    private func cancelAllWebPageMetadataTasks() {
        for task in webPageMetadataTasks.values {
            task.cancel()
        }
        webPageMetadataTasks.removeAll()
    }

    private var nowNanoseconds: UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private func runtimeSlotID(for keyID: Int, pageID: String? = nil) -> RuntimeSlotID {
        RuntimeSlotID(pageID: pageID ?? interactionState.currentPageID, keyID: keyID)
    }

    private func runtimeConfiguration(for slot: RuntimeSlotID) -> DeckKeyConfiguration? {
        if slot.pageID == interactionState.currentPageID {
            return interactionState.configuration(for: slot.keyID)
        }

        return interactionState.persistedPages
            .first { $0.id == slot.pageID }?
            .configurations[slot.keyID]
    }

    private func runtimeInstanceID(for keyID: Int, pageID: String? = nil) -> RuntimeInstanceID? {
        runtimeInstancesBySlot[runtimeSlotID(for: keyID, pageID: pageID)]
    }

    private func ensureRuntimeInstance(for keyID: Int) -> RuntimeInstanceID? {
        guard let kind = interactionState.configuration(for: keyID)?.function.scheduledRuntime else {
            return nil
        }

        let slot = runtimeSlotID(for: keyID)
        if let existingInstanceID = runtimeInstancesBySlot[slot] {
            if runtimeKindsByInstance[existingInstanceID] == kind {
                return existingInstanceID
            }
            destroyRuntimeInstance(existingInstanceID, clearsConfigurationRuntimeState: true)
        }

        nextRuntimeInstanceRawValue += 1
        let instanceID = RuntimeInstanceID(rawValue: nextRuntimeInstanceRawValue)
        runtimeInstancesBySlot[slot] = instanceID
        runtimeSlotsByInstance[instanceID] = slot
        runtimeKindsByInstance[instanceID] = kind
        return instanceID
    }

    private func ensureCurrentPageRuntimeInstances() {
        for key in layout.keys where interactionState.configuration(for: key.id)?.function.scheduledRuntime != nil {
            _ = ensureRuntimeInstance(for: key.id)
        }
    }

    private func reconcileRuntimeInstancesWithInteractionState() {
        let pageIDs = Set(interactionState.persistedPages.map(\.id))
        for (slot, instanceID) in Array(runtimeInstancesBySlot) {
            let expectedKind = pageIDs.contains(slot.pageID)
                ? runtimeConfiguration(for: slot)?.function.scheduledRuntime
                : nil
            guard expectedKind == runtimeKindsByInstance[instanceID] else {
                destroyRuntimeInstance(
                    instanceID,
                    clearsConfigurationRuntimeState: slot.pageID == interactionState.currentPageID
                )
                continue
            }
        }
    }

    private func clearConfigurationRuntimeState(for slot: RuntimeSlotID, kind: DeckKeyScheduledRuntime?) {
        guard slot.pageID == interactionState.currentPageID else {
            return
        }

        switch kind {
        case .sub2API:
            _ = interactionState.clearSub2APIRuntimeState(for: slot.keyID)
        case .mihoyoGame:
            _ = interactionState.clearMihoyoGameRuntimeState(for: slot.keyID)
        case nil:
            return
        }
    }

    private func destroyRuntimeInstance(
        _ instanceID: RuntimeInstanceID,
        clearsConfigurationRuntimeState: Bool
    ) {
        let slot = runtimeSlotsByInstance[instanceID]
        let kind = runtimeKindsByInstance[instanceID]

        sub2APITimers[instanceID]?.invalidate()
        sub2APITimers[instanceID] = nil
        sub2APINextFireNanoseconds[instanceID] = nil
        sub2APIFetchTasks[instanceID]?.cancel()
        sub2APIFetchTasks[instanceID] = nil
        sub2APIGroupListTasks[instanceID]?.cancel()
        sub2APIGroupListTasks[instanceID] = nil
        sub2APIGroupListRefreshTasks[instanceID]?.cancel()
        sub2APIGroupListRefreshTasks[instanceID] = nil
        sub2APIGroupListRefreshFireNanoseconds[instanceID] = nil
        sub2APIGroupListLastRequestNanoseconds[instanceID] = nil
        sub2APITokenPausedInstances.remove(instanceID)

        mihoyoGameTimers[instanceID]?.invalidate()
        mihoyoGameTimers[instanceID] = nil
        mihoyoGameNextFireNanoseconds[instanceID] = nil
        mihoyoGameFetchTasks[instanceID]?.cancel()
        mihoyoGameFetchTasks[instanceID] = nil

        if let slot {
            runtimeInstancesBySlot[slot] = nil
            runtimeSlotsByInstance[instanceID] = nil
            if clearsConfigurationRuntimeState {
                clearConfigurationRuntimeState(for: slot, kind: kind)
            }
        }
        runtimeKindsByInstance[instanceID] = nil
    }

    private func destroyRuntimeInstance(for keyID: Int, clearsConfigurationRuntimeState: Bool) {
        guard let instanceID = runtimeInstanceID(for: keyID) else {
            return
        }

        destroyRuntimeInstance(
            instanceID,
            clearsConfigurationRuntimeState: clearsConfigurationRuntimeState
        )
    }

    private func swapRuntimeInstances(sourceKeyID: Int, targetKeyID: Int, pageID: String) {
        let sourceSlot = RuntimeSlotID(pageID: pageID, keyID: sourceKeyID)
        let targetSlot = RuntimeSlotID(pageID: pageID, keyID: targetKeyID)
        let sourceInstanceID = runtimeInstancesBySlot[sourceSlot]
        let targetInstanceID = runtimeInstancesBySlot[targetSlot]

        runtimeInstancesBySlot[sourceSlot] = targetInstanceID
        runtimeInstancesBySlot[targetSlot] = sourceInstanceID
        if let sourceInstanceID {
            runtimeSlotsByInstance[sourceInstanceID] = targetSlot
        }
        if let targetInstanceID {
            runtimeSlotsByInstance[targetInstanceID] = sourceSlot
        }
    }

    private func cancelLongPressRuntime(for keyID: Int) {
        longPressTasks[keyID]?.cancel()
        longPressTasks[keyID] = nil
        longPressResetKeyIDs.remove(keyID)
    }

    private func pauseRuntimeInstance(_ instanceID: RuntimeInstanceID) {
        sub2APITimers[instanceID]?.invalidate()
        sub2APITimers[instanceID] = nil
        sub2APIFetchTasks[instanceID]?.cancel()
        sub2APIFetchTasks[instanceID] = nil
        sub2APIGroupListTasks[instanceID]?.cancel()
        sub2APIGroupListTasks[instanceID] = nil
        sub2APIGroupListRefreshTasks[instanceID]?.cancel()
        sub2APIGroupListRefreshTasks[instanceID] = nil

        mihoyoGameTimers[instanceID]?.invalidate()
        mihoyoGameTimers[instanceID] = nil
        mihoyoGameFetchTasks[instanceID]?.cancel()
        mihoyoGameFetchTasks[instanceID] = nil
    }

    private func pauseCurrentPageRuntime() {
        cancelAllLongPressTasks()
        for (slot, instanceID) in runtimeInstancesBySlot where slot.pageID == interactionState.currentPageID {
            pauseRuntimeInstance(instanceID)
        }
    }

    private func pauseAllRuntimeInstances() {
        cancelAllLongPressTasks()
        for instanceID in runtimeSlotsByInstance.keys {
            pauseRuntimeInstance(instanceID)
        }
    }

    private func resumeCurrentPageRuntime() {
        guard canRunInternalRefresh else {
            return
        }

        reconcileRuntimeInstancesWithInteractionState()
        ensureCurrentPageRuntimeInstances()
        for (slot, instanceID) in runtimeInstancesBySlot where slot.pageID == interactionState.currentPageID {
            resumeRuntimeInstance(instanceID)
        }
    }

    private func resumeRuntimeInstance(_ instanceID: RuntimeInstanceID) {
        switch runtimeKindsByInstance[instanceID] {
        case .sub2API:
            resumeSub2APIRuntime(instanceID)
        case .mihoyoGame:
            resumeMihoyoGameRuntime(instanceID)
        case nil:
            return
        }
    }

    private func isSub2APITokenPaused(for instanceID: RuntimeInstanceID) -> Bool {
        sub2APITokenPausedInstances.contains(instanceID)
    }

    private func pauseSub2APIForTokenError(instanceID: RuntimeInstanceID) {
        sub2APITokenPausedInstances.insert(instanceID)
        stopSub2APITimer(for: instanceID, preservesNextFire: false)
        sub2APIGroupListRefreshTasks[instanceID]?.cancel()
        sub2APIGroupListRefreshTasks[instanceID] = nil
        sub2APIGroupListRefreshFireNanoseconds[instanceID] = nil
    }

    private func resumeSub2APIAfterBearerChange(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        sub2APITokenPausedInstances.remove(instanceID)
    }

    private func resolveCurrentSub2APISlot(
        for instanceID: RuntimeInstanceID
    ) -> (slot: RuntimeSlotID, config: DeckKeySub2APIConfiguration)? {
        guard let slot = runtimeSlotsByInstance[instanceID],
              slot.pageID == interactionState.currentPageID,
              interactionState.configuration(for: slot.keyID)?.displayMode == .function,
              interactionState.configuration(for: slot.keyID)?.function == .sub2API
        else {
            return nil
        }

        return (slot, interactionState.sub2APIConfiguration(for: slot.keyID))
    }

    private func fetchSub2API(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        fetchSub2API(for: instanceID)
    }

    private func fetchSub2API(for instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              let resolved = resolveCurrentSub2APISlot(for: instanceID),
              !isSub2APITokenPaused(for: instanceID),
              !resolved.config.baseURL.isEmpty,
              resolved.config.targetGroupID > 0,
              !resolved.config.bearerKey.isEmpty
        else {
            return
        }

        stopSub2APITimer(for: instanceID, preservesNextFire: false)
        sub2APIFetchTasks[instanceID]?.cancel()
        let pageID = resolved.slot.pageID
        let fetcher = sub2APIFetcher
        let baseURL = resolved.config.baseURL
        let targetGroupID = resolved.config.targetGroupID
        let bearerKey = resolved.config.bearerKey
        sub2APIFetchTasks[instanceID] = Task { @MainActor [weak self] in
            let result = await fetcher.fetchCapacitySummary(
                baseURL: baseURL,
                targetGroupID: targetGroupID,
                bearerKey: bearerKey
            )
            guard !Task.isCancelled else { return }

            guard let self,
                  let latest = self.resolveCurrentSub2APISlot(for: instanceID),
                  latest.slot.pageID == pageID,
                  latest.config.baseURL == baseURL,
                  latest.config.targetGroupID == targetGroupID,
                  latest.config.bearerKey == bearerKey
            else {
                return
            }

            self.sub2APIFetchTasks[instanceID] = nil
            self.interactionState.setSub2APILastResult(result, for: latest.slot.keyID)
            if result.isTokenUnavailable {
                self.pauseSub2APIForTokenError(instanceID: instanceID)
            }
            self.syncKeyDisplay(keyID: latest.slot.keyID) { [weak self] (syncResult: H200DeckSyncResult) in
                guard case .success = syncResult else {
                    return
                }

                guard let self,
                      self.canRunInternalRefresh,
                      let latest = self.resolveCurrentSub2APISlot(for: instanceID),
                      latest.config.baseURL == baseURL,
                      latest.config.targetGroupID == targetGroupID,
                      latest.config.bearerKey == bearerKey,
                      !self.isSub2APITokenPaused(for: instanceID)
                else {
                    return
                }

                self.scheduleNextSub2APIRefresh(for: instanceID)
            }
        }
    }

    private func fetchSub2APIGroupList(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        fetchSub2APIGroupList(for: instanceID)
    }

    private func fetchSub2APIGroupList(for instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              let resolved = resolveCurrentSub2APISlot(for: instanceID),
              !isSub2APITokenPaused(for: instanceID)
        else {
            return
        }

        guard !resolved.config.baseURL.isEmpty, !resolved.config.bearerKey.isEmpty else {
            interactionState.setSub2APIGroupListState(
                .networkError("请先填写 Base URL 和 Bearer Key"),
                for: resolved.slot.keyID
            )
            return
        }

        stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: false)
        sub2APIGroupListTasks[instanceID]?.cancel()
        interactionState.setSub2APIGroupListState(.loading, for: resolved.slot.keyID)
        sub2APIGroupListLastRequestNanoseconds[instanceID] = nowNanoseconds
        let pageID = resolved.slot.pageID
        let fetcher = sub2APIFetcher
        let baseURL = resolved.config.baseURL
        let bearerKey = resolved.config.bearerKey
        sub2APIGroupListTasks[instanceID] = Task { @MainActor [weak self] in
            let result = await fetcher.fetchCapacityGroups(baseURL: baseURL, bearerKey: bearerKey)
            guard !Task.isCancelled else { return }

            guard let self,
                  let latest = self.resolveCurrentSub2APISlot(for: instanceID),
                  latest.slot.pageID == pageID,
                  latest.config.baseURL == baseURL,
                  latest.config.bearerKey == bearerKey
            else {
                return
            }

            self.sub2APIGroupListTasks[instanceID] = nil
            let groupListState: DeckKeySub2APIGroupListState
            switch result {
            case let .success(items):
                groupListState = .success(items: items)
            case .invalidToken:
                groupListState = .invalidToken
            case .tokenExpired:
                groupListState = .tokenExpired
            case let .networkError(message):
                groupListState = .networkError(message)
            }

            if result.isTokenUnavailable {
                self.pauseSub2APIForTokenError(instanceID: instanceID)
            }
            self.interactionState.setSub2APIGroupListState(groupListState, for: latest.slot.keyID)
        }
    }

    private func scheduleSub2APIGroupListRefresh(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        scheduleSub2APIGroupListRefresh(for: instanceID)
    }

    private func scheduleSub2APIGroupListRefresh(for instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              let resolved = resolveCurrentSub2APISlot(for: instanceID),
              !isSub2APITokenPaused(for: instanceID),
              !resolved.config.baseURL.isEmpty,
              !resolved.config.bearerKey.isEmpty
        else {
            stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: false)
            return
        }

        let now = nowNanoseconds
        let minimumInterval = sub2APIGroupListMinimumIntervalNanoseconds
        guard let lastRequest = sub2APIGroupListLastRequestNanoseconds[instanceID],
              now < lastRequest + minimumInterval
        else {
            stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: false)
            fetchSub2APIGroupList(for: instanceID)
            return
        }

        scheduleSub2APIGroupListRefresh(for: instanceID, fireAt: lastRequest + minimumInterval)
    }

    private func scheduleSub2APIGroupListRefresh(
        for instanceID: RuntimeInstanceID,
        fireAt fireNanoseconds: UInt64
    ) {
        guard canRunInternalRefresh,
              resolveCurrentSub2APISlot(for: instanceID) != nil,
              !isSub2APITokenPaused(for: instanceID)
        else {
            return
        }

        stopSub2APIGroupListRefresh(for: instanceID, preservesNextFire: true)
        sub2APIGroupListRefreshFireNanoseconds[instanceID] = fireNanoseconds
        let now = nowNanoseconds
        guard fireNanoseconds > now else {
            sub2APIGroupListRefreshFireNanoseconds[instanceID] = nil
            fetchSub2APIGroupList(for: instanceID)
            return
        }

        let delayNanoseconds = fireNanoseconds - now
        sub2APIGroupListRefreshTasks[instanceID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            self?.sub2APIGroupListRefreshTasks[instanceID] = nil
            self?.sub2APIGroupListRefreshFireNanoseconds[instanceID] = nil
            self?.fetchSub2APIGroupList(for: instanceID)
        }
    }

    private func stopSub2APIGroupListRefresh(
        for instanceID: RuntimeInstanceID,
        preservesNextFire: Bool
    ) {
        sub2APIGroupListRefreshTasks[instanceID]?.cancel()
        sub2APIGroupListRefreshTasks[instanceID] = nil
        if !preservesNextFire {
            sub2APIGroupListRefreshFireNanoseconds[instanceID] = nil
        }
    }

    private func resumeSub2APIRuntime(_ instanceID: RuntimeInstanceID) {
        guard let resolved = resolveCurrentSub2APISlot(for: instanceID),
              !isSub2APITokenPaused(for: instanceID)
        else {
            return
        }

        if let groupListFireNanoseconds = sub2APIGroupListRefreshFireNanoseconds[instanceID] {
            scheduleSub2APIGroupListRefresh(for: instanceID, fireAt: groupListFireNanoseconds)
        }

        if let nextFireNanoseconds = sub2APINextFireNanoseconds[instanceID] {
            scheduleSub2APIRefresh(for: instanceID, fireAt: nextFireNanoseconds)
        } else if resolved.config.lastResult != nil {
            scheduleNextSub2APIRefresh(for: instanceID)
        } else {
            fetchSub2API(for: instanceID)
        }
    }

    private func fetchMihoyoGameStatus(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        fetchMihoyoGameStatus(for: instanceID)
    }

    private func resolveCurrentMihoyoGameSlot(
        for instanceID: RuntimeInstanceID
    ) -> (slot: RuntimeSlotID, game: MihoyoGame, config: DeckKeyMihoyoGameConfiguration)? {
        guard let slot = runtimeSlotsByInstance[instanceID],
              slot.pageID == interactionState.currentPageID,
              interactionState.configuration(for: slot.keyID)?.displayMode == .function,
              let game = interactionState.mihoyoGame(for: slot.keyID)
        else {
            return nil
        }

        return (slot, game, interactionState.mihoyoGameConfiguration(for: slot.keyID))
    }

    private func fetchMihoyoGameStatus(for instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              let resolved = resolveCurrentMihoyoGameSlot(for: instanceID)
        else {
            return
        }

        guard let session = mihoyoSession else {
            if interactionState.setMihoyoGameLastResult(.loginRequired, for: resolved.slot.keyID) {
                syncKeyDisplay(keyID: resolved.slot.keyID)
            }
            return
        }

        mihoyoGameFetchTasks[instanceID]?.cancel()
        let pageID = resolved.slot.pageID
        let service = mihoyoGameService
        let game = resolved.game
        mihoyoGameFetchTasks[instanceID] = Task { @MainActor [weak self] in
            let result = await service.fetchDailyStatus(game: game, session: session)
            guard !Task.isCancelled else { return }

            guard let self,
                  let latest = self.resolveCurrentMihoyoGameSlot(for: instanceID),
                  latest.slot.pageID == pageID,
                  self.mihoyoSession == session,
                  latest.game == game
            else {
                return
            }

            self.mihoyoGameFetchTasks[instanceID] = nil
            self.interactionState.setMihoyoGameLastResult(result, for: latest.slot.keyID)
            switch result {
            case let .loginExpired(message):
                self.invalidateMihoyoSession(
                    loginState: .expired(message),
                    keyResult: .loginExpired(message)
                )
                return
            case .loginRequired:
                self.invalidateMihoyoSession(
                    loginState: .notLoggedIn,
                    keyResult: .loginRequired
                )
                return
            case .success, .noBoundRole, .networkError:
                break
            }
            self.syncKeyDisplay(keyID: latest.slot.keyID)
        }
    }

    private func invalidateMihoyoSession(
        loginState: MihoyoLoginState,
        keyResult: MihoyoGameStatusResult
    ) {
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = loginState
        cancelAllMihoyoGameTimers(preservesNextFire: false)
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: keyResult)
    }

    private func finishMihoyoLogin(_ session: MihoyoLoginSession) {
        guard mihoyoSessionStore.saveSession(session) else {
            mihoyoSession = nil
            mihoyoLoginState = .failed("无法安全保存登录会话，请检查 Keychain 权限后重试")
            cancelAllMihoyoGameTimers(preservesNextFire: false)
            cancelAllMihoyoGameFetchTasks()
            markAllMihoyoKeys(result: .loginRequired)
            return
        }

        mihoyoSession = session
        mihoyoLoginState = .loggedIn(accountID: session.accountID)
        guard canRunInternalRefresh else {
            return
        }

        startAssignedMihoyoGameTimers()
        refreshAssignedMihoyoGameStatuses()
    }

    private func failMihoyoLogin(_ message: String) {
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = .failed(message)
        cancelAllMihoyoGameTimers(preservesNextFire: false)
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: .loginRequired)
    }

    private func expireMihoyoLogin(_ message: String) {
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = .expired(message)
        cancelAllMihoyoGameTimers(preservesNextFire: false)
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: .loginRequired)
    }

    private func refreshAssignedMihoyoGameStatuses() {
        guard canRunInternalRefresh else {
            return
        }

        for key in layout.keys where interactionState.mihoyoGame(for: key.id) != nil {
            fetchMihoyoGameStatus(for: key.id)
        }
    }

    private func markAllMihoyoKeys(result: MihoyoGameStatusResult) {
        for key in layout.keys where interactionState.mihoyoGame(for: key.id) != nil {
            if interactionState.setMihoyoGameLastResult(result, for: key.id) {
                syncKeyDisplay(keyID: key.id)
            }
        }
    }

    private func refreshAssignedSub2APIStatuses() {
        guard canRunInternalRefresh else {
            return
        }

        for key in layout.keys where interactionState.configuration(for: key.id)?.function == .sub2API {
            fetchSub2API(for: key.id)
        }
    }

    private func startAssignedMihoyoGameTimers() {
        guard canRunInternalRefresh else {
            return
        }

        for key in layout.keys where interactionState.mihoyoGame(for: key.id) != nil {
            startMihoyoGameTimer(for: key.id)
        }
    }

    private func scheduleNextSub2APIRefresh(for instanceID: RuntimeInstanceID) {
        guard let resolved = resolveCurrentSub2APISlot(for: instanceID) else {
            return
        }

        let config = resolved.config
        guard canRunInternalRefresh,
              !isSub2APITokenPaused(for: instanceID),
              !config.baseURL.isEmpty,
              config.targetGroupID > 0,
              !config.bearerKey.isEmpty,
              config.refreshInterval >= 5
        else {
            return
        }

        let intervalNanoseconds = UInt64(TimeInterval(config.refreshInterval) * sub2APIRefreshSecondDuration * 1_000_000_000)
        scheduleSub2APIRefresh(for: instanceID, fireAt: nowNanoseconds + intervalNanoseconds)
    }

    private func scheduleSub2APIRefresh(for instanceID: RuntimeInstanceID, fireAt fireNanoseconds: UInt64) {
        stopSub2APITimer(for: instanceID, preservesNextFire: true)
        guard canRunInternalRefresh,
              resolveCurrentSub2APISlot(for: instanceID) != nil,
              !isSub2APITokenPaused(for: instanceID)
        else {
            return
        }

        sub2APINextFireNanoseconds[instanceID] = fireNanoseconds
        let now = nowNanoseconds
        guard fireNanoseconds > now else {
            sub2APINextFireNanoseconds[instanceID] = nil
            fetchSub2API(for: instanceID)
            return
        }

        let interval = TimeInterval(fireNanoseconds - now) / 1_000_000_000
        sub2APITimers[instanceID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sub2APITimers[instanceID] = nil
                self?.sub2APINextFireNanoseconds[instanceID] = nil
                self?.fetchSub2API(for: instanceID)
            }
        }
    }

    private func stopSub2APITimer(for instanceID: RuntimeInstanceID, preservesNextFire: Bool) {
        sub2APITimers[instanceID]?.invalidate()
        sub2APITimers[instanceID] = nil
        if !preservesNextFire {
            sub2APINextFireNanoseconds[instanceID] = nil
        }
    }

    private func restartSub2APITimer(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        guard canRunInternalRefresh,
              !isSub2APITokenPaused(for: instanceID),
              interactionState.sub2APIConfiguration(for: keyID).lastResult != nil
        else {
            return
        }

        scheduleNextSub2APIRefresh(for: instanceID)
    }

    private func startMihoyoGameTimer(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        scheduleNextMihoyoGameRefresh(for: instanceID)
    }

    private func scheduleNextMihoyoGameRefresh(for instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              mihoyoSession != nil,
              let resolved = resolveCurrentMihoyoGameSlot(for: instanceID)
        else {
            return
        }

        let intervalNanoseconds = UInt64(
            TimeInterval(resolved.config.refreshIntervalMinutes)
                * mihoyoGameRefreshMinuteDuration
                * 1_000_000_000
        )
        scheduleMihoyoGameRefresh(for: instanceID, fireAt: nowNanoseconds + intervalNanoseconds)
    }

    private func scheduleMihoyoGameRefresh(for instanceID: RuntimeInstanceID, fireAt fireNanoseconds: UInt64) {
        stopMihoyoGameTimer(for: instanceID, preservesNextFire: true)
        guard canRunInternalRefresh,
              mihoyoSession != nil,
              resolveCurrentMihoyoGameSlot(for: instanceID) != nil
        else {
            return
        }

        mihoyoGameNextFireNanoseconds[instanceID] = fireNanoseconds
        let now = nowNanoseconds
        guard fireNanoseconds > now else {
            mihoyoGameNextFireNanoseconds[instanceID] = nil
            fetchMihoyoGameStatus(for: instanceID)
            scheduleNextMihoyoGameRefresh(for: instanceID)
            return
        }

        let interval = TimeInterval(fireNanoseconds - now) / 1_000_000_000
        mihoyoGameTimers[instanceID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.mihoyoGameTimers[instanceID] = nil
                self?.mihoyoGameNextFireNanoseconds[instanceID] = nil
                self?.fetchMihoyoGameStatus(for: instanceID)
                self?.scheduleNextMihoyoGameRefresh(for: instanceID)
            }
        }
    }

    private func stopMihoyoGameTimer(for instanceID: RuntimeInstanceID, preservesNextFire: Bool) {
        mihoyoGameTimers[instanceID]?.invalidate()
        mihoyoGameTimers[instanceID] = nil
        if !preservesNextFire {
            mihoyoGameNextFireNanoseconds[instanceID] = nil
        }
    }

    private func restartMihoyoGameTimer(for keyID: Int) {
        guard let instanceID = ensureRuntimeInstance(for: keyID) else {
            return
        }

        stopMihoyoGameTimer(for: instanceID, preservesNextFire: false)
        scheduleNextMihoyoGameRefresh(for: instanceID)
    }

    private func resumeMihoyoGameRuntime(_ instanceID: RuntimeInstanceID) {
        guard canRunInternalRefresh,
              let resolved = resolveCurrentMihoyoGameSlot(for: instanceID)
        else {
            return
        }

        guard mihoyoSession != nil else {
            if interactionState.setMihoyoGameLastResult(.loginRequired, for: resolved.slot.keyID) {
                syncKeyDisplay(keyID: resolved.slot.keyID)
            }
            return
        }

        if let nextFireNanoseconds = mihoyoGameNextFireNanoseconds[instanceID] {
            scheduleMihoyoGameRefresh(for: instanceID, fireAt: nextFireNanoseconds)
        } else {
            scheduleNextMihoyoGameRefresh(for: instanceID)
        }

        if resolved.config.lastResult == nil {
            fetchMihoyoGameStatus(for: instanceID)
        }
    }

    private func requestBrightnessUpdate(percent: Int) {
        guard case .connected = status else {
            return
        }

        let request = BrightnessUpdateRequest(percent: DeckBrightnessConfiguration.clamped(percent))
        latestBrightnessUpdate = request
        brightnessUpdateRevision += 1

        guard !brightnessUpdateInProgress else {
            return
        }

        startBrightnessCommand(request: request, revision: brightnessUpdateRevision)
    }

    private func startBrightnessCommand(request: BrightnessUpdateRequest, revision: Int) {
        brightnessUpdateInProgress = true
        let syncer = syncer
        deviceCommandQueue.async { [weak self] in
            let result = syncer.setBrightness(percent: request.percent)
            DispatchQueue.main.async { [weak self] in
                self?.finishBrightnessCommand(request: request, revision: revision, result: result)
            }
        }
    }

    private func finishBrightnessCommand(
        request: BrightnessUpdateRequest,
        revision: Int,
        result: H200DeckCommandResult
    ) {
        if case let .failure(error, _) = result {
            brightnessUpdateInProgress = false
            alert = H200ConnectionAlert(syncFailure: error)
            return
        }

        if brightnessUpdateRevision != revision, let latestBrightnessUpdate {
            startBrightnessCommand(request: latestBrightnessUpdate, revision: brightnessUpdateRevision)
            return
        }

        brightnessUpdateInProgress = false
    }

    @discardableResult
    private func persistCurrentConfiguration() -> DeckConfigurationSaveResult {
        configurationStore.saveInteractionState(interactionState, for: layout)
    }

    private func syncCurrentDisplays() {
        guard case .connected = status, syncSummary != nil else {
            return
        }

        let displays = interactionState.displays(for: layout)
        let generation = deviceCommandGeneration
        let syncer = syncer
        deviceCommandQueue.async { [weak self] in
            let result = syncer.sendStartupPackage(displays: displays)
            DispatchQueue.main.async { [weak self] in
                self?.finishDisplaySync(result, generation: generation)
            }
        }
    }

    private func syncKeyDisplays(keyIDs: Set<Int>) {
        displayRevision += 1
        if syncSummary == nil {
            needsFullDisplaySyncAfterStartup = true
        }
        guard case .connected = status, syncSummary != nil else {
            return
        }

        let displays = layout.keys
            .filter { keyIDs.contains($0.id) }
            .map { interactionState.display(for: $0) }
        guard !displays.isEmpty else {
            return
        }

        let generation = deviceCommandGeneration
        let syncer = syncer
        deviceCommandQueue.async { [weak self] in
            let result = syncer.sendPartialPackage(displays: displays)
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.deviceCommandGeneration else {
                    return
                }

                self.finishDisplaySync(result, generation: generation)
            }
        }
    }

    private func syncKeyDisplay(
        keyID: Int,
        completion: ((H200DeckSyncResult) -> Void)? = nil
    ) {
        displayRevision += 1
        if syncSummary == nil {
            needsFullDisplaySyncAfterStartup = true
        }
        guard case .connected = status, syncSummary != nil,
              let key = layout.keys.first(where: { $0.id == keyID })
        else {
            return
        }

        let display = interactionState.display(for: key)
        let generation = deviceCommandGeneration
        let syncer = syncer
        deviceCommandQueue.async { [weak self] in
            let result = syncer.sendPartialPackage(displays: [display])
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.deviceCommandGeneration else {
                    return
                }

                self.finishDisplaySync(result, generation: generation)
                completion?(result)
            }
        }
    }

    private func cancelCurrentPageRuntime() {
        pauseCurrentPageRuntime()
    }

    private func startCurrentPageRuntime() {
        resumeCurrentPageRuntime()
    }

    private func finishDisplaySync(_ result: H200DeckSyncResult, generation: Int) {
        guard generation == deviceCommandGeneration else {
            return
        }

        switch result {
        case let .success(summary):
            syncSummary = summary
        case let .failure(error, _):
            alert = H200ConnectionAlert(syncFailure: error)
        }
    }

    private func cancelAllLongPressTasks() {
        for task in longPressTasks.values {
            task.cancel()
        }

        longPressTasks.removeAll()
        longPressResetKeyIDs.removeAll()
    }

    private func cancelAllMihoyoGameTimers(preservesNextFire: Bool = false) {
        for timer in mihoyoGameTimers.values {
            timer.invalidate()
        }

        mihoyoGameTimers.removeAll()
        if !preservesNextFire {
            mihoyoGameNextFireNanoseconds.removeAll()
        }
    }

    private func cancelAllMihoyoGameFetchTasks() {
        for task in mihoyoGameFetchTasks.values {
            task.cancel()
        }

        mihoyoGameFetchTasks.removeAll()
    }
}

private extension Sub2APICapacityResult {
    var isTokenUnavailable: Bool {
        switch self {
        case .invalidToken, .tokenExpired:
            return true
        case .success, .notFound, .networkError:
            return false
        }
    }
}

private extension Sub2APIGroupListResult {
    var isTokenUnavailable: Bool {
        switch self {
        case .invalidToken, .tokenExpired:
            return true
        case .success, .networkError:
            return false
        }
    }
}

enum H200ConnectionStatus: Equatable {
    case checking
    case connected(H200DeviceIdentity)
    case notConnected
    case communicationPortOccupied(HIDReturnCode)
    case occupied(H200DeviceIdentity, HIDReturnCode)
    case permissionDenied(H200DeviceIdentity, HIDReturnCode)
    case openFailed(H200DeviceIdentity, HIDReturnCode)
    case managerOpenFailed(HIDReturnCode)

    init(result: H200DiscoveryResult) {
        switch result {
        case let .connected(device):
            self = .connected(device)
        case .notConnected:
            self = .notConnected
        case let .communicationPortOccupied(code):
            self = .communicationPortOccupied(code)
        case let .occupied(device, code):
            self = .occupied(device, code)
        case let .permissionDenied(device, code):
            self = .permissionDenied(device, code)
        case let .openFailed(device, code):
            self = .openFailed(device, code)
        case let .managerOpenFailed(code):
            self = .managerOpenFailed(code)
        }
    }
}

struct H200ConnectionAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    init?(result: H200DiscoveryResult) {
        switch result {
        case .connected:
            return nil
        case .notConnected:
            title = "未检测到 H200"
            message = "请确认 Ulanzi Deck H200 已通过 USB-C 连接并处于开机状态，然后重试。"
        case let .communicationPortOccupied(code):
            title = "H200 通信端口被占用"
            message = "有其他应用正在占用 H200 通信端口。请关闭 Ulanzi Studio 或其他控制软件后重试。返回码：\(code.name)。"
        case let .occupied(device, code):
            title = "H200 通信端口被占用"
            message = "检测到 H200 通信接口 \(device.shortIdentifier)，但有其他应用正在占用 H200 通信端口。请关闭 Ulanzi Studio 或其他控制软件后重试。返回码：\(code.name)。"
        case let .permissionDenied(device, code):
            title = "没有权限访问 H200"
            message = "检测到 H200 通信接口 \(device.shortIdentifier)，但 macOS 拒绝访问。返回码：\(code.name)。"
        case let .openFailed(device, code):
            title = "无法打开 H200"
            message = "检测到 H200 通信接口 \(device.shortIdentifier)，但打开失败。返回码：\(code.name)。"
        case let .managerOpenFailed(code):
            title = "无法扫描 HID 设备"
            message = "macOS HID 管理器初始化失败。返回码：\(code.name)。"
        }
    }

    init(syncFailure: H200DeckSyncFailure) {
        title = syncFailure.alertTitle
        message = syncFailure.alertMessage
    }
}

extension H200DeviceIdentity {
    var shortIdentifier: String {
        let location = String(format: "0x%08x", locationID)
        let vid = String(format: "0x%04x", vendorID)
        let pid = String(format: "0x%04x", productID)

        if serialNumber.isEmpty {
            return "\(vid):\(pid), location \(location)"
        }

        return "\(vid):\(pid), serial \(serialNumber), location \(location)"
    }
}

extension H200ConnectionModel: BrightnessAdjusting {
    var canAdjustBrightness: Bool {
        if case .connected = status, syncSummary != nil {
            return true
        }

        return false
    }

    func adjustBrightness(to percent: Int) {
        updateBrightnessPercent(percent, persist: false, forceSend: true)
    }
}
