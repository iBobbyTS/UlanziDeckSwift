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
        #expect(layout.keyID(forSequentialInputIndex: 0) == 1)
        #expect(layout.keyID(forSequentialInputIndex: 13) == 14)
        #expect(layout.keyID(forSequentialInputIndex: 14) == nil)
    }

    @Test func shortPressingAKeySelectsItAndIncrementsTally() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 14)

        #expect(state.selectedKeyID == 14)
        #expect(state.tallyValue(for: 7) == 2)
        #expect(state.tallyValue(for: 14) == 1)
    }

    @Test func displayModelUsesTheSameTextAsTheStartupPackage() {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let displays = state.displays(for: layout)

        #expect(displays.map(\.title) == Array(repeating: "0", count: 14))
        #expect(displays.allSatisfy { $0.subtitle == "默认 0" })
        #expect(displays.first?.isSelected == true)
        #expect(displays.last?.isWide == true)
        #expect(displays.last?.devicePixelSize == H200DeviceTarget.smallWindowIconSize)
    }

    @Test func unknownKeyDoesNotChangeTallyState() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 99)

        #expect(state.selectedKeyID == 1)
        #expect(state.configurations.values.allSatisfy { $0.tally.value == 0 })
        #expect(state.pressedKeyIDs.isEmpty)
    }

    @Test func tallyDefaultValueIsAlsoTheResetTarget() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.setTallyDefaultValue(12, for: 4)
        state.triggerShortPress(keyID: 4)
        state.resetTally(keyID: 4)

        #expect(state.selectedKeyID == 4)
        #expect(state.tallyDefaultValue(for: 4) == 12)
        #expect(state.tallyValue(for: 4) == 12)
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
        #expect(syncer.sentDisplays.first?.map(\.title) == Array(repeating: "0", count: 14))
        #expect(syncer.sentDisplays.first?.allSatisfy { $0.subtitle == "默认 0" } == true)
        #expect(syncer.sentDisplays.first?.last?.isWide == true)
        #expect(model.syncSummary?.packetCount == 4)
    }

    @MainActor
    @Test func physicalButtonShortPressIncrementsTally() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer
        )

        model.checkOnLaunch()
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 7)
        #expect(model.interactionState.tallyValue(for: 7) == 2)
    }

    @MainActor
    @Test func physicalReleaseAndEncoderEventsDoNotTriggerGridPresses() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer
        )

        model.checkOnLaunch()
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .release))
        syncer.emitInput(H200InputEvent(state: 1, index: 17, type: .encoder, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 1)
        #expect(model.interactionState.configurations.values.allSatisfy { $0.tally.value == 0 })
    }

    @MainActor
    @Test func longPressResetsTallyToConfiguredDefault() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            longPressDurationNanoseconds: 10_000_000
        )

        model.checkOnLaunch()
        model.setSelectedTallyDefaultValue(5)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 5_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 30_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.interactionState.tallyDefaultValue(for: 1) == 5)
        #expect(model.interactionState.tallyValue(for: 1) == 5)
        #expect(model.interactionState.pressedKeyIDs.isEmpty)
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

    @Test func inputReportParserRecognizesButtonPressReports() {
        let report = Self.inputReport(state: 0x01, index: 13, type: 0x01, action: 0x01)

        let event = H200InputReportParser.parse(report)

        #expect(event == H200InputEvent(state: 0x01, index: 13, type: .button, action: .press))
        #expect(H200DeckInputMapper.keyID(for: event!, layout: .h200Prototype) == 14)
    }

    @Test func inputReportParserIgnoresUnknownReportsAndMapsRelease() {
        var wrongCommand = Self.inputReport(state: 0x01, index: 0, type: 0x01, action: 0x01)
        wrongCommand[3] = 0x02
        let release = Self.inputReport(state: 0x00, index: 0, type: 0x01, action: 0x00)

        let releaseEvent = H200InputReportParser.parse(release)

        #expect(H200InputReportParser.parse(wrongCommand) == nil)
        #expect(releaseEvent == H200InputEvent(state: 0x00, index: 0, type: .button, action: .release))
        #expect(H200DeckInputMapper.keyID(for: releaseEvent!, layout: .h200Prototype) == 1)
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

    private static func inputReport(state: UInt8, index: UInt8, type: UInt8, action: UInt8) -> Data {
        var report = Data()
        report.append(0x7c)
        report.append(0x7c)
        report.appendUInt16BE(H200Command.inButton)
        report.appendUInt32LE(4)
        report.append(state)
        report.append(index)
        report.append(type)
        report.append(action)
        report.append(Data(repeating: 0, count: H200DeviceTarget.reportSize - report.count))
        return report
    }
}

private final class FakeH200DeckSyncer: H200DeckSyncing {
    private var results: [H200DeckSyncResult]
    private(set) var sentDisplays: [[DeckKeyDisplay]] = []
    private var inputHandler: H200InputHandler?

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

    func setInputHandler(_ handler: H200InputHandler?) {
        inputHandler = handler
    }

    func emitInput(_ event: H200InputEvent) {
        inputHandler?(event)
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
