import Foundation

@MainActor
final class PageFolderAutoReturnTimer {
    var onTimeout: (() -> Void)?

    private let durationNanoseconds: UInt64
    private var task: Task<Void, Never>?

    init(durationNanoseconds: UInt64 = 30_000_000_000) {
        self.durationNanoseconds = durationNanoseconds
    }

    deinit {
        task?.cancel()
    }

    func restart() {
        task?.cancel()
        let durationNanoseconds = durationNanoseconds
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            self?.finishCountdown()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func finishCountdown() {
        task = nil
        onTimeout?()
    }
}
