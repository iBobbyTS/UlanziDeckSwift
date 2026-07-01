import Foundation

nonisolated enum H200Command {
    static let outSetButtons: UInt16 = 0x0001
    static let outSetSmallWindowData: UInt16 = 0x0006
    static let outSetBrightness: UInt16 = 0x000a
    static let outPartiallyUpdateButtons: UInt16 = 0x000d
    static let inButton: UInt16 = 0x0101
}

nonisolated enum H200SmallWindowMode: Int, Encodable, Equatable {
    case stats = 0
    case dial = 1
    case background = 2

    init(displayMode: DeckKeyDisplayMode) {
        switch displayMode {
        case .function:
            self = .background
        case .clock:
            self = .dial
        case .systemStatus:
            self = .stats
        }
    }

    static func mode(for displays: [DeckKeyDisplay]) -> H200SmallWindowMode {
        modeIfPresent(in: displays) ?? .background
    }

    static func modeIfPresent(in displays: [DeckKeyDisplay]) -> H200SmallWindowMode? {
        guard let display = displays.first(where: \.isWide) else {
            return nil
        }

        return H200SmallWindowMode(displayMode: display.displayMode)
    }
}

nonisolated struct H200SystemStats: Equatable, Sendable {
    let cpuPercent: Int
    let memoryPercent: Int
    let gpuPercent: Int

    static let zero = H200SystemStats(cpuPercent: 0, memoryPercent: 0, gpuPercent: 0)

    init(cpuPercent: Int, memoryPercent: Int, gpuPercent: Int) {
        self.cpuPercent = Self.clamped(cpuPercent)
        self.memoryPercent = Self.clamped(memoryPercent)
        self.gpuPercent = Self.clamped(gpuPercent)
    }

    private static func clamped(_ percent: Int) -> Int {
        max(0, min(100, percent))
    }
}

nonisolated enum H200PacketBuilder {
    static let packetSize = H200DeviceTarget.reportSize
    static let headerSize = 8
    static let firstChunkDataSize = packetSize - headerSize

    static func buildChunkedPackets(command: UInt16, payload: Data) -> [Data] {
        var packets: [Data] = []
        let firstChunkEnd = min(firstChunkDataSize, payload.count)
        let firstChunk = payload.subdata(in: 0..<firstChunkEnd)
        packets.append(buildFramedPacket(command: command, payloadLength: payload.count, data: firstChunk))

        var offset = firstChunkDataSize
        while offset < payload.count {
            let end = min(offset + packetSize, payload.count)
            var packet = payload.subdata(in: offset..<end)
            if packet.count < packetSize {
                packet.append(Data(repeating: 0, count: packetSize - packet.count))
            }
            packets.append(packet)
            offset += packetSize
        }

        return packets
    }

    static func buildSimplePacket(command: UInt16, payload: Data) -> Data {
        buildFramedPacket(command: command, payloadLength: payload.count, data: payload)
    }

    static func isPayloadSafe(_ payload: Data) -> Bool {
        guard payload.count > firstChunkDataSize else {
            return true
        }

        var offset = firstChunkDataSize
        while offset < payload.count {
            let byte = payload[offset]
            if byte == 0x00 || byte == 0x7c {
                return false
            }
            offset += packetSize
        }

        return true
    }

    private static func buildFramedPacket(command: UInt16, payloadLength: Int, data: Data) -> Data {
        precondition(data.count <= firstChunkDataSize)

        var packet = Data()
        packet.reserveCapacity(packetSize)
        packet.append(0x7c)
        packet.append(0x7c)
        packet.appendUInt16BE(command)
        packet.appendUInt32LE(UInt32(payloadLength))
        packet.append(data)

        if packet.count < packetSize {
            packet.append(Data(repeating: 0, count: packetSize - packet.count))
        }

        return packet
    }
}

nonisolated enum H200StartupPacketBuilder {
    static func buildStartupPackets(
        package: H200ButtonPackage,
        smallWindowMode: H200SmallWindowMode = .background,
        systemStats: H200SystemStats? = nil
    ) -> [Data] {
        var packets = H200PacketBuilder.buildChunkedPackets(
            command: H200Command.outSetButtons,
            payload: package.payload
        )
        packets.append(H200SmallWindowDataPacketBuilder.packet(mode: smallWindowMode, systemStats: systemStats))
        return packets
    }
}

nonisolated enum H200PartialUpdatePacketBuilder {
    static func buildPartialUpdatePackets(
        package: H200ButtonPackage,
        smallWindowMode: H200SmallWindowMode? = nil,
        systemStats: H200SystemStats? = nil
    ) -> [Data] {
        var packets = H200PacketBuilder.buildChunkedPackets(
            command: H200Command.outPartiallyUpdateButtons,
            payload: package.payload
        )
        if let smallWindowMode {
            packets.append(H200SmallWindowDataPacketBuilder.packet(mode: smallWindowMode, systemStats: systemStats))
        }

        return packets
    }
}

nonisolated enum H200SmallWindowDataPacketBuilder {
    static let backgroundModePayload = Data("2|0|0|00:00:00|0|24H|".utf8)

    static func payload(
        mode: H200SmallWindowMode,
        date: Date = Date(),
        systemStats: H200SystemStats? = nil
    ) -> Data {
        let time = mode == .background ? "00:00:00" : timeString(from: date)
        let stats = mode == .stats ? systemStats ?? .zero : .zero
        return Data("\(mode.rawValue)|\(stats.cpuPercent)|\(stats.memoryPercent)|\(time)|\(stats.gpuPercent)|24H|".utf8)
    }

    static func packet(
        mode: H200SmallWindowMode,
        date: Date = Date(),
        systemStats: H200SystemStats? = nil
    ) -> Data {
        H200PacketBuilder.buildSimplePacket(
            command: H200Command.outSetSmallWindowData,
            payload: payload(mode: mode, date: date, systemStats: systemStats)
        )
    }

    static func backgroundModePacket() -> Data {
        packet(mode: .background)
    }

    private static func timeString(from date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(
            format: "%02d:%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}

nonisolated enum H200BrightnessPacketBuilder {
    static func payload(percent: Int) -> Data {
        Data(String(DeckBrightnessConfiguration.clamped(percent)).utf8)
    }

    static func packet(percent: Int) -> Data {
        H200PacketBuilder.buildSimplePacket(
            command: H200Command.outSetBrightness,
            payload: payload(percent: percent)
        )
    }
}

nonisolated struct H200InputEvent: Equatable, Sendable {
    let state: UInt8
    let index: UInt8
    let type: H200InputEventType
    let action: H200InputAction
}

nonisolated enum H200InputEventType: Equatable, Sendable {
    case button
    case encoder
}

nonisolated enum H200InputAction: Equatable, Sendable {
    case press
    case release
}

nonisolated enum H200InputReportParser {
    static func parse(_ report: Data) -> H200InputEvent? {
        guard report.count >= H200PacketBuilder.headerSize else {
            return nil
        }
        guard report[0] == 0x7c, report[1] == 0x7c else {
            return nil
        }

        let command = UInt16(report[2]) << 8 | UInt16(report[3])
        guard command == H200Command.inButton else {
            return nil
        }

        let payloadLength = Int(report[4])
            | (Int(report[5]) << 8)
            | (Int(report[6]) << 16)
            | (Int(report[7]) << 24)
        let payloadStart = H200PacketBuilder.headerSize
        let payloadEnd = payloadStart + payloadLength
        guard payloadLength >= 4, payloadEnd <= report.count else {
            return nil
        }

        let payload = report[payloadStart..<payloadEnd]
        return H200InputEvent(
            state: payload[payload.startIndex],
            index: payload[payload.startIndex + 1],
            type: payload[payload.startIndex + 2] == 0x02 ? .encoder : .button,
            action: action(from: payload[payload.startIndex + 3])
        )
    }

    private static func action(from byte: UInt8) -> H200InputAction {
        switch byte {
        case 0x01:
            return .press
        default:
            return .release
        }
    }
}

nonisolated enum H200DeckInputMapper {
    static func keyID(for event: H200InputEvent, layout: DeckGridLayout) -> Int? {
        guard event.type == .button else {
            return nil
        }

        return layout.keyID(forSequentialInputIndex: Int(event.index))
    }
}

extension Data {
    nonisolated mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0x00ff))
        append(UInt8((value >> 8) & 0x00ff))
    }

    nonisolated mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0x00ff))
        append(UInt8(value & 0x00ff))
    }

    nonisolated mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0x000000ff))
        append(UInt8((value >> 8) & 0x000000ff))
        append(UInt8((value >> 16) & 0x000000ff))
        append(UInt8((value >> 24) & 0x000000ff))
    }

    nonisolated mutating func appendUTF8(_ value: String) {
        append(value.data(using: .utf8) ?? Data())
    }
}
