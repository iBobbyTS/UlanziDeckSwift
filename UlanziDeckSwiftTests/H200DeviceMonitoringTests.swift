import Foundation
import Testing
@testable import UlanziDeckSwift

@Suite(.serialized)
struct H200DeviceMonitoringTests {

    @MainActor
    @Test("AC 1: connected 状态触发 removal → 离线且弹断线横幅，close 计数递增，旧 generation discovery 真实回调不落地")
    func connectedDeviceRemovalAndGenerationInvalidation() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity), .connected(identity)])
        let syncer = FakeSyncer()
        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil { model.status == .connected(identity) }
        #expect(model.status == .connected(identity))
        #expect(model.alert == nil)

        let closeCountBeforeRemoval = syncer.closeCallCount

        // 1. 拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")

        // 等待 close 真正执行完成（完成屏障）
        try await waitUntil { syncer.closeCallCount - closeCountBeforeRemoval >= 1 }
        #expect(syncer.closeCallCount - closeCountBeforeRemoval >= 1)

        // 2. 验证旧 generation 真实回调不落地：
        // 在离线状态下发起一次可控 refresh，在 discovery 阶段挂起，然后再次 removal（bump generation），
        // 随后放行 discovery 返回 connected，断言晚到的 connected 结果被 guard generation 丢弃，保持 notConnected
        let semaphore = DispatchSemaphore(value: 0)
        let secondDiscoverStarted = AtomicFlag()
        let secondDiscoverFinished = AtomicFlag()

        discovery.onDiscover = { count in
            if count == 2 {
                secondDiscoverStarted.set()
                _ = semaphore.wait(timeout: .now() + 2)
            }
        }
        discovery.onDiscoverCompleted = { count in
            if count == 2 {
                secondDiscoverFinished.set()
            }
        }

        monitor.triggerDeviceMatched()
        try await waitUntil { secondDiscoverStarted.isSet }
        #expect(model.status == .checking)

        // checking 中再次 removal，使 generation 再次递增并转入 notConnected
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.alert?.title == "H200 已断开")

        // 放行已挂起的第一轮旧 generation discovery
        semaphore.signal()
        // Producer 侧证据：FakeSyncer 收到启动包，证明 finishDiscovery 的 main.async 已入队
        try await waitUntil { syncer.sentStartupDisplays.count == 2 }
        await mainActorBarrier()

        // 断言晚到结果不覆盖 notConnected 与断线横幅
        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")
    }

    @MainActor
    @Test("AC 2: 完整链路恢复：连接 → removal → matching → 恢复，覆盖 14 格 displays 且 runtime 恢复执行")
    func fullReconnectionFlowRestoresDisplaysAndRuntime() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity), .connected(identity)])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-test-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && syncer.sentStartupDisplays.count == 1
                && fetcher.requestCount >= 1
        }

        // 1. 拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.status == .notConnected)
        #expect(model.syncSummary == nil)

        // 2. 插回
        monitor.triggerDeviceMatched()
        try await waitUntil {
            model.status == .connected(identity)
                && syncer.sentStartupDisplays.count == 2
        }

        // 3. 断言 discovery 调用次数为 2、启动包次数为 2、syncSummary 恢复
        #expect(discovery.discoverCallCount == 2)
        #expect(syncer.sentStartupDisplays.count == 2)
        #expect(model.syncSummary != nil)

        // 4. 恢复用启动包的 displays 覆盖当前页全部 14 格内容（逐格比对）
        let expectedDisplays = model.interactionState.displays(for: .h200Prototype)
        let latestDisplays = syncer.sentStartupDisplays.last!
        #expect(latestDisplays.count == 14)
        #expect(latestDisplays == expectedDisplays)

        // 5. 当前页 runtime 恢复：fetcher 再次被调用
        try await waitUntil { fetcher.requestCount >= 2 }
        #expect(fetcher.requestCount >= 2)
    }

    @MainActor
    @Test("R1: 亮度命令合并场景：A 在途合并 B，A 失败后重放 B 成功发送，inProgress 最终复位且后续调节仍工作")
    func brightnessCoalescingReplaysLatestAfterInFlightFailureAndResetsInProgress() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity)])
        let syncer = FakeSyncer()
        let semaphore = DispatchSemaphore(value: 0)
        let firstBrightnessStarted = AtomicFlag()
        let firstBrightnessFinished = AtomicFlag()

        syncer.onBrightness = { percent in
            if percent == 40 {
                firstBrightnessStarted.set()
                _ = semaphore.wait(timeout: .now() + 2)
            }
        }
        syncer.onBrightnessCompleted = { percent in
            if percent == 40 {
                firstBrightnessFinished.set()
            }
        }
        syncer.brightnessResult = .failure(.writeFailed(HIDReturnCode(rawValue: -1)), elapsedNanoseconds: 0)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil { model.status == .connected(identity) }
        let initialBrightnessCount = syncer.sentBrightnessPercents.count

        // 发送 A (40%)
        model.setBrightnessPercent(40)
        try await waitUntil { firstBrightnessStarted.isSet }

        // A 在途时调节 B (70%) 合并等待
        model.setBrightnessPercent(70)

        // 成功响应随后的 B 命令
        syncer.brightnessResult = .success(elapsedNanoseconds: 0)

        // 放行 A 失败返回
        semaphore.signal()
        try await waitUntil { firstBrightnessFinished.isSet }

        // 等待 B 发送并成功完成
        try await waitUntil {
            Array(syncer.sentBrightnessPercents.suffix(from: initialBrightnessCount)) == [40, 70]
        }
        await mainActorBarrier()

        #expect(Array(syncer.sentBrightnessPercents.suffix(from: initialBrightnessCount)) == [40, 70])

        // 后续再调节 C (90%) 仍能正常工作（证明 inProgress 已复位）
        model.setBrightnessPercent(90)
        try await waitUntil {
            Array(syncer.sentBrightnessPercents.suffix(from: initialBrightnessCount)) == [40, 70, 90]
        }
        #expect(Array(syncer.sentBrightnessPercents.suffix(from: initialBrightnessCount)) == [40, 70, 90])
    }

    @MainActor
    @Test("R2: 断线期间网络定时刷新照常进行，且受状态守卫拦截不向设备写入")
    func networkRefreshContinuesDuringDisconnectionWithoutDeviceWrites() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity)])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && fetcher.requestCount >= 1
        }

        await mainActorBarrier()
        let initialCommandCount = syncer.deviceCommandCallCount

        // 拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        let countAtRemoval = fetcher.requestCount
        // 断线期间推进网络刷新时序：断言离线期间连续完成至少两轮刷新
        try await waitUntil { fetcher.requestCount >= countAtRemoval + 2 }
        #expect(fetcher.requestCount >= countAtRemoval + 2)

        // 等待一个 MainActor 屏障确保数据更新回调到达
        await mainActorBarrier()

        // 断言 FakeSyncer 没有新增设备写命令（设备写被 guard case .connected 拦截）
        #expect(syncer.deviceCommandCallCount == initialCommandCount)
    }

    @MainActor
    @Test("W2: 重连探测失败（非 connected）落地时恢复已建立的应用内 runtime，网络刷新继续进行")
    func failedReconnectionDiscoveryResumesEstablishedRuntime() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        // 第一次启动成功 connected，重连 matching 探测返回 notConnected
        let discovery = FakeDiscovery(results: [.connected(identity), .notConnected])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        // 1. 启动并连接成功，runtime 建立
        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && fetcher.requestCount >= 1
        }

        await mainActorBarrier()
        let initialCommandCount = syncer.deviceCommandCallCount

        // 2. 拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        // 3. 触发重连 matching，但 discovery 探测返回 notConnected 失败落地
        monitor.triggerDeviceMatched()
        try await waitUntil {
            discovery.discoverCallCount == 2 && model.status == .notConnected
        }

        // 4. 断言网络 runtime 已恢复：fetcher 在失败落地后仍然连续完成至少两轮刷新
        let countAfterFailedReconnect = fetcher.requestCount
        try await waitUntil { fetcher.requestCount >= countAfterFailedReconnect + 2 }
        #expect(fetcher.requestCount >= countAfterFailedReconnect + 2)

        await mainActorBarrier()
        // 设备写仍被状态守卫拦截，FakeSyncer 设备命令记录不增加
        #expect(syncer.deviceCommandCallCount == initialCommandCount)
    }

    @MainActor
    @Test("AC 3: checking 期间 removal，在途结果不落地，最终保持 notConnected 且横幅存在")
    func removalDuringCheckingDiscardsInFlightResult() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity)])
        let syncer = FakeSyncer()
        let semaphore = DispatchSemaphore(value: 0)
        let discoveryStarted = AtomicFlag()
        let discoveryFinished = AtomicFlag()

        discovery.onDiscover = { _ in
            discoveryStarted.set()
            _ = semaphore.wait(timeout: .now() + 2)
        }
        discovery.onDiscoverCompleted = { _ in
            discoveryFinished.set()
        }

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil { discoveryStarted.isSet }
        #expect(model.status == .checking)
        let closeCountBeforeRemoval = syncer.closeCallCount

        // checking 中拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        // 放行 discovery 完成，等待 producer 侧证据：removal 排在 deviceCommandQueue 的 close 在 sendStartupPackage 之后执行完成（证明启动包已发完、finishStartupSync 的 main.async 已入队）
        semaphore.signal()
        try await waitUntil { syncer.closeCallCount > closeCountBeforeRemoval }
        await mainActorBarrier()

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")
        #expect(model.syncSummary == nil)
    }

    @MainActor
    @Test("AC 4: checking 期间 matching：若落地非 connected 自动补一次 refresh，若落地 connected 则不叠加")
    func matchingDuringCheckingHandlesPendingAndIdempotency() async throws {
        let identity = makeTestDeviceIdentity()

        // 子用例 A：第一轮结果为 notConnected，pending 标志触发补发 refresh 并最终 connected
        do {
            let monitor = FakeDeviceMonitor()
            let discovery = FakeDiscovery(results: [.notConnected, .connected(identity)])
            let syncer = FakeSyncer()
            let semaphore = DispatchSemaphore(value: 0)
            let firstDiscoverStarted = AtomicFlag()
            let firstDiscoverFinished = AtomicFlag()

            discovery.onDiscover = { count in
                if count == 1 {
                    firstDiscoverStarted.set()
                    _ = semaphore.wait(timeout: .now() + 2)
                }
            }
            discovery.onDiscoverCompleted = { count in
                if count == 1 {
                    firstDiscoverFinished.set()
                }
            }

            let model = H200ConnectionModel(
                discovery: discovery,
                deviceMonitor: monitor,
                syncer: syncer
            )

            model.checkOnLaunch()
            try await waitUntil { firstDiscoverStarted.isSet }
            #expect(model.status == .checking)

            // 触发 matching 并等待 MainActor 处理完毕该事件（设置 pendingDeviceMatched = true）
            await monitor.triggerDeviceMatchedAndWait()

            // 确定性在 pending 设置后放行 discovery
            semaphore.signal()
            try await waitUntil { firstDiscoverFinished.isSet }

            try await waitUntil { model.status == .connected(identity) }
            #expect(model.status == .connected(identity))
            #expect(discovery.discoverCallCount == 2)
        }

        // 子用例 B：第一轮结果为 connected，清除 pending 且不叠加 refresh
        do {
            let monitor = FakeDeviceMonitor()
            let discovery = FakeDiscovery(results: [.connected(identity)])
            let syncer = FakeSyncer()
            let semaphore = DispatchSemaphore(value: 0)
            let firstDiscoverStarted = AtomicFlag()
            let firstDiscoverFinished = AtomicFlag()

            discovery.onDiscover = { count in
                if count == 1 {
                    firstDiscoverStarted.set()
                    _ = semaphore.wait(timeout: .now() + 2)
                }
            }
            discovery.onDiscoverCompleted = { count in
                if count == 1 {
                    firstDiscoverFinished.set()
                }
            }

            let model = H200ConnectionModel(
                discovery: discovery,
                deviceMonitor: monitor,
                syncer: syncer
            )

            model.checkOnLaunch()
            try await waitUntil { firstDiscoverStarted.isSet }
            #expect(model.status == .checking)

            // 触发 matching 并等待 MainActor 处理完毕该事件
            await monitor.triggerDeviceMatchedAndWait()

            // 确定性在 pending 设置后放行 discovery
            semaphore.signal()
            try await waitUntil { firstDiscoverFinished.isSet }

            try await waitUntil { model.status == .connected(identity) }
            await mainActorBarrier()

            #expect(discovery.discoverCallCount == 1)
            #expect(syncer.sentStartupDisplays.count == 1)
        }
    }

    @MainActor
    @Test("AC 5: occupied 状态下 removal 收敛为 notConnected")
    func occupiedStateRemovalConvergesToNotConnected() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let code = HIDReturnCode(rawValue: Int32(bitPattern: 0xe00002c5)) // exclusiveAccess
        let discovery = FakeDiscovery(results: [.occupied(identity, code)])
        let syncer = FakeSyncer()

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil {
            if case .occupied = model.status { return true }
            return false
        }

        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")
    }

    @MainActor
    @Test("AC 6: 亮度请求在途时 removal，旧结果不覆盖断线横幅且无新增设备写调用")
    func inFlightBrightnessCommandRemovalPreventsAlertOverwriteAndNewCommands() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity)])
        let syncer = FakeSyncer()
        let semaphore = DispatchSemaphore(value: 0)
        let brightnessStarted = AtomicFlag()
        let brightnessFinished = AtomicFlag()

        syncer.onBrightness = { _ in
            brightnessStarted.set()
            _ = semaphore.wait(timeout: .now() + 2)
        }
        syncer.onBrightnessCompleted = { _ in
            brightnessFinished.set()
        }
        syncer.brightnessResult = .failure(.writeFailed(HIDReturnCode(rawValue: -1)), elapsedNanoseconds: 0)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil { model.status == .connected(identity) }

        model.setBrightnessPercent(80)
        try await waitUntil { brightnessStarted.isSet }

        let commandCountBeforeRemoval = syncer.deviceCommandCallCount
        let closeCountBeforeRemoval = syncer.closeCallCount

        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.alert?.title == "H200 已断开")

        // 放行亮度命令完成，等待 producer 侧证据：deviceCommandQueue 串行队列上排在 finishBrightnessCommand 之后的 close() 已执行
        semaphore.signal()
        try await waitUntil { syncer.closeCallCount > closeCountBeforeRemoval }
        await mainActorBarrier()

        #expect(model.alert?.title == "H200 已断开")
        #expect(syncer.deviceCommandCallCount == commandCountBeforeRemoval)
    }

    @MainActor
    @Test("AC 7: 默认工厂无副作用断言、notConnected 重复 removal 幂等、managerOpenFailed 下 matching 恢复")
    func defaultMonitorNoSideEffectsIdempotencyAndManagerOpenFailed() async throws {
        // 1. 默认工厂无副作用断言（若默认实现被换成真实 HID monitor 会立即红）
        let defaultMonitor = H200ConnectionModel.makeDefaultDeviceMonitor()
        #expect(defaultMonitor is H200NoopDeviceMonitor)
        defaultMonitor.start()
        defaultMonitor.stop()
        defaultMonitor.onDeviceMatched = { }
        defaultMonitor.onDeviceRemoved = { }

        let defaultModel = H200ConnectionModel()
        #expect(defaultModel.status == .checking)

        // 2. notConnected 下重复 removal 幂等
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.notConnected])
        let syncer = FakeSyncer()
        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer
        )

        model.checkOnLaunch()
        try await waitUntil { model.status == .notConnected }
        let alertBefore = model.alert
        let statusBefore = model.status

        await monitor.triggerDeviceRemovedAndWait()

        #expect(model.status == statusBefore)
        #expect(model.alert == alertBefore)

        // 3. managerOpenFailed 下 matching 触发 refresh（独立 model 构造确保初始 checking 被消费）
        do {
            let isolatedMonitor = FakeDeviceMonitor()
            let identity = makeTestDeviceIdentity()
            let code = HIDReturnCode(rawValue: -1)
            let isolatedDiscovery = FakeDiscovery(results: [.managerOpenFailed(code), .connected(identity)])
            let isolatedSyncer = FakeSyncer()
            let isolatedModel = H200ConnectionModel(
                discovery: isolatedDiscovery,
                deviceMonitor: isolatedMonitor,
                syncer: isolatedSyncer
            )

            isolatedModel.checkOnLaunch()
            try await waitUntil {
                if case .managerOpenFailed = isolatedModel.status { return true }
                return false
            }

            isolatedMonitor.triggerDeviceMatched()
            try await waitUntil { isolatedModel.status == .connected(identity) }
            #expect(isolatedModel.status == .connected(identity))
        }
    }

    @MainActor
    @Test("V1-1: 在线显示包阻塞中 removal，放行后 completion 被丢弃，离线网络刷新仍由 removal 恢复并持续执行")
    func removalDuringInFlightDisplaySyncResumesOfflineRefresh() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity)])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()
        let semaphore = DispatchSemaphore(value: 0)
        let partialStarted = AtomicFlag()
        let partialFinished = AtomicFlag()

        syncer.onPartialPackage = { _ in
            partialStarted.set()
            _ = semaphore.wait(timeout: .now() + 2)
        }
        syncer.onPartialPackageCompleted = { _ in
            partialFinished.set()
        }

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        // 1. 启动并连接成功，第一轮 Sub2API 请求发出并成功返回，进入 syncKeyDisplay 阻塞在 partialPackage
        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && partialStarted.isSet
        }

        // 2. 在部分显示包阻塞期间拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")
        #expect(model.syncSummary == nil)

        // 3. 放行显示包，completion 因 generation 不匹配被丢弃
        semaphore.signal()
        try await waitUntil { partialFinished.isSet }
        await mainActorBarrier()

        let countAtRemoval = fetcher.requestCount
        let baselineCommandCount = syncer.deviceCommandCallCount

        // 4. 断言离线连续完成至少两轮网络刷新（证明调度未因 completion 被丢弃而丢失）
        try await waitUntil { fetcher.requestCount >= countAtRemoval + 2 }
        #expect(fetcher.requestCount >= countAtRemoval + 2)

        await mainActorBarrier()
        // 断言无新增设备写命令
        #expect(syncer.deviceCommandCallCount == baselineCommandCount)
    }

    @MainActor
    @Test("V1-2: 重连 refresh 阻塞中再次 removal，晚到 discovery 被拦截丢弃，离线网络刷新仍恢复并持续执行")
    func removalDuringReconnectionDiscoveryResumesOfflineRefresh() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity), .connected(identity)])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()
        let semaphore = DispatchSemaphore(value: 0)
        let secondDiscoverStarted = AtomicFlag()
        let secondDiscoverFinished = AtomicFlag()

        discovery.onDiscover = { count in
            if count == 2 {
                secondDiscoverStarted.set()
                _ = semaphore.wait(timeout: .now() + 2)
            }
        }
        discovery.onDiscoverCompleted = { count in
            if count == 2 {
                secondDiscoverFinished.set()
            }
        }

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        // 1. 首次连接成功，runtime 正常运行
        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && fetcher.requestCount >= 1
        }

        // 2. 拔线进入离线状态
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        // 3. 触发 matching，进入 refresh()（暂停全部 runtime，并在后台队列开始第 2 次 discovery 且阻塞）
        monitor.triggerDeviceMatched()
        try await waitUntil { secondDiscoverStarted.isSet }
        #expect(model.status == .checking)

        // 4. 在途期间再次 removal：递增 generation，置 notConnected，触发 resumeCurrentPageRuntime()
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }
        #expect(model.alert?.title == "H200 已断开")

        let countAtSecondRemoval = fetcher.requestCount

        // 5. 放行第 2 次 discovery，其回调被 guard generation == deviceCommandGeneration 丢弃，绕过 W2 恢复分支
        semaphore.signal()
        try await waitUntil { secondDiscoverFinished.isSet }
        await mainActorBarrier()

        // 断言最终保持 notConnected、断线横幅未被覆盖
        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "H200 已断开")
        #expect(model.syncSummary == nil)

        // 6. 断言 runtime 已成功恢复：fetcher 离线连续完成至少两轮刷新
        try await waitUntil { fetcher.requestCount >= countAtSecondRemoval + 2 }
        #expect(fetcher.requestCount >= countAtSecondRemoval + 2)
    }

    @MainActor
    @Test("V3: finishStartupSync 失败分支直接测试：discovery 成功但启动包失败，已建立的 runtime 恢复刷新，展示失败横幅")
    func failedStartupSyncResumesEstablishedRuntimeAndShowsAlert() async throws {
        let identity = makeTestDeviceIdentity()
        let monitor = FakeDeviceMonitor()
        let discovery = FakeDiscovery(results: [.connected(identity), .connected(identity)])
        let syncer = FakeSyncer()
        let fetcher = FakeSub2APIFetcher()

        var state = DeckGridInteractionState(layout: .h200Prototype)
        _ = state.assign(.sub2API, to: 1)
        _ = state.setSub2APIBaseURL("https://api.example.com", for: 1)
        _ = state.setSub2APIBearerKey(sub2APIAuthJSON(accessToken: "valid-token"), for: 1)
        _ = state.setSub2APITargetGroupID(1, for: 1)
        _ = state.setSub2APIRefreshInterval(5, for: 1)
        let configStore = FakeDeckConfigurationStore(loadedState: state)

        let model = H200ConnectionModel(
            discovery: discovery,
            deviceMonitor: monitor,
            syncer: syncer,
            configurationStore: configStore,
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        // 1. 首次连接成功，runtime 正常运行
        model.checkOnLaunch()
        try await waitUntil {
            model.status == .connected(identity)
                && syncer.sentStartupDisplays.count == 1
                && fetcher.requestCount >= 1
        }

        // 2. 拔线
        monitor.triggerDeviceRemoved()
        try await waitUntil { model.status == .notConnected }

        // 3. 为第二轮启动包注入失败
        let errorCode = HIDReturnCode(rawValue: -1)
        syncer.queueStartupSyncResult(.failure(.writeFailed(errorCode), elapsedNanoseconds: 0))

        let commandCountBeforeMatching = syncer.deviceCommandCallCount

        // 4. 插回触发 matching，discovery 成功（第二次返回 connected），但启动包失败落地
        monitor.triggerDeviceMatched()
        try await waitUntil {
            syncer.sentStartupDisplays.count == 2
                && model.alert?.title == "无法同步 H200"
        }

        // 断言 status 为 connected(identity)、syncSummary 为 nil 未完成同步、横幅为同步失败文案
        #expect(model.status == .connected(identity))
        #expect(model.syncSummary == nil)
        #expect(model.alert?.title == "无法同步 H200")
        #expect(model.alert?.message.contains("写入 H200 通信接口失败") == true)

        // 5. 断言 runtime 恢复：fetcher 连续刷新 ≥2 次
        let countAfterFailedStartup = fetcher.requestCount
        try await waitUntil { fetcher.requestCount >= countAfterFailedStartup + 2 }
        #expect(fetcher.requestCount >= countAfterFailedStartup + 2)

        await mainActorBarrier()
        // 因为 syncSummary == nil，设备写被 guard case .connected = status, syncSummary != nil 拦截
        // FakeSyncer 设备命令记录仅比 matching 前多 1 次（即注入失败的 sendStartupPackage）
        #expect(syncer.deviceCommandCallCount == commandCountBeforeMatching + 1)
    }
}

// MARK: - Test Helpers & Fakes

private func sub2APIAuthJSON(accessToken: String) -> String {
    #"{"access_token":"\#(accessToken)","refresh_token":"refresh-token","expires_at":"4102444800000"}"#
}

@MainActor
private func mainActorBarrier() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
}

private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        defer { lock.unlock() }
        value = true
    }
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

private final class FakeDeviceMonitor: H200DeviceMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _onDeviceMatched: (@Sendable () -> Void)?
    private var _onDeviceRemoved: (@Sendable () -> Void)?
    private var _startCallCount = 0
    private var _stopCallCount = 0

    var onDeviceMatched: (@Sendable () -> Void)? {
        get { locked { _onDeviceMatched } }
        set { locked { _onDeviceMatched = newValue } }
    }

    var onDeviceRemoved: (@Sendable () -> Void)? {
        get { locked { _onDeviceRemoved } }
        set { locked { _onDeviceRemoved = newValue } }
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

    func triggerDeviceMatched() {
        let handler = locked { _onDeviceMatched }
        handler?()
    }

    func triggerDeviceRemoved() {
        let handler = locked { _onDeviceRemoved }
        handler?()
    }

    @MainActor
    func triggerDeviceMatchedAndWait() async {
        triggerDeviceMatched()
        await mainActorBarrier()
    }

    @MainActor
    func triggerDeviceRemovedAndWait() async {
        triggerDeviceRemoved()
        await mainActorBarrier()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeDiscovery: H200Discovering, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [H200DiscoveryResult]
    private var _discoverCallCount = 0
    private var _onDiscover: (@Sendable (Int) -> Void)?
    private var _onDiscoverCompleted: (@Sendable (Int) -> Void)?

    init(results: [H200DiscoveryResult] = []) {
        self.results = results
    }

    var discoverCallCount: Int {
        locked { _discoverCallCount }
    }

    var onDiscover: (@Sendable (Int) -> Void)? {
        get { locked { _onDiscover } }
        set { locked { _onDiscover = newValue } }
    }

    var onDiscoverCompleted: (@Sendable (Int) -> Void)? {
        get { locked { _onDiscoverCompleted } }
        set { locked { _onDiscoverCompleted = newValue } }
    }

    func queueResult(_ result: H200DiscoveryResult) {
        locked { results.append(result) }
    }

    func discoverH200() -> H200DiscoveryResult {
        let (count, handler): (Int, (@Sendable (Int) -> Void)?) = locked {
            _discoverCallCount += 1
            return (_discoverCallCount, _onDiscover)
        }
        handler?(count)
        let result: H200DiscoveryResult = locked {
            guard !results.isEmpty else {
                return .notConnected
            }
            return results.removeFirst()
        }
        let completedHandler = locked { _onDiscoverCompleted }
        completedHandler?(count)
        return result
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeSyncer: H200DeckSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var _closeCallCount = 0
    private var _sentStartupDisplays: [[DeckKeyDisplay]] = []
    private var _startupSyncResults: [H200DeckSyncResult] = []
    private var _sentPartialDisplays: [[DeckKeyDisplay]] = []
    private var _sentBrightnessPercents: [Int] = []
    private var _deviceCommandCallCount = 0
    private var _onPartialPackage: (@Sendable ([DeckKeyDisplay]) -> Void)?
    private var _onPartialPackageCompleted: (@Sendable ([DeckKeyDisplay]) -> Void)?
    private var _onBrightness: (@Sendable (Int) -> Void)?
    private var _onBrightnessCompleted: (@Sendable (Int) -> Void)?
    private var _brightnessResult: H200DeckCommandResult = .success(elapsedNanoseconds: 0)

    var closeCallCount: Int {
        locked { _closeCallCount }
    }

    var sentStartupDisplays: [[DeckKeyDisplay]] {
        locked { _sentStartupDisplays }
    }

    var startupSyncResults: [H200DeckSyncResult] {
        get { locked { _startupSyncResults } }
        set { locked { _startupSyncResults = newValue } }
    }

    func queueStartupSyncResult(_ result: H200DeckSyncResult) {
        locked { _startupSyncResults.append(result) }
    }

    var sentPartialDisplays: [[DeckKeyDisplay]] {
        locked { _sentPartialDisplays }
    }

    var sentBrightnessPercents: [Int] {
        locked { _sentBrightnessPercents }
    }

    var deviceCommandCallCount: Int {
        locked { _deviceCommandCallCount }
    }

    var onPartialPackage: (@Sendable ([DeckKeyDisplay]) -> Void)? {
        get { locked { _onPartialPackage } }
        set { locked { _onPartialPackage = newValue } }
    }

    var onPartialPackageCompleted: (@Sendable ([DeckKeyDisplay]) -> Void)? {
        get { locked { _onPartialPackageCompleted } }
        set { locked { _onPartialPackageCompleted = newValue } }
    }

    var onBrightness: (@Sendable (Int) -> Void)? {
        get { locked { _onBrightness } }
        set { locked { _onBrightness = newValue } }
    }

    var onBrightnessCompleted: (@Sendable (Int) -> Void)? {
        get { locked { _onBrightnessCompleted } }
        set { locked { _onBrightnessCompleted = newValue } }
    }

    var brightnessResult: H200DeckCommandResult {
        get { locked { _brightnessResult } }
        set { locked { _brightnessResult = newValue } }
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let result: H200DeckSyncResult = locked {
            _deviceCommandCallCount += 1
            _sentStartupDisplays.append(displays)
            if !_startupSyncResults.isEmpty {
                return _startupSyncResults.removeFirst()
            }
            return .success(H200DeckSyncSummary(
                payloadByteCount: displays.count * 100,
                packetCount: 1,
                displayCount: displays.count
            ))
        }
        return result
    }

    func sendPartialPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let (handler, summary): ((@Sendable ([DeckKeyDisplay]) -> Void)?, H200DeckSyncSummary) = locked {
            _deviceCommandCallCount += 1
            _sentPartialDisplays.append(displays)
            return (
                _onPartialPackage,
                H200DeckSyncSummary(
                    payloadByteCount: displays.count * 100,
                    packetCount: 1,
                    displayCount: displays.count
                )
            )
        }
        handler?(displays)
        let completedHandler = locked { _onPartialPackageCompleted }
        completedHandler?(displays)
        return .success(summary)
    }

    func setBrightness(percent: Int) -> H200DeckCommandResult {
        let (handler, result): ((@Sendable (Int) -> Void)?, H200DeckCommandResult) = locked {
            _deviceCommandCallCount += 1
            _sentBrightnessPercents.append(percent)
            return (_onBrightness, _brightnessResult)
        }
        handler?(percent)
        let completedHandler = locked { _onBrightnessCompleted }
        completedHandler?(percent)
        return result
    }

    func close() {
        locked {
            _closeCallCount += 1
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeDeckConfigurationStore: DeckConfigurationStoring {
    private let loadedState: DeckGridInteractionState?
    private let loadedBrightnessPercent: Int?
    private let loadedFollowsBuiltInDisplayBrightness: Bool

    init(
        loadedState: DeckGridInteractionState? = nil,
        loadedBrightnessPercent: Int? = nil,
        loadedFollowsBuiltInDisplayBrightness: Bool = false
    ) {
        self.loadedState = loadedState
        self.loadedBrightnessPercent = loadedBrightnessPercent
        self.loadedFollowsBuiltInDisplayBrightness = loadedFollowsBuiltInDisplayBrightness
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        loadedState
    }

    @discardableResult
    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) -> DeckConfigurationSaveResult {
        .success
    }

    func loadBrightnessPercent() -> Int? {
        loadedBrightnessPercent
    }

    func saveBrightnessPercent(_ percent: Int) {}

    func loadFollowsBuiltInDisplayBrightness() -> Bool {
        loadedFollowsBuiltInDisplayBrightness
    }

    func saveFollowsBuiltInDisplayBrightness(_ follows: Bool) {}
}

private final class FakeSub2APIFetcher: Sub2APIFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _requestCount = 0

    var requestCount: Int {
        locked { _requestCount }
    }

    func fetchCapacitySummary(
        baseURL: String,
        targetGroupID: Int,
        bearerKey: String
    ) async -> Sub2APICapacityResult {
        locked { _requestCount += 1 }
        return .success(item: Sub2APICapacityItem(
            groupID: targetGroupID,
            groupName: "TestGroup",
            groupPlatform: "TestPlatform",
            concurrencyUsed: 1,
            concurrencyMax: 10,
            sessionsUsed: 1,
            sessionsMax: 10,
            rpmUsed: 1,
            rpmMax: 60
        ))
    }

    func fetchCapacityGroups(baseURL: String, bearerKey: String) async -> Sub2APIGroupListResult {
        .success(items: [])
    }

    func fetchBalance(baseURL: String, bearerKey: String) async -> Sub2APIBalanceResult {
        .success(remaining: 100)
    }

    func fetchDailyCost(baseURL: String, timezoneID: String, bearerKey: String) async -> Sub2APIDailyCostResult {
        .success(actualCost: 10)
    }

    func refreshBearerToken(baseURL: String, refreshToken: String) async -> Sub2APIAuthInfo? {
        nil
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
