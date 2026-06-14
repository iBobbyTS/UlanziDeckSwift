import AppKit
import Foundation

nonisolated struct H200ButtonPackage: Equatable {
    let payload: Data
    let manifestData: Data
    let displayCount: Int
}

nonisolated protocol H200ButtonIconRendering {
    func pngData(for display: DeckKeyDisplay) throws -> Data
}

nonisolated struct H200ButtonPackageBuilder {
    private let renderer: H200ButtonIconRendering

    nonisolated init(renderer: H200ButtonIconRendering = H200ButtonIconRenderer()) {
        self.renderer = renderer
    }

    func buildPackage(displays: [DeckKeyDisplay]) throws -> H200ButtonPackage {
        let sortedDisplays = displays.sorted { first, second in
            if first.row == second.row {
                return first.column < second.column
            }

            return first.row < second.row
        }

        let manifest = try buildManifest(displays: sortedDisplays)
        let manifestData = try makeJSONData(manifest)
        let imageFiles = try sortedDisplays.map { display in
            ZIPArchiveFile(path: iconPath(for: display), data: try renderer.pngData(for: display))
        }
        let payload = try makeSafePayload(manifestData: manifestData, imageFiles: imageFiles)

        return H200ButtonPackage(
            payload: payload,
            manifestData: manifestData,
            displayCount: sortedDisplays.count
        )
    }

    private func buildManifest(displays: [DeckKeyDisplay]) throws -> [String: H200ManifestEntry] {
        Dictionary(uniqueKeysWithValues: displays.map { display in
            let viewParam = H200ManifestViewParam(
                Font: .default,
                Icon: iconPath(for: display),
                Text: ""
            )
            let entry = H200ManifestEntry(
                State: 0,
                ViewParam: [viewParam],
                SmallViewMode: display.isWide ? H200SmallWindowMode.background.rawValue : nil
            )

            return ("\(display.column)_\(display.row)", entry)
        })
    }

    private func makeJSONData(_ manifest: [String: H200ManifestEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(manifest)
    }

    private func makeSafePayload(manifestData: Data, imageFiles: [ZIPArchiveFile]) throws -> Data {
        var retries = 0
        while retries <= 64 {
            var files = [ZIPArchiveFile(path: "manifest.json", data: manifestData)]
            if retries > 0 {
                let dummy = String(repeating: "H200", count: retries * 5)
                files.append(ZIPArchiveFile(path: "dummy.txt", data: Data(dummy.utf8)))
            }
            files.append(contentsOf: imageFiles)

            let payload = try ZIPArchiveBuilder.makeArchive(files: files)
            if H200PacketBuilder.isPayloadSafe(payload) {
                return payload
            }

            retries += 1
        }

        throw H200ButtonPackageError.unsafePayloadAfterRetries
    }

    private func iconPath(for display: DeckKeyDisplay) -> String {
        "Images/key_\(display.id).png"
    }
}

nonisolated enum H200ButtonPackageError: Error, Equatable {
    case unsafePayloadAfterRetries
}

nonisolated private enum H200SmallWindowMode: Int, Encodable {
    case background = 2
}

nonisolated private struct H200ManifestEntry: Encodable, Equatable {
    let State: Int
    let ViewParam: [H200ManifestViewParam]
    let SmallViewMode: Int?

    enum CodingKeys: CodingKey {
        case State
        case ViewParam
        case SmallViewMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(State, forKey: .State)
        try container.encode(ViewParam, forKey: .ViewParam)
        try container.encodeIfPresent(SmallViewMode, forKey: .SmallViewMode)
    }
}

nonisolated private struct H200ManifestViewParam: Encodable, Equatable {
    let Font: H200ManifestFont
    let Icon: String
    let Text: String
}

nonisolated private struct H200ManifestFont: Encodable, Equatable {
    let Align: String
    let Color: Int
    let FontName: String
    let ShowTitle: Bool
    let Size: Int
    let Weight: Int

    static let `default` = H200ManifestFont(
        Align: "bottom",
        Color: 0xffffff,
        FontName: "Source Han Sans SC",
        ShowTitle: true,
        Size: 10,
        Weight: 80
    )
}

nonisolated struct H200ButtonIconRenderer: H200ButtonIconRendering {
    nonisolated init() {}

    func pngData(for display: DeckKeyDisplay) throws -> Data {
        let size = display.devicePixelSize
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size.width,
            pixelsHigh: size.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw H200ButtonIconRenderError.cannotCreateBitmap
        }

        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(display: display, in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw H200ButtonIconRenderError.cannotEncodePNG
        }

        return png
    }

    private func draw(display: DeckKeyDisplay, in rect: NSRect) {
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1).setFill()
        rect.fill()

        let inset = rect.height * 0.08
        let cardRect = rect.insetBy(dx: inset, dy: inset)
        let radius = rect.height * 0.12
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
        let isActive = display.isSelected || display.isPressed
        let background = isActive
            ? NSColor.controlAccentColor
            : NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.17, alpha: 1)
        background.setFill()
        cardPath.fill()

        NSColor(calibratedWhite: isActive ? 1 : 0.32, alpha: isActive ? 0.4 : 1).setStroke()
        cardPath.lineWidth = max(2, rect.height * 0.012)
        cardPath.stroke()

        drawCenteredText(
            display.title,
            font: .systemFont(ofSize: rect.height * 0.43, weight: .bold),
            color: .white,
            rect: NSRect(x: cardRect.minX, y: cardRect.midY - rect.height * 0.08, width: cardRect.width, height: rect.height * 0.5)
        )
        drawCenteredText(
            display.subtitle,
            font: .systemFont(ofSize: rect.height * 0.13, weight: .semibold),
            color: NSColor(calibratedWhite: 0.82, alpha: 1),
            rect: NSRect(x: cardRect.minX, y: cardRect.midY - rect.height * 0.26, width: cardRect.width, height: rect.height * 0.2)
        )
    }

    private func drawCenteredText(_ text: String, font: NSFont, color: NSColor, rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
    }
}

nonisolated enum H200ButtonIconRenderError: Error, Equatable {
    case cannotCreateBitmap
    case cannotEncodePNG
}
