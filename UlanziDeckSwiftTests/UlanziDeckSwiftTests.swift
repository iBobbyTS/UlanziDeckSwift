import Foundation
import Testing
@testable import UlanziDeckSwift

struct UlanziDeckSwiftTests {
    @Test func h200PrototypeLayoutContainsFourteenNumberedKeys() {
        let layout = DeckGridLayout.h200Prototype

        #expect(layout.keys.map(\.id) == Array(1...14))
        #expect(layout.rows.map(\.count) == [5, 5, 4])
        #expect(layout.columnCount == 5)
        #expect(layout.keys.last?.columnSpan == 2)
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

    @Test func displayModelUsesTheSameTextAsTheStartupPackage() {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let displays = state.displays(for: layout)

        #expect(displays.map(\.title) == Array(1...14).map(String.init))
        #expect(displays.allSatisfy { $0.subtitle == "就绪" })
        #expect(displays.last?.isWide == true)
        #expect(displays.last?.devicePixelSize == H200DeviceTarget.smallWindowIconSize)
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
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [.notConnected]), syncer: syncer)

        model.checkOnLaunch()

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "未检测到 H200")
        #expect(syncer.sentDisplays.isEmpty)
    }

    @MainActor
    @Test func managerExclusiveAccessShowsOccupiedPortAlert() {
        let code = Self.exclusiveAccessReturnCode()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.communicationPortOccupied(code)]),
            syncer: FakeH200DeckSyncer()
        )

        model.checkOnLaunch()

        #expect(model.status == .communicationPortOccupied(code))
        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("有其他应用正在占用 H200 通信端口") == true)
        #expect(model.alert?.message.contains("kIOReturnExclusiveAccess") == true)
    }

    @Test func exclusiveAccessReturnCodeMeansOccupiedPort() {
        let code = Self.exclusiveAccessReturnCode()

        #expect(code.name == "kIOReturnExclusiveAccess")
        #expect(code.indicatesOccupiedPort)
    }

    @MainActor
    @Test func retryUpdatesStateWhenH200Appears() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 2048, packetCount: 2, displayCount: 14)),
        ])
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [
            .notConnected,
            .connected(connectedIdentity),
        ]), syncer: syncer)

        model.checkOnLaunch()
        model.retry()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.status == .connected(connectedIdentity))
        #expect(model.connectedDevice == connectedIdentity)
        #expect(model.syncSummary?.displayCount == 14)
        #expect(model.alert == nil)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func successfulLaunchSendsDisplaysMatchingTheVisibleGrid() {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: 14)),
        ])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer
        )

        model.checkOnLaunch()

        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.sentDisplays.first?.map(\.title) == Array(1...14).map(String.init))
        #expect(syncer.sentDisplays.first?.allSatisfy { $0.subtitle == "就绪" } == true)
        #expect(syncer.sentDisplays.first?.last?.isWide == true)
        #expect(model.syncSummary?.packetCount == 4)
    }

    @MainActor
    @Test func syncFailureShowsPackageNotSentAlert() {
        let code = Self.exclusiveAccessReturnCode()
        let syncer = FakeH200DeckSyncer(results: [.failure(.communicationPortOccupied(code))])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer
        )

        model.checkOnLaunch()

        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("按键包尚未发送") == true)
        #expect(model.syncSummary == nil)
    }

    @MainActor
    @Test func buttonPackageManifestMatchesDisplays() throws {
        let displays = DeckGridInteractionState(layout: .h200Prototype).displays(for: .h200Prototype)
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: displays)
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let firstEntry = manifest["0_0"] as? [String: Any]
        let firstViewParam = (firstEntry?["ViewParam"] as? [[String: Any]])?.first
        let smallEntry = manifest["3_2"] as? [String: Any]
        let smallViewParam = (smallEntry?["ViewParam"] as? [[String: Any]])?.first

        #expect(package.displayCount == 14)
        #expect(Array(package.payload.prefix(4)) == [0x50, 0x4b, 0x03, 0x04])
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
        #expect(manifest.count == 14)
        #expect(firstViewParam?["Icon"] as? String == "Images/key_1.png")
        #expect(firstViewParam?["Text"] as? String == "")
        #expect(smallEntry?["SmallViewMode"] as? Int == 2)
        #expect(smallViewParam?["Icon"] as? String == "Images/key_14.png")
    }

    @Test func realIconRendererCreatesPNGForWideDisplay() throws {
        let display = DeckGridInteractionState(layout: .h200Prototype)
            .displays(for: .h200Prototype)
            .last!

        let png = try H200ButtonIconRenderer().pngData(for: display)

        #expect(Array(png.prefix(4)) == [0x89, 0x50, 0x4e, 0x47])
        #expect(!png.isEmpty)
    }

    @Test func chunkedPacketsUseTheObservedH200FrameFormat() {
        let payload = Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2)

        let packets = H200PacketBuilder.buildChunkedPackets(command: H200Command.outSetButtons, payload: payload)

        #expect(packets.count == 2)
        #expect(packets.allSatisfy { $0.count == H200PacketBuilder.packetSize })
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(packets[0][4] == UInt8(payload.count & 0xff))
        #expect(packets[0][5] == UInt8((payload.count >> 8) & 0xff))
        #expect(packets[1][0] == 0xab)
        #expect(packets[1][1] == 0xab)
        #expect(packets[1][2] == 0x00)
    }

    @Test func startupPacketsSetButtonsThenSmallWindowBackgroundMode() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 14
        )

        let packets = H200StartupPacketBuilder.buildStartupPackets(package: package)
        let smallWindowPacket = packets.last!
        let smallWindowLength = Self.payloadLength(in: smallWindowPacket)
        let smallWindowPayload = smallWindowPacket.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + smallWindowLength))

        #expect(packets.count == 3)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(Array(smallWindowPacket.prefix(4)) == [0x7c, 0x7c, 0x00, 0x06])
        #expect(smallWindowPayload == H200SmallWindowDataPacketBuilder.backgroundModePayload)
        #expect(String(data: smallWindowPayload, encoding: .utf8) == "2|0|0|00:00:00|0|24H|")
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

    private static func exclusiveAccessReturnCode() -> HIDReturnCode {
        HIDReturnCode(rawValue: Int32(bitPattern: 0xe00002c5))
    }

    private static func payloadLength(in packet: Data) -> Int {
        Int(packet[4])
            | (Int(packet[5]) << 8)
            | (Int(packet[6]) << 16)
            | (Int(packet[7]) << 24)
    }
}

private final class FakeH200DeckSyncer: H200DeckSyncing {
    private var results: [H200DeckSyncResult]
    private(set) var sentDisplays: [[DeckKeyDisplay]] = []

    init(results: [H200DeckSyncResult] = []) {
        self.results = results
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        sentDisplays.append(displays)

        guard !results.isEmpty else {
            return .success(H200DeckSyncSummary(
                payloadByteCount: displays.count,
                packetCount: 1,
                displayCount: displays.count
            ))
        }

        return results.removeFirst()
    }
}

private struct FakeH200ButtonIconRenderer: H200ButtonIconRendering {
    func pngData(for display: DeckKeyDisplay) throws -> Data {
        Data([0x89, 0x50, 0x4e, 0x47, UInt8(display.id)])
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
