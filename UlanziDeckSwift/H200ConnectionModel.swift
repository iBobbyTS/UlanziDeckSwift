import AppKit
import Combine
import Foundation

@MainActor
final class H200ConnectionModel: ObservableObject {
    @Published private(set) var status: H200ConnectionStatus = .checking
    @Published private(set) var syncSummary: H200DeckSyncSummary?
    @Published private(set) var interactionState = DeckGridInteractionState(layout: .h200Prototype)
    @Published private(set) var brightnessPercent = DeckBrightnessConfiguration.defaultPercent
    @Published var alert: H200ConnectionAlert?

    private let layout = DeckGridLayout.h200Prototype
    private let discovery: H200Discovering
    private let syncer: H200DeckSyncing
    private let configurationStore: DeckConfigurationStoring
    private let folderOpener: FinderFolderOpening
    private let smbServerConnector: SMBServerConnecting
    private let sub2APIFetcher: Sub2APIFetching
    private var hasPersistedBrightnessPercent: Bool
    private let longPressDurationNanoseconds: UInt64
    private let brightnessUpdateQueue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.H200BrightnessUpdate")
    private var longPressTasks: [Int: Task<Void, Never>] = [:]
    private var longPressResetKeyIDs: Set<Int> = []
    private var brightnessUpdateRevision = 0
    private var brightnessUpdateInProgress = false
    private var latestBrightnessUpdate: BrightnessUpdateRequest?
    private var sub2APITimers: [Int: Timer] = [:]
    private var sub2APIFetchTasks: [Int: Task<Void, Never>] = [:]

    private struct BrightnessUpdateRequest {
        let percent: Int
    }

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        folderOpener: FinderFolderOpening? = nil,
        smbServerConnector: SMBServerConnecting? = nil,
        sub2APIFetcher: Sub2APIFetching = Sub2APIFetcher(),
        longPressDurationNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.discovery = discovery
        self.syncer = syncer
        self.configurationStore = configurationStore
        self.folderOpener = folderOpener ?? FinderFolderOpener()
        self.smbServerConnector = smbServerConnector ?? SMBServerConnector()
        self.sub2APIFetcher = sub2APIFetcher
        self.longPressDurationNanoseconds = longPressDurationNanoseconds
        interactionState = configurationStore.loadInteractionState(for: layout) ?? DeckGridInteractionState(layout: layout)
        let loadedBrightnessPercent = configurationStore.loadBrightnessPercent()
        hasPersistedBrightnessPercent = loadedBrightnessPercent != nil
        brightnessPercent = loadedBrightnessPercent ?? DeckBrightnessConfiguration.defaultPercent
        self.syncer.setInputHandler { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleInputEvent(event)
            }
        }
    }

    deinit {
        syncer.setInputHandler(nil)
        syncer.close()
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

        longPressTasks[keyID]?.cancel()
        longPressTasks[keyID] = nil
        longPressResetKeyIDs.remove(keyID)
        stopSub2APITimer(for: keyID)
        sub2APIFetchTasks[keyID]?.cancel()
        sub2APIFetchTasks[keyID] = nil
        persistCurrentConfiguration()
        syncKeyDisplay(keyID: keyID)
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

        switch interactionState.configuration(for: keyID)?.function {
        case .some(.tally):
            if interactionState.triggerShortPress(keyID: keyID) {
                persistCurrentConfiguration()
                syncKeyDisplay(keyID: keyID)
            }
        case .some(.openFolder):
            openFolder(for: keyID)
        case .some(.connectSMBServer):
            connectSMBServer(for: keyID)
        case .some(.sub2API):
            fetchSub2API(for: keyID)
        case .some(.brightness), .some(.none), nil:
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
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
            if function == .sub2API {
                startSub2APITimer(for: selectedKeyID)
            } else {
                stopSub2APITimer(for: selectedKeyID)
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

    func setSelectedFolderPath(_ path: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setFolderPath(path, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
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

    func setSelectedSub2APIBaseURL(_ baseURL: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setSub2APIBaseURL(baseURL, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedSub2APITargetGroupID(_ groupID: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setSub2APITargetGroupID(groupID, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncKeyDisplay(keyID: selectedKeyID)
        }
    }

    func setSelectedSub2APIRefreshInterval(_ interval: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
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

        if interactionState.setSub2APIBearerKey(bearerKey, for: selectedKeyID) {
            persistCurrentConfiguration()
        }
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
        let didChange = brightnessPercent != clampedPercent

        brightnessPercent = clampedPercent
        if persist {
            hasPersistedBrightnessPercent = true
            configurationStore.saveBrightnessPercent(clampedPercent)
        }
        guard didChange || forceSend else {
            return
        }

        requestBrightnessUpdate(percent: clampedPercent)
    }

    private func refresh() {
        cancelAllLongPressTasks()
        cancelAllSub2APITimers()
        cancelAllSub2APIFetchTasks()
        syncer.close()
        status = .checking
        syncSummary = nil
        alert = nil

        let result = discovery.discoverH200()
        status = H200ConnectionStatus(result: result)
        alert = H200ConnectionAlert(result: result)

        guard case .connected = result else {
            return
        }

        let initialDisplays = interactionState.displays(for: layout)
        switch syncer.sendStartupPackage(displays: initialDisplays) {
        case let .success(summary):
            syncSummary = summary
            if hasPersistedBrightnessPercent {
                requestBrightnessUpdate(percent: brightnessPercent)
            }
        case let .failure(error):
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
        guard let path = interactionState.folderPath(for: keyID), !path.isEmpty else {
            return
        }

        _ = folderOpener.openFolder(at: path)
    }

    private func connectSMBServer(for keyID: Int) {
        let address = interactionState.smbServerAddress(for: keyID)
        guard !address.isEmpty else {
            return
        }

        _ = smbServerConnector.connect(to: address)
    }

    private func fetchSub2API(for keyID: Int) {
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard !config.baseURL.isEmpty, config.targetGroupID > 0, !config.bearerKey.isEmpty else {
            return
        }

        sub2APIFetchTasks[keyID]?.cancel()
        let fetcher = sub2APIFetcher
        let baseURL = config.baseURL
        let targetGroupID = config.targetGroupID
        let bearerKey = config.bearerKey
        sub2APIFetchTasks[keyID] = Task { @MainActor [weak self] in
            let result = await fetcher.fetchCapacitySummary(baseURL: baseURL, targetGroupID: targetGroupID, bearerKey: bearerKey)
            guard !Task.isCancelled else { return }

            guard let self else { return }
            self.interactionState.setSub2APILastResult(result, for: keyID)
            self.persistCurrentConfiguration()
            self.syncKeyDisplay(keyID: keyID)
        }
    }

    private func startSub2APITimer(for keyID: Int) {
        stopSub2APITimer(for: keyID)
        let config = interactionState.sub2APIConfiguration(for: keyID)
        guard interactionState.configuration(for: keyID)?.function == .sub2API,
              config.refreshInterval >= 5
        else {
            return
        }

        let interval = TimeInterval(config.refreshInterval)
        sub2APITimers[keyID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchSub2API(for: keyID)
            }
        }
    }

    private func stopSub2APITimer(for keyID: Int) {
        sub2APITimers[keyID]?.invalidate()
        sub2APITimers[keyID] = nil
    }

    private func restartSub2APITimer(for keyID: Int) {
        startSub2APITimer(for: keyID)
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
        brightnessUpdateQueue.async { [weak self] in
            let error = syncer.setBrightness(percent: request.percent)
            DispatchQueue.main.async { [weak self] in
                self?.finishBrightnessCommand(request: request, revision: revision, error: error)
            }
        }
    }

    private func finishBrightnessCommand(
        request: BrightnessUpdateRequest,
        revision: Int,
        error: H200DeckSyncFailure?
    ) {
        if let error {
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

        switch syncer.sendStartupPackage(displays: interactionState.displays(for: layout)) {
        case let .success(summary):
            syncSummary = summary
        case let .failure(error):
            alert = H200ConnectionAlert(syncFailure: error)
        }
    }

    private func syncKeyDisplay(keyID: Int) {
        guard case .connected = status, syncSummary != nil,
              let key = layout.keys.first(where: { $0.id == keyID })
        else {
            return
        }

        let display = interactionState.display(for: key)
        switch syncer.sendPartialPackage(displays: [display]) {
        case let .success(summary):
            syncSummary = summary
        case let .failure(error):
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
