import Foundation

nonisolated enum H200Command {
    static let outSetButtons: UInt16 = 0x0001
    static let outPartiallyUpdateButtons: UInt16 = 0x000d
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
