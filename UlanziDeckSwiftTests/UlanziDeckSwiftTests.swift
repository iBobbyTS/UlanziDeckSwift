import Testing
@testable import UlanziDeckSwift

struct UlanziDeckSwiftTests {
    @Test func h200PrototypeLayoutContainsFourteenNumberedKeys() {
        let layout = DeckGridLayout.h200Prototype

        #expect(layout.keys.map(\.id) == Array(1...14))
        #expect(layout.rows.map(\.count) == [5, 5, 4])
        #expect(layout.columnCount == 5)
    }

    @Test func pressingAKeySelectsItAndTracksTapCount() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.press(keyID: 7)
        state.press(keyID: 7)
        state.press(keyID: 14)

        #expect(state.selectedKeyID == 14)
        #expect(state.tapCount(for: 7) == 2)
        #expect(state.tapCount(for: 14) == 1)
    }

    @Test func pressingUnknownKeyDoesNotChangeState() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.press(keyID: 99)

        #expect(state.selectedKeyID == nil)
        #expect(state.tapCounts.values.allSatisfy { $0 == 0 })
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
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [.notConnected]))

        model.checkOnLaunch()

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "未检测到 H200")
    }

    @MainActor
    @Test func retryUpdatesStateWhenH200Appears() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [
            .notConnected,
            .connected(connectedIdentity),
        ]))

        model.checkOnLaunch()
        model.retry()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.status == .connected(connectedIdentity))
        #expect(model.connectedDevice == connectedIdentity)
        #expect(model.alert == nil)
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
