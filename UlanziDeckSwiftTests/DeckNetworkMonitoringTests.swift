import Foundation
import Testing
@testable import UlanziDeckSwift

@Suite(.serialized)
struct DeckNetworkMonitoringTests {

    // MARK: - 网络恢复触发补抓

    @MainActor
    @Test("断网失败的 usage 键在网络恢复事件后立即补抓成功，不等待下一个刷新周期")
    func networkRecoveryTriggersImmediateRefetchForUsageKeyThatFailedDuringOutage() async throws {
        let identity = makeTestDeviceIdentity()
        let networkMonitor = FakeNetworkMonitor()
        let fetcher = FakeCodexUsageFetcher()
        fetcher.queueResult(.networkError("断网中"))

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.codexUsage, to: 1)
        _ = state.setCodexUsageAuthSource(.manualJSON, for: 1)
        _ = state.setCodexUsageManualAuthData(testCodexManualAuthJSON(), for: 1)
        // 60 分钟刷新间隔：失败后的下一次定时重试远在测试时长之外，
        // 从而证明补抓只能来自网络恢复事件。
        _ = state.setCodexUsageRefreshIntervalMinutes(60, for: 1)

        let syncer = FakeNetworkTestSyncer()
        let model = H200ConnectionModel(
            discovery: FakeNetworkTestDiscovery(results: [.connected(identity)]),
            deviceMonitor: FakeNetworkTestDeviceMonitor(),
            networkMonitor: networkMonitor,
            syncer: syncer,
            configurationStore: FakeNetworkTestConfigurationStore(loadedState: state),
            codexUsageFetcher: fetcher
        )

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && fetcher.requestCount == 1
                && model.interactionState.codexUsageConfiguration(for: 1).lastResult != nil
        }
        guard case .networkError = model.interactionState.codexUsageConfiguration(for: 1).lastResult else {
            Issue.record("首次抓取应记录网络错误结果")
            return
        }

        // 网络恢复：后续抓取返回成功
        fetcher.queueResult(.success(testCodexUsageQuota()))
        await networkMonitor.triggerPathSatisfiedAndWait()

        try await waitUntil {
            fetcher.requestCount == 2
                && model.interactionState.codexUsageConfiguration(for: 1).lastResult != nil
        }
        guard case .success = model.interactionState.codexUsageConfiguration(for: 1).lastResult else {
            Issue.record("网络恢复后应补抓并落地成功结果")
            return
        }
        #expect(fetcher.requestCount == 2)
        // 网络恢复不是设备事件：不触发启动包；部分包共两次
        // （首次失败态显示 + 补抓成功后的显示更新）
        #expect(syncer.sentStartupDisplays.count == 1)
        #expect(syncer.sentPartialDisplays.count == 2)
    }

    @MainActor
    @Test("快照仍新鲜的 usage 键在网络恢复后保持原节奏，不额外抓取")
    func networkRecoveryKeepsFreshUsageKeyOnOriginalRefreshCadence() async throws {
        let identity = makeTestDeviceIdentity()
        let networkMonitor = FakeNetworkMonitor()
        let fetcher = FakeCodexUsageFetcher()
        fetcher.queueResult(.success(testCodexUsageQuota()))

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.codexUsage, to: 1)
        _ = state.setCodexUsageAuthSource(.manualJSON, for: 1)
        _ = state.setCodexUsageManualAuthData(testCodexManualAuthJSON(), for: 1)
        _ = state.setCodexUsageRefreshIntervalMinutes(60, for: 1)

        let model = H200ConnectionModel(
            discovery: FakeNetworkTestDiscovery(results: [.connected(identity)]),
            deviceMonitor: FakeNetworkTestDeviceMonitor(),
            networkMonitor: networkMonitor,
            syncer: FakeNetworkTestSyncer(),
            configurationStore: FakeNetworkTestConfigurationStore(loadedState: state),
            codexUsageFetcher: fetcher
        )

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && fetcher.requestCount == 1
                && model.interactionState.codexUsageConfiguration(for: 1).lastResult != nil
        }
        guard case .success = model.interactionState.codexUsageConfiguration(for: 1).lastResult else {
            Issue.record("首次抓取应成功并形成新鲜快照")
            return
        }

        await networkMonitor.triggerPathSatisfiedAndWait()

        // resume 的 wait 分支只重排 Timer，不派发抓取 Task；
        // 屏障之后 requestCount 必须保持不变。
        #expect(fetcher.requestCount == 1)
    }

    @MainActor
    @Test("设备断开期间网络恢复仍触发补抓：联网刷新离线继续，且不发启动包")
    func networkRecoveryDuringDeviceDisconnectStillRefreshesUsageKey() async throws {
        let identity = makeTestDeviceIdentity()
        let networkMonitor = FakeNetworkMonitor()
        let deviceMonitor = FakeNetworkTestDeviceMonitor()
        let fetcher = FakeCodexUsageFetcher()
        fetcher.queueResult(.networkError("断网中"))
        // 设备拔线会触发一次离线 resume 补抓，同样失败
        fetcher.queueResult(.networkError("断网中"))

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.codexUsage, to: 1)
        _ = state.setCodexUsageAuthSource(.manualJSON, for: 1)
        _ = state.setCodexUsageManualAuthData(testCodexManualAuthJSON(), for: 1)
        _ = state.setCodexUsageRefreshIntervalMinutes(60, for: 1)

        let syncer = FakeNetworkTestSyncer()
        let model = H200ConnectionModel(
            discovery: FakeNetworkTestDiscovery(results: [.connected(identity)]),
            deviceMonitor: deviceMonitor,
            networkMonitor: networkMonitor,
            syncer: syncer,
            configurationStore: FakeNetworkTestConfigurationStore(loadedState: state),
            codexUsageFetcher: fetcher
        )

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity) && fetcher.requestCount == 1
        }

        // 拔线：状态离线，且离线 resume 会再补抓一次（同样失败）
        await deviceMonitor.triggerDeviceRemovedAndWait()
        try await waitUntil { model.status == .notConnected }
        try await waitUntil { fetcher.requestCount == 2 }

        // 网络恢复（设备仍离线）：立即补抓成功
        fetcher.queueResult(.success(testCodexUsageQuota()))
        let partialCountAfterRemoval = syncer.sentPartialDisplays.count
        await networkMonitor.triggerPathSatisfiedAndWait()

        try await waitUntil {
            fetcher.requestCount == 3
                && model.interactionState.codexUsageConfiguration(for: 1).lastResult != nil
        }
        guard case .success = model.interactionState.codexUsageConfiguration(for: 1).lastResult else {
            Issue.record("设备离线期间网络恢复也应补抓成功")
            return
        }
        #expect(model.status == .notConnected)
        // 设备离线：拔线后的网络刷新与补抓都不产生任何设备写入
        #expect(syncer.sentStartupDisplays.count == 1)
        #expect(syncer.sentPartialDisplays.count == partialCountAfterRemoval)
    }

    @MainActor
    @Test("启动同步完成前的网络恢复事件无害，之后首次抓取正常进行")
    func networkRecoveryBeforeStartupSyncIsHarmlessAndLaunchFetchStillRuns() async throws {
        let identity = makeTestDeviceIdentity()
        let networkMonitor = FakeNetworkMonitor()
        let fetcher = FakeCodexUsageFetcher()
        fetcher.queueResult(.success(testCodexUsageQuota()))

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.codexUsage, to: 1)
        _ = state.setCodexUsageAuthSource(.manualJSON, for: 1)
        _ = state.setCodexUsageManualAuthData(testCodexManualAuthJSON(), for: 1)
        _ = state.setCodexUsageRefreshIntervalMinutes(60, for: 1)

        let model = H200ConnectionModel(
            discovery: FakeNetworkTestDiscovery(results: [.connected(identity)]),
            deviceMonitor: FakeNetworkTestDeviceMonitor(),
            networkMonitor: networkMonitor,
            syncer: FakeNetworkTestSyncer(),
            configurationStore: FakeNetworkTestConfigurationStore(loadedState: state),
            codexUsageFetcher: fetcher
        )

        // 启动同步尚未完成：恢复事件应被 canRunInternalRefresh 挡下，不产生抓取
        await networkMonitor.triggerPathSatisfiedAndWait()
        #expect(fetcher.requestCount == 0)

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity) && fetcher.requestCount == 1
        }
        #expect(fetcher.requestCount == 1)
    }

    // MARK: - 监视器本身

    @Test("路径翻转判定真值表：只有 false→true 才是恢复")
    func pathTransitionTruthTable() {
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: nil, isSatisfied: true) == false)
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: nil, isSatisfied: false) == false)
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: false, isSatisfied: true) == true)
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: false, isSatisfied: false) == false)
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: true, isSatisfied: true) == false)
        #expect(DeckNetworkPathTransition.isRecovery(previousSatisfied: true, isSatisfied: false) == false)
    }

    @MainActor
    @Test("默认监视器为 Noop：模型启动时 start 一次，Noop 无副作用且幂等")
    func defaultMonitorIsNoopAndModelStartsItOnce() {
        let noop = H200ConnectionModel.makeDefaultNetworkMonitor()
        noop.onPathSatisfied = {}
        noop.start()
        noop.start()
        noop.stop()
        noop.stop()

        let networkMonitor = FakeNetworkMonitor()
        _ = H200ConnectionModel(
            discovery: FakeNetworkTestDiscovery(results: []),
            deviceMonitor: FakeNetworkTestDeviceMonitor(),
            networkMonitor: networkMonitor,
            syncer: FakeNetworkTestSyncer(),
            configurationStore: FakeNetworkTestConfigurationStore(loadedState: nil),
            codexUsageFetcher: FakeCodexUsageFetcher()
        )
        #expect(networkMonitor.startCallCount == 1)
        #expect(networkMonitor.onPathSatisfied != nil)
    }

    @Test("真实 DeckNetworkMonitor 生命周期幂等：重复 start/stop 与先 stop 均不崩溃")
    func realDeckNetworkMonitorLifecycleIsIdempotent() {
        let monitor = DeckNetworkMonitor()
        monitor.stop()
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }
}

// MARK: - Test Helpers & Fakes

private func testCodexManualAuthJSON() -> String {
    #"{"auth_mode":"chatgpt","tokens":{"access_token":"test-access-token","account_id":"test-account"}}"#
}

private func testCodexUsageQuota() -> UsageQuota {
    UsageQuota(
        remainingPercent: 84,
        resetAfterSeconds: 100,
        limitWindowSeconds: 200,
        usedPercent: 16
    )
}

private func makeTestDeviceIdentity() -> H200DeviceIdentity {
    H200DeviceIdentity(
        vendorID: H200DeviceTarget.vendorID,
        productID: H200DeviceTarget.productID,
        locationID: 0x01124300,
        primaryUsagePage: H200DeviceTarget.primaryUsagePage,
        primaryUsage: H200DeviceTarget.primaryUsage,
        maxInputReportSize: H200DeviceTarget.reportSize,
        maxOutputReportSize: H200DeviceTarget.reportSize,
        serialNumber: "test-device-serial",
        manufacturer: "rockchip",
        product: "Ulanzi Deck H200"
    )
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    condition: @MainActor () -> Bool
) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
            Issue.record("等待条件超时")
            return
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
}

@MainActor
private func mainActorBarrier() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
}

private final class FakeNetworkMonitor: DeckNetworkMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _onPathSatisfied: (@Sendable () -> Void)?
    private var _startCallCount = 0
    private var _stopCallCount = 0

    var onPathSatisfied: (@Sendable () -> Void)? {
        get { locked { _onPathSatisfied } }
        set { locked { _onPathSatisfied = newValue } }
    }

    var startCallCount: Int {
        locked { _startCallCount }
    }

    var stopCallCount: Int {
        locked { _stopCallCount }
    }

    func start() {
        locked { _startCallCount += 1 }
    }

    func stop() {
        locked { _stopCallCount += 1 }
    }

    @MainActor
    func triggerPathSatisfiedAndWait() async {
        let handler = locked { _onPathSatisfied }
        handler?()
        await mainActorBarrier()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeNetworkTestDeviceMonitor: H200DeviceMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _onDeviceMatched: (@Sendable () -> Void)?
    private var _onDeviceRemoved: (@Sendable () -> Void)?

    var onDeviceMatched: (@Sendable () -> Void)? {
        get { locked { _onDeviceMatched } }
        set { locked { _onDeviceMatched = newValue } }
    }

    var onDeviceRemoved: (@Sendable () -> Void)? {
        get { locked { _onDeviceRemoved } }
        set { locked { _onDeviceRemoved = newValue } }
    }

    func start() {}
    func stop() {}

    @MainActor
    func triggerDeviceRemovedAndWait() async {
        let handler = locked { _onDeviceRemoved }
        handler?()
        await mainActorBarrier()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeNetworkTestDiscovery: H200Discovering, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [H200DiscoveryResult]

    init(results: [H200DiscoveryResult]) {
        self.results = results
    }

    func discoverH200() -> H200DiscoveryResult {
        locked {
            guard !results.isEmpty else {
                return .notConnected
            }
            return results.removeFirst()
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeNetworkTestSyncer: H200DeckSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var _closeCallCount = 0
    private var _sentStartupDisplays: [[DeckKeyDisplay]] = []
    private var _sentPartialDisplays: [[DeckKeyDisplay]] = []

    var closeCallCount: Int {
        locked { _closeCallCount }
    }

    var sentStartupDisplays: [[DeckKeyDisplay]] {
        locked { _sentStartupDisplays }
    }

    var sentPartialDisplays: [[DeckKeyDisplay]] {
        locked { _sentPartialDisplays }
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        locked {
            _sentStartupDisplays.append(displays)
            return .success(H200DeckSyncSummary(
                payloadByteCount: displays.count * 100,
                packetCount: 1,
                displayCount: displays.count
            ))
        }
    }

    func sendPartialPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        locked {
            _sentPartialDisplays.append(displays)
            return .success(H200DeckSyncSummary(
                payloadByteCount: displays.count * 100,
                packetCount: 1,
                displayCount: displays.count
            ))
        }
    }

    func close() {
        locked { _closeCallCount += 1 }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeNetworkTestConfigurationStore: DeckConfigurationStoring {
    private let loadedState: DeckGridInteractionState?

    init(loadedState: DeckGridInteractionState?) {
        self.loadedState = loadedState
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        loadedState
    }

    @discardableResult
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) -> DeckConfigurationSaveResult {
        .success
    }

    func loadBrightnessPercent() -> Int? {
        nil
    }

    func saveBrightnessPercent(_ percent: Int) {}

    func loadFollowsBuiltInDisplayBrightness() -> Bool {
        false
    }

    func saveFollowsBuiltInDisplayBrightness(_ follows: Bool) {}
}

private final class FakeCodexUsageFetcher: CodexUsageFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var queuedResults: [CodexUsageResult] = []
    private var _requestCount = 0

    var requestCount: Int {
        locked { _requestCount }
    }

    func queueResult(_ result: CodexUsageResult) {
        locked { queuedResults.append(result) }
    }

    func fetchUsage(configuration: DeckKeyCodexUsageConfiguration) async -> CodexUsageResult {
        locked {
            _requestCount += 1
            if !queuedResults.isEmpty {
                return queuedResults.removeFirst()
            }
            return .networkError("测试默认网络错误")
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
