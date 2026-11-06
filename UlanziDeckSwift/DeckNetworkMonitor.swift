import Foundation
import Network

/// 网络路径翻转判定：只有「上次明确不可用且本次可用」才算恢复事件；
/// 首个事件只用于记录基线，不触发恢复。
nonisolated enum DeckNetworkPathTransition: Equatable {
    static func isRecovery(previousSatisfied: Bool?, isSatisfied: Bool) -> Bool {
        previousSatisfied == false && isSatisfied
    }
}

nonisolated protocol DeckNetworkMonitoring: AnyObject, Sendable {
    var onPathSatisfied: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
}

nonisolated final class DeckNoopNetworkMonitor: DeckNetworkMonitoring, @unchecked Sendable {
    var onPathSatisfied: (@Sendable () -> Void)?

    init() {}
    func start() {}
    func stop() {}
}

/// 基于 NWPathMonitor 的网络恢复监听。
/// 回调可能在任意线程触发，由持有方负责派发到主线程。
nonisolated final class DeckNetworkMonitor: DeckNetworkMonitoring, @unchecked Sendable {
    private let stateQueue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.DeckNetworkMonitor.state")
    private let pathQueue = DispatchQueue(label: "com.iBobby.UlanziDeckSwift.DeckNetworkMonitor.path")
    private var pathMonitor: NWPathMonitor?
    private var isStarted = false
    private var previousPathSatisfied: Bool?
    private var _onPathSatisfied: (@Sendable () -> Void)?

    var onPathSatisfied: (@Sendable () -> Void)? {
        get { stateQueue.sync { _onPathSatisfied } }
        set { stateQueue.sync { _onPathSatisfied = newValue } }
    }

    init() {}

    deinit {
        stop()
    }

    func start() {
        stateQueue.sync {
            guard !isStarted else { return }

            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.handlePathUpdate(path)
            }
            monitor.start(queue: pathQueue)
            pathMonitor = monitor
            isStarted = true
        }
    }

    func stop() {
        let monitor: NWPathMonitor? = stateQueue.sync {
            guard isStarted else { return nil }

            let monitor = pathMonitor
            pathMonitor = nil
            isStarted = false
            previousPathSatisfied = nil
            return monitor
        }
        monitor?.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let handler: (@Sendable () -> Void)? = stateQueue.sync {
            let isSatisfied = path.status == .satisfied
            let isRecovery = DeckNetworkPathTransition.isRecovery(
                previousSatisfied: previousPathSatisfied,
                isSatisfied: isSatisfied
            )
            previousPathSatisfied = isSatisfied
            return isRecovery ? _onPathSatisfied : nil
        }
        handler?()
    }
}
