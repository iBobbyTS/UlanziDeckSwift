import AppKit
import Combine
import Foundation

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
    private var sub2APITimers: [Int: Timer] = [:]
    private var sub2APIFetchTasks: [Int: Task<Void, Never>] = [:]
    private var sub2APIGroupListTasks: [Int: Task<Void, Never>] = [:]
    private var sub2APIGroupListRefreshTasks: [Int: Task<Void, Never>] = [:]
    private var sub2APIGroupListLastRequestNanoseconds: [Int: UInt64] = [:]
    private var sub2APITokenPausedKeys: Set<PageKeyRuntimeID> = []
    private var mihoyoLoginTask: Task<Void, Never>?
    private var mihoyoGameTimers: [Int: Timer] = [:]
    private var mihoyoGameFetchTasks: [Int: Task<Void, Never>] = [:]
    private let sub2APIRefreshSecondDuration: TimeInterval
    private let sub2APIGroupListMinimumIntervalNanoseconds: UInt64
    private let mihoyoGameRefreshMinuteDuration: TimeInterval

    private struct BrightnessUpdateRequest {
        let percent: Int
    }

    private struct PageKeyRuntimeID: Hashable {
        let pageID: String
        let keyID: Int
    }

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        folderOpener: FinderFolderOpening? = nil,
        fileOpener: FinderFileOpening? = nil,
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
        guard interactionState.clearFunction(keyID: keyID) else {
            return
        }

        cancelRuntime(for: keyID)
        persistCurrentConfiguration()
        syncKeyDisplay(keyID: keyID)
    }

    func swapSquareKeyConfigurations(sourceKeyID: Int, targetKeyID: Int) {
        guard interactionState.canSwapSquareConfigurations(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID) else {
            return
        }

        let pageID = interactionState.currentPageID
        let sourceSub2APITokenPaused = isSub2APITokenPaused(for: sourceKeyID, pageID: pageID)
        let targetSub2APITokenPaused = isSub2APITokenPaused(for: targetKeyID, pageID: pageID)
        cancelRuntime(for: sourceKeyID, clearsSub2APITokenPause: false)
        cancelRuntime(for: targetKeyID, clearsSub2APITokenPause: false)
        guard interactionState.swapSquareConfigurations(sourceKeyID: sourceKeyID, targetKeyID: targetKeyID) else {
            return
        }
        setSub2APITokenPause(targetSub2APITokenPaused, for: sourceKeyID, pageID: pageID)
        setSub2APITokenPause(sourceSub2APITokenPaused, for: targetKeyID, pageID: pageID)

        persistCurrentConfiguration()
        restartRuntime(for: sourceKeyID)
        restartRuntime(for: targetKeyID)
        syncKeyDisplays(keyIDs: [sourceKeyID, targetKeyID])
    }

    func navigateKey(keyID: Int) {
        switch interactionState.configuration(for: keyID)?.function {
        case .pageFolder:
            enterPageFolder(for: keyID)
        case .pageBack:
            goBackPage()
        default:
            return
        }
    }

    func setKeyDisplayMode(_ displayMode: DeckKeyDisplayMode, for keyID: Int) {
        guard interactionState.setDisplayMode(displayMode, for: keyID) else {
            return
        }

        if displayMode != .function {
            cancelRuntime(for: keyID)
        }
        persistCurrentConfiguration()
        syncKeyDisplay(keyID: keyID)
    }

    private func enterPageFolder(for keyID: Int) {
        guard interactionState.pageID(for: keyID) != nil else {
            return
        }

        cancelCurrentPageRuntime()
        guard interactionState.enterPageFolder(keyID: keyID) else {
            startCurrentPageRuntime()
            return
        }

        syncCurrentDisplays()
        startCurrentPageRuntime()
    }

    private func goBackPage() {
        guard interactionState.currentPageID != DeckGridInteractionState.rootPageID else {
            return
        }

        cancelCurrentPageRuntime()
        guard interactionState.goBackPage() else {
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

        if interactionState.assign(function, to: selectedKeyID) {
            cancelRuntime(for: selectedKeyID)
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
            if function == .sub2API {
                fetchSub2API(for: selectedKeyID)
                scheduleSub2APIGroupListRefresh(for: selectedKeyID)
            }
            if function.game != nil {
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
            persistCurrentConfiguration()
            stopSub2APITimer(for: selectedKeyID)
            sub2APIFetchTasks[selectedKeyID]?.cancel()
            sub2APIFetchTasks[selectedKeyID] = nil
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
            persistCurrentConfiguration()
            stopSub2APITimer(for: selectedKeyID)
            sub2APIFetchTasks[selectedKeyID]?.cancel()
            sub2APIFetchTasks[selectedKeyID] = nil
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

        guard interactionState.sub2APIConfiguration(for: selectedKeyID).bearerKey != bearerKey else {
            return
        }

        if interactionState.setSub2APIBearerKey(bearerKey, for: selectedKeyID) {
            resumeSub2APIAfterBearerChange(for: selectedKeyID)
            persistCurrentConfiguration()
            stopSub2APITimer(for: selectedKeyID)
            sub2APIFetchTasks[selectedKeyID]?.cancel()
            sub2APIFetchTasks[selectedKeyID] = nil
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
        cancelAllMihoyoGameTimers()
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
        cancelAllSub2APITimers()
        cancelAllSub2APIFetchTasks()
        cancelAllSub2APIGroupListTasks()
        cancelAllMihoyoGameTimers()
        cancelAllMihoyoGameFetchTasks()
        syncer.setInternalRefreshPaused(true)
    }

    private func resumeInternalRefresh() {
        syncer.setInternalRefreshPaused(false)
        startCurrentPageRuntime()
        if mihoyoSession != nil {
            refreshAssignedMihoyoGameStatuses()
        }
    }

    private func refresh() {
        cancelAllLongPressTasks()
        cancelAllSub2APITimers()
        cancelAllSub2APIFetchTasks()
        cancelAllSub2APIGroupListTasks()
        cancelAllMihoyoGameTimers()
        cancelAllMihoyoGameFetchTasks()
        _ = interactionState.goToRootPage()
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
        case .left, .right:
            return
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

    private func connectSMBServer(for keyID: Int) {
        let address = interactionState.smbServerAddress(for: keyID)
        guard !address.isEmpty else {
            return
        }

        _ = smbServerConnector.connect(to: address)
    }

    private func pageKeyRuntimeID(for keyID: Int, pageID: String? = nil) -> PageKeyRuntimeID {
        PageKeyRuntimeID(pageID: pageID ?? interactionState.currentPageID, keyID: keyID)
    }

    private func isSub2APITokenPaused(for keyID: Int, pageID: String? = nil) -> Bool {
        sub2APITokenPausedKeys.contains(pageKeyRuntimeID(for: keyID, pageID: pageID))
    }

    private func pauseSub2APIForTokenError(keyID: Int, pageID: String) {
        sub2APITokenPausedKeys.insert(pageKeyRuntimeID(for: keyID, pageID: pageID))
        stopSub2APITimer(for: keyID)
        sub2APIGroupListRefreshTasks[keyID]?.cancel()
        sub2APIGroupListRefreshTasks[keyID] = nil
    }

    private func setSub2APITokenPause(_ paused: Bool, for keyID: Int, pageID: String? = nil) {
        let runtimeID = pageKeyRuntimeID(for: keyID, pageID: pageID)
        if paused {
            sub2APITokenPausedKeys.insert(runtimeID)
        } else {
            sub2APITokenPausedKeys.remove(runtimeID)
        }
    }

    private func resumeSub2APIAfterBearerChange(for keyID: Int) {
        sub2APITokenPausedKeys.remove(pageKeyRuntimeID(for: keyID))
    }

    private func clearSub2APITokenPause(for keyID: Int) {
        sub2APITokenPausedKeys.remove(pageKeyRuntimeID(for: keyID))
    }

    private func fetchSub2API(for keyID: Int) {
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard canRunInternalRefresh,
              interactionState.configuration(for: keyID)?.function == .sub2API,
              !isSub2APITokenPaused(for: keyID),
              !config.baseURL.isEmpty,
              config.targetGroupID > 0,
              !config.bearerKey.isEmpty
        else {
            return
        }

        sub2APIFetchTasks[keyID]?.cancel()
        let pageID = interactionState.currentPageID
        let fetcher = sub2APIFetcher
        let baseURL = config.baseURL
        let targetGroupID = config.targetGroupID
        let bearerKey = config.bearerKey
        sub2APIFetchTasks[keyID] = Task { @MainActor [weak self] in
            let result = await fetcher.fetchCapacitySummary(baseURL: baseURL, targetGroupID: targetGroupID, bearerKey: bearerKey)
            guard !Task.isCancelled else { return }

            guard let self else { return }
            let latestConfig = self.interactionState.sub2APIConfiguration(for: keyID)
            guard self.interactionState.currentPageID == pageID,
                  self.interactionState.configuration(for: keyID)?.function == .sub2API,
                  latestConfig.baseURL == baseURL,
                  latestConfig.targetGroupID == targetGroupID,
                  latestConfig.bearerKey == bearerKey
            else {
                return
            }

            self.interactionState.setSub2APILastResult(result, for: keyID)
            self.persistCurrentConfiguration()
            if result.isTokenUnavailable {
                self.pauseSub2APIForTokenError(keyID: keyID, pageID: pageID)
            }
            self.syncKeyDisplay(keyID: keyID) { [weak self] (result: H200DeckSyncResult) in
                guard case .success = result else {
                    return
                }

                guard let self,
                      self.canRunInternalRefresh,
                      !self.isSub2APITokenPaused(for: keyID, pageID: pageID)
                else {
                    return
                }

                self.scheduleNextSub2APIRefresh(for: keyID)
            }
        }
    }

    private func fetchSub2APIGroupList(for keyID: Int) {
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard canRunInternalRefresh,
              interactionState.configuration(for: keyID)?.function == .sub2API,
              !isSub2APITokenPaused(for: keyID)
        else {
            return
        }

        guard !config.baseURL.isEmpty, !config.bearerKey.isEmpty else {
            interactionState.setSub2APIGroupListState(
                .networkError("请先填写 Base URL 和 Bearer Key"),
                for: keyID
            )
            return
        }

        sub2APIGroupListTasks[keyID]?.cancel()
        interactionState.setSub2APIGroupListState(.loading, for: keyID)
        sub2APIGroupListLastRequestNanoseconds[keyID] = DispatchTime.now().uptimeNanoseconds
        let pageID = interactionState.currentPageID
        let fetcher = sub2APIFetcher
        let baseURL = config.baseURL
        let bearerKey = config.bearerKey
        sub2APIGroupListTasks[keyID] = Task { @MainActor [weak self] in
            let result = await fetcher.fetchCapacityGroups(baseURL: baseURL, bearerKey: bearerKey)
            guard !Task.isCancelled else { return }

            guard let self else { return }
            let latestConfig = self.interactionState.sub2APIConfiguration(for: keyID)
            guard self.interactionState.currentPageID == pageID,
                  self.interactionState.configuration(for: keyID)?.function == .sub2API,
                  latestConfig.baseURL == baseURL,
                  latestConfig.bearerKey == bearerKey
            else {
                return
            }

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
                self.pauseSub2APIForTokenError(keyID: keyID, pageID: pageID)
            }
            self.interactionState.setSub2APIGroupListState(groupListState, for: keyID)
        }
    }

    private func scheduleSub2APIGroupListRefresh(for keyID: Int) {
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard canRunInternalRefresh,
              interactionState.configuration(for: keyID)?.function == .sub2API,
              !isSub2APITokenPaused(for: keyID),
              !config.baseURL.isEmpty,
              !config.bearerKey.isEmpty
        else {
            sub2APIGroupListRefreshTasks[keyID]?.cancel()
            sub2APIGroupListRefreshTasks[keyID] = nil
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let minimumInterval = sub2APIGroupListMinimumIntervalNanoseconds
        guard let lastRequest = sub2APIGroupListLastRequestNanoseconds[keyID],
              now < lastRequest + minimumInterval
        else {
            sub2APIGroupListRefreshTasks[keyID]?.cancel()
            sub2APIGroupListRefreshTasks[keyID] = nil
            fetchSub2APIGroupList(for: keyID)
            return
        }

        let delayNanoseconds = lastRequest + minimumInterval - now
        let pageID = interactionState.currentPageID
        sub2APIGroupListRefreshTasks[keyID]?.cancel()
        sub2APIGroupListRefreshTasks[keyID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            guard self?.interactionState.currentPageID == pageID else {
                return
            }
            self?.sub2APIGroupListRefreshTasks[keyID] = nil
            self?.fetchSub2APIGroupList(for: keyID)
        }
    }

    private func fetchMihoyoGameStatus(for keyID: Int) {
        guard canRunInternalRefresh,
              let game = interactionState.mihoyoGame(for: keyID)
        else {
            return
        }

        guard let session = mihoyoSession else {
            if interactionState.setMihoyoGameLastResult(.loginRequired, for: keyID) {
                syncKeyDisplay(keyID: keyID)
            }
            return
        }

        mihoyoGameFetchTasks[keyID]?.cancel()
        let pageID = interactionState.currentPageID
        let service = mihoyoGameService
        mihoyoGameFetchTasks[keyID] = Task { @MainActor [weak self] in
            let result = await service.fetchDailyStatus(game: game, session: session)
            guard !Task.isCancelled else { return }

            guard let self else { return }
            guard self.interactionState.currentPageID == pageID,
                  self.mihoyoSession == session,
                  self.interactionState.mihoyoGame(for: keyID) == game
            else {
                return
            }

            self.interactionState.setMihoyoGameLastResult(result, for: keyID)
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
            self.syncKeyDisplay(keyID: keyID)
        }
    }

    private func invalidateMihoyoSession(
        loginState: MihoyoLoginState,
        keyResult: MihoyoGameStatusResult
    ) {
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = loginState
        cancelAllMihoyoGameTimers()
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: keyResult)
    }

    private func finishMihoyoLogin(_ session: MihoyoLoginSession) {
        mihoyoSession = session
        mihoyoSessionStore.saveSession(session)
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
        cancelAllMihoyoGameTimers()
        cancelAllMihoyoGameFetchTasks()
        markAllMihoyoKeys(result: .loginRequired)
    }

    private func expireMihoyoLogin(_ message: String) {
        mihoyoSession = nil
        mihoyoSessionStore.clearSession()
        mihoyoLoginState = .expired(message)
        cancelAllMihoyoGameTimers()
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

    private func scheduleNextSub2APIRefresh(for keyID: Int) {
        stopSub2APITimer(for: keyID)
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard canRunInternalRefresh,
              interactionState.configuration(for: keyID)?.function == .sub2API,
              !isSub2APITokenPaused(for: keyID),
              !config.baseURL.isEmpty,
              config.targetGroupID > 0,
              !config.bearerKey.isEmpty,
              config.refreshInterval >= 5
        else {
            return
        }

        let interval = TimeInterval(config.refreshInterval) * sub2APIRefreshSecondDuration
        sub2APITimers[keyID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sub2APITimers[keyID] = nil
                self?.fetchSub2API(for: keyID)
            }
        }
    }

    private func stopSub2APITimer(for keyID: Int) {
        sub2APITimers[keyID]?.invalidate()
        sub2APITimers[keyID] = nil
    }

    private func restartSub2APITimer(for keyID: Int) {
        guard canRunInternalRefresh,
              !isSub2APITokenPaused(for: keyID)
        else {
            return
        }

        guard interactionState.sub2APIConfiguration(for: keyID).lastResult != nil else {
            return
        }

        scheduleNextSub2APIRefresh(for: keyID)
    }

    private func startMihoyoGameTimer(for keyID: Int) {
        stopMihoyoGameTimer(for: keyID)
        guard canRunInternalRefresh,
              mihoyoSession != nil,
              interactionState.mihoyoGame(for: keyID) != nil
        else {
            return
        }

        let config = interactionState.mihoyoGameConfiguration(for: keyID)
        let interval = TimeInterval(config.refreshIntervalMinutes) * mihoyoGameRefreshMinuteDuration
        mihoyoGameTimers[keyID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchMihoyoGameStatus(for: keyID)
            }
        }
    }

    private func stopMihoyoGameTimer(for keyID: Int) {
        mihoyoGameTimers[keyID]?.invalidate()
        mihoyoGameTimers[keyID] = nil
    }

    private func restartMihoyoGameTimer(for keyID: Int) {
        startMihoyoGameTimer(for: keyID)
    }

    private func restartRuntime(for keyID: Int) {
        switch interactionState.configuration(for: keyID)?.function.scheduledRuntime {
        case .some(.sub2API):
            restartSub2APITimer(for: keyID)
        case .some(.mihoyoGame):
            restartMihoyoGameTimer(for: keyID)
        case nil:
            return
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

    private func persistCurrentConfiguration() {
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
        cancelAllLongPressTasks()
        cancelAllSub2APITimers()
        cancelAllSub2APIFetchTasks()
        cancelAllSub2APIGroupListTasks()
        cancelAllMihoyoGameTimers()
        cancelAllMihoyoGameFetchTasks()
    }

    private func startCurrentPageRuntime() {
        guard canRunInternalRefresh else {
            return
        }

        if mihoyoSession != nil {
            startAssignedMihoyoGameTimers()
        }
        refreshAssignedSub2APIStatuses()
    }

    private func cancelRuntime(for keyID: Int, clearsSub2APITokenPause: Bool = true) {
        longPressTasks[keyID]?.cancel()
        longPressTasks[keyID] = nil
        longPressResetKeyIDs.remove(keyID)
        stopSub2APITimer(for: keyID)
        sub2APIFetchTasks[keyID]?.cancel()
        sub2APIFetchTasks[keyID] = nil
        sub2APIGroupListTasks[keyID]?.cancel()
        sub2APIGroupListTasks[keyID] = nil
        sub2APIGroupListRefreshTasks[keyID]?.cancel()
        sub2APIGroupListRefreshTasks[keyID] = nil
        sub2APIGroupListLastRequestNanoseconds[keyID] = nil
        if clearsSub2APITokenPause {
            clearSub2APITokenPause(for: keyID)
        }
        stopMihoyoGameTimer(for: keyID)
        mihoyoGameFetchTasks[keyID]?.cancel()
        mihoyoGameFetchTasks[keyID] = nil
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

    private func cancelAllSub2APITimers() {
        for timer in sub2APITimers.values {
            timer.invalidate()
        }

        sub2APITimers.removeAll()
    }

    private func cancelAllSub2APIFetchTasks() {
        for task in sub2APIFetchTasks.values {
            task.cancel()
        }

        sub2APIFetchTasks.removeAll()
    }

    private func cancelAllSub2APIGroupListTasks() {
        for task in sub2APIGroupListTasks.values {
            task.cancel()
        }
        for task in sub2APIGroupListRefreshTasks.values {
            task.cancel()
        }

        sub2APIGroupListTasks.removeAll()
        sub2APIGroupListRefreshTasks.removeAll()
        sub2APIGroupListLastRequestNanoseconds.removeAll()
    }

    private func cancelAllMihoyoGameTimers() {
        for timer in mihoyoGameTimers.values {
            timer.invalidate()
        }

        mihoyoGameTimers.removeAll()
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
