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
    private var hasPersistedBrightnessPercent: Bool
    private let longPressDurationNanoseconds: UInt64
    private let brightnessUpdateQueue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.H200BrightnessUpdate")
    private var longPressTasks: [Int: Task<Void, Never>] = [:]
    private var longPressResetKeyIDs: Set<Int> = []
    private var brightnessUpdateRevision = 0
    private var brightnessUpdateInProgress = false
    private var latestBrightnessUpdate: BrightnessUpdateRequest?

    private struct BrightnessUpdateRequest {
        let percent: Int
    }

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        folderOpener: FinderFolderOpening? = nil,
        longPressDurationNanoseconds: UInt64 = 1_000_000_000
    ) {
        self.discovery = discovery
        self.syncer = syncer
        self.configurationStore = configurationStore
        self.folderOpener = folderOpener ?? FinderFolderOpener()
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
        persistCurrentConfiguration()
        syncCurrentDisplays()
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
                syncCurrentDisplays()
            }
        case .some(.openFolder):
            openFolder(for: keyID)
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
            syncCurrentDisplays()
        }
    }

    func setSelectedTallyDefaultValue(_ value: Int) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setTallyDefaultValue(value, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncCurrentDisplays()
        }
    }

    func setSelectedFolderPath(_ path: String) {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return
        }

        if interactionState.setFolderPath(path, for: selectedKeyID) {
            persistCurrentConfiguration()
            syncCurrentDisplays()
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
            syncCurrentDisplays()
        }
    }

    private func openFolder(for keyID: Int) {
        guard let path = interactionState.folderPath(for: keyID), !path.isEmpty else {
            return
        }

        _ = folderOpener.openFolder(at: path)
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

    private func cancelAllLongPressTasks() {
        for task in longPressTasks.values {
            task.cancel()
        }

        longPressTasks.removeAll()
        longPressResetKeyIDs.removeAll()
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
