import Foundation

@MainActor
protocol RefreshScheduling: AnyObject {
    func startTick(_ handler: @escaping @MainActor () -> Void)
    func scheduleRefresh(after interval: TimeInterval, _ handler: @escaping @MainActor () -> Void)
    func cancelRefresh()
    func stop()
}

@MainActor
final class TimerRefreshScheduler: RefreshScheduling {
    private let tickInterval: TimeInterval
    private var tickTimer: Timer?
    private var refreshTimer: Timer?

    nonisolated init(tickInterval: TimeInterval = 1) {
        self.tickInterval = tickInterval
    }

    func startTick(_ handler: @escaping @MainActor () -> Void) {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func scheduleRefresh(after interval: TimeInterval, _ handler: @escaping @MainActor () -> Void) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func cancelRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        cancelRefresh()
    }
}
