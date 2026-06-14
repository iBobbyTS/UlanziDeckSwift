import Foundation

nonisolated struct ZIPArchiveFile: Equatable {
    let path: String
    let data: Data
}

nonisolated enum ZIPArchiveBuilder {
    static func makeArchive(files: [ZIPArchiveFile]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var entries: [(file: ZIPArchiveFile, crc: UInt32, localHeaderOffset: UInt32)] = []

        for file in files {
            guard let fileName = file.path.data(using: .utf8) else {
                throw ZIPArchiveError.invalidFileName(file.path)
            }
            guard archive.count <= Int(UInt32.max), file.data.count <= Int(UInt32.max) else {
                throw ZIPArchiveError.archiveTooLarge
            }

            let crc = CRC32.checksum(file.data)
            let localHeaderOffset = UInt32(archive.count)

            archive.appendUInt32LE(0x04034b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(UInt32(file.data.count))
            archive.appendUInt32LE(UInt32(file.data.count))
            archive.appendUInt16LE(UInt16(fileName.count))
            archive.appendUInt16LE(0)
            archive.append(fileName)
            archive.append(file.data)

            entries.append((file, crc, localHeaderOffset))
        }

        let centralDirectoryOffset = UInt32(archive.count)
        for entry in entries {
            guard let fileName = entry.file.path.data(using: .utf8) else {
                throw ZIPArchiveError.invalidFileName(entry.file.path)
            }

            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(entry.crc)
            centralDirectory.appendUInt32LE(UInt32(entry.file.data.count))
            centralDirectory.appendUInt32LE(UInt32(entry.file.data.count))
            centralDirectory.appendUInt16LE(UInt16(fileName.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(entry.localHeaderOffset)
            centralDirectory.append(fileName)
        }

        guard centralDirectory.count <= Int(UInt32.max), entries.count <= Int(UInt16.max) else {
            throw ZIPArchiveError.archiveTooLarge
        }

        archive.append(centralDirectory)
        archive.appendUInt32LE(0x06054b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(entries.count))
        archive.appendUInt16LE(UInt16(entries.count))
        archive.appendUInt32LE(UInt32(centralDirectory.count))
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)

        return archive
    }
}

nonisolated enum ZIPArchiveError: Error, Equatable {
    case invalidFileName(String)
    case archiveTooLarge
}

nonisolated private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffffffff
    }
}
