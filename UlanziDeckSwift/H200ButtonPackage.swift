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
            ZIPArchiveFile(path: iconPath(for: display), data: try imageData(for: display))
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
                SmallViewMode: display.isWide ? H200SmallWindowMode(displayMode: display.displayMode).rawValue : nil
            )

            return ("\(display.column)_\(display.row)", entry)
        })
    }

    private func makeJSONData(_ manifest: [String: H200ManifestEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(manifest)
    }

    private func imageData(for display: DeckKeyDisplay) throws -> Data {
        guard display.isWide && display.displayMode != .function else {
            return try renderer.pngData(for: display)
        }

        return try H200ButtonIconRenderer.transparentPNGData(size: display.devicePixelSize)
    }

    private func makeSafePayload(manifestData: Data, imageFiles: [ZIPArchiveFile]) throws -> Data {
        let manifestFile = ZIPArchiveFile(path: "manifest.json", data: manifestData)
        let baseFiles = [manifestFile] + imageFiles
        if let payload = try makePayloadIfSafe(files: baseFiles) {
            return payload
        }

        for placement in SafetyPaddingPlacement.allCases {
            for paddingLength in 1...H200PacketBuilder.packetSize {
                let paddingFile = ZIPArchiveFile(
                    path: "__h200_padding.bin",
                    data: makePaddingData(length: paddingLength)
                )
                let files = filesWithPadding(
                    manifestFile: manifestFile,
                    imageFiles: imageFiles,
                    paddingFile: paddingFile,
                    placement: placement
                )

                if let payload = try makePayloadIfSafe(files: files) {
                    return payload
                }
            }
        }

        throw H200ButtonPackageError.unsafePayloadAfterRetries
    }

    private func makePayloadIfSafe(files: [ZIPArchiveFile]) throws -> Data? {
        let payload = try ZIPArchiveBuilder.makeArchive(files: files)
        return H200PacketBuilder.isPayloadSafe(payload) ? payload : nil
    }

    private func filesWithPadding(
        manifestFile: ZIPArchiveFile,
        imageFiles: [ZIPArchiveFile],
        paddingFile: ZIPArchiveFile,
        placement: SafetyPaddingPlacement
    ) -> [ZIPArchiveFile] {
        switch placement {
        case .afterManifest:
            return [manifestFile, paddingFile] + imageFiles
        case .afterImages:
            return [manifestFile] + imageFiles + [paddingFile]
        case .beforeManifest:
            return [paddingFile, manifestFile] + imageFiles
        }
    }

    private func makePaddingData(length: Int) -> Data {
        let pattern = Array("H200SAFE".utf8)
        return Data((0..<length).map { pattern[$0 % pattern.count] })
    }

    private func iconPath(for display: DeckKeyDisplay) -> String {
        "Images/key_\(display.id).png"
    }
}

nonisolated enum H200ButtonPackageError: Error, Equatable {
    case unsafePayloadAfterRetries
}

nonisolated private enum SafetyPaddingPlacement: CaseIterable {
    case afterManifest
    case afterImages
    case beforeManifest
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
    private static let buttonBackgroundColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)

    nonisolated init() {}

    static func transparentPNGData(size: H200DeviceTarget.PixelSize) throws -> Data {
        let rep = try makeBitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            throw H200ButtonIconRenderError.cannotCreateBitmap
        }

        context.cgContext.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return try pngData(from: rep)
    }

    func pngData(for display: DeckKeyDisplay) throws -> Data {
        let size = display.devicePixelSize
        let rep = try Self.makeBitmap(size: size)

        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(display: display, in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()

        return try Self.pngData(from: rep)
    }

    private static func makeBitmap(size: H200DeviceTarget.PixelSize) throws -> NSBitmapImageRep {
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

        return rep
    }

    private static func pngData(from rep: NSBitmapImageRep) throws -> Data {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw H200ButtonIconRenderError.cannotEncodePNG
        }

        return png
    }

    private func draw(display: DeckKeyDisplay, in rect: NSRect) {
        drawBackground(for: display, in: rect)

        let inset = rect.height * 0.08
        let cardRect = rect.insetBy(dx: inset, dy: inset)
        if let content = display.mihoyoGameButtonContent {
            drawMihoyoGameContent(content, in: cardRect, buttonRect: rect)
            return
        }

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

    private func drawBackground(for display: DeckKeyDisplay, in rect: NSRect) {
        guard let game = display.mihoyoGame,
              let image = NSImage(named: NSImage.Name(game.buttonBackgroundAssetName))
        else {
            Self.buttonBackgroundColor.setFill()
            rect.fill()
            return
        }

        let imageRect = NSRect(origin: .zero, size: image.size)
        image.draw(
            in: rect,
            from: imageRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSColor(calibratedWhite: 0, alpha: 0.38).setFill()
        rect.fill()
    }

    private func drawMihoyoGameContent(
        _ content: MihoyoGameButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        let labelFont = NSFont.systemFont(ofSize: buttonRect.height * 0.105, weight: .semibold)
        let valueFont = NSFont.systemFont(ofSize: buttonRect.height * 0.235, weight: .heavy)
        let valueSuffixFont = NSFont.systemFont(ofSize: buttonRect.height * 0.145, weight: .heavy)
        let labelHeight = buttonRect.height * 0.13
        let valueHeight = buttonRect.height * 0.25
        let gap = buttonRect.height * 0.035
        let totalHeight = labelHeight + valueHeight + gap + labelHeight + valueHeight
        let top = rect.midY + totalHeight / 2
        let shadow = textShadow()

        drawCenteredText(
            content.staminaLabel,
            font: labelFont,
            color: NSColor(calibratedWhite: 0.88, alpha: 1),
            rect: NSRect(x: rect.minX, y: top - labelHeight, width: rect.width, height: labelHeight),
            shadow: shadow
        )
        drawCenteredMetricValue(
            content.staminaValue,
            currentFont: valueFont,
            maximumFont: valueSuffixFont,
            color: .white,
            rect: NSRect(x: rect.minX, y: top - labelHeight - valueHeight, width: rect.width, height: valueHeight),
            shadow: shadow
        )
        drawCenteredText(
            content.dailyLabel,
            font: labelFont,
            color: NSColor(calibratedWhite: 0.88, alpha: 1),
            rect: NSRect(
                x: rect.minX,
                y: top - labelHeight - valueHeight - gap - labelHeight,
                width: rect.width,
                height: labelHeight
            ),
            shadow: shadow
        )
        drawCenteredMetricValue(
            content.dailyValue,
            currentFont: valueFont,
            maximumFont: valueSuffixFont,
            color: .white,
            rect: NSRect(x: rect.minX, y: top - totalHeight, width: rect.width, height: valueHeight),
            shadow: shadow
        )
    }

    private func textShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.72)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        return shadow
    }

    private func drawCenteredText(
        _ text: String,
        font: NSFont,
        color: NSColor,
        rect: NSRect,
        shadow: NSShadow? = nil
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        attributes[.shadow] = shadow
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
    }

    private func drawCenteredMetricValue(
        _ text: String,
        currentFont: NSFont,
        maximumFont: NSFont,
        color: NSColor,
        rect: NSRect,
        shadow: NSShadow? = nil
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let value = NSMutableAttributedString(string: text, attributes: [
            .font: currentFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])

        if let slashRange = text.range(of: "/") {
            let suffixRange = NSRange(slashRange.lowerBound..<text.endIndex, in: text)
            value.addAttributes([
                .font: maximumFont,
                .baselineOffset: (currentFont.pointSize - maximumFont.pointSize) * 0.16,
            ], range: suffixRange)
        }

        if let shadow {
            value.addAttribute(.shadow, value: shadow, range: NSRange(location: 0, length: value.length))
        }
        value.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

nonisolated enum H200ButtonIconRenderError: Error, Equatable {
    case cannotCreateBitmap
    case cannotEncodePNG
}
