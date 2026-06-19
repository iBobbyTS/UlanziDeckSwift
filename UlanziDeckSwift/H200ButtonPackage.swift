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

nonisolated struct AutoSizedSingleLineText {
    nonisolated enum FontStyle {
        case system
        case monospacedDigitSystem
    }

    let text: String
    let sampleText: String
    let fontStyle: FontStyle
    let weight: NSFont.Weight
    let maxFontSize: CGFloat
    let minFontSize: CGFloat

    init(
        text: String,
        sampleText: String? = nil,
        fontStyle: FontStyle = .system,
        weight: NSFont.Weight,
        maxFontSize: CGFloat,
        minFontSize: CGFloat
    ) {
        self.text = text
        self.sampleText = sampleText ?? text
        self.fontStyle = fontStyle
        self.weight = weight
        self.maxFontSize = maxFontSize
        self.minFontSize = minFontSize
    }

    /// 返回一个能放进允许区域的单行字体。
    ///
    /// - Parameters:
    ///   - allowedWidth: 允许宽度。宽度通常从实际按钮宽度来，除非一行有多种字体的排版。
    ///   - allowedHeight: 允许高度。高度根据排版设计决定。
    ///
    /// 这个组件只按单行测量，不允许换行。
    func fittedFont(allowedWidth: CGFloat, allowedHeight: CGFloat) -> NSFont {
        let safeMaxFontSize = Swift.max(Swift.max(maxFontSize, minFontSize), 1)
        let safeMinFontSize = Swift.max(Swift.min(minFontSize, safeMaxFontSize), 1)
        guard allowedWidth > 0, allowedHeight > 0 else {
            return font(ofSize: safeMinFontSize)
        }

        let maxFont = font(ofSize: safeMaxFontSize)
        let measuredWidth = singleLineWidth(font: maxFont)
        let measuredHeight = singleLineHeight(font: maxFont)
        guard measuredWidth > 0, measuredHeight > 0 else {
            return maxFont
        }

        let widthScale = allowedWidth / measuredWidth
        let heightScale = allowedHeight / measuredHeight
        let scale = Swift.min(1, Swift.min(widthScale, heightScale))
        let fittedSize = Swift.max(safeMinFontSize, floor(safeMaxFontSize * scale))
        return font(ofSize: fittedSize)
    }

    private func font(ofSize size: CGFloat) -> NSFont {
        switch fontStyle {
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .monospacedDigitSystem:
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        }
    }

    private func singleLineWidth(font: NSFont) -> CGFloat {
        let measurementText = sampleText.isEmpty ? text : sampleText
        return (measurementText as NSString).size(withAttributes: [.font: font]).width
    }

    private func singleLineHeight(font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }
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
        if let content = display.sub2APIButtonContent {
            drawSub2APIContent(content, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.folderButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.smbServerButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }

        drawCenteredAutoSizedSingleLineText(
            display.title,
            weight: .bold,
            maxFontSize: rect.height * 0.43,
            minFontSize: rect.height * 0.14,
            color: .white,
            rect: NSRect(x: cardRect.minX, y: cardRect.midY - rect.height * 0.08, width: cardRect.width, height: rect.height * 0.5)
        )
        drawCenteredAutoSizedSingleLineText(
            display.subtitle,
            weight: .semibold,
            maxFontSize: rect.height * 0.15,
            minFontSize: rect.height * 0.09,
            color: NSColor(calibratedWhite: 0.82, alpha: 1),
            rect: NSRect(x: cardRect.minX, y: cardRect.midY - rect.height * 0.26, width: cardRect.width, height: rect.height * 0.2)
        )
    }

    private func drawBackground(for display: DeckKeyDisplay, in rect: NSRect) {
        let backgroundAssetName: String?
        if let game = display.mihoyoGame {
            backgroundAssetName = game.buttonBackgroundAssetName
        } else if display.folderButtonContent != nil {
            backgroundAssetName = FolderButtonContent.backgroundAssetName
        } else if display.smbServerButtonContent != nil {
            backgroundAssetName = SMBServerButtonContent.backgroundAssetName
        } else {
            backgroundAssetName = nil
        }

        guard let backgroundAssetName,
              let image = NSImage(named: NSImage.Name(backgroundAssetName))
        else {
            Self.buttonBackgroundColor.setFill()
            rect.fill()
            return
        }

        if display.folderButtonContent != nil || display.smbServerButtonContent != nil {
            drawFittedBackgroundImage(image, in: rect)
        } else {
            let imageRect = NSRect(origin: .zero, size: image.size)
            image.draw(
                in: rect,
                from: imageRect,
                operation: .copy,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSColor(calibratedWhite: 0, alpha: 0.38).setFill()
        rect.fill()
    }

    private func drawFittedBackgroundImage(_ image: NSImage, in rect: NSRect) {
        Self.buttonBackgroundColor.setFill()
        rect.fill()

        let imageRect = NSRect(origin: .zero, size: image.size)
        guard imageRect.width > 0, imageRect.height > 0 else {
            return
        }

        let scale = min(rect.width / imageRect.width, rect.height / imageRect.height)
        let drawSize = NSSize(width: imageRect.width * scale, height: imageRect.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(
            in: drawRect,
            from: imageRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawShortcutContent(
        _ displayName: String,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        drawCenteredAutoSizedSingleLineText(
            displayName,
            weight: .heavy,
            maxFontSize: buttonRect.height * 0.32,
            minFontSize: buttonRect.height * 0.12,
            color: .white,
            rect: NSRect(x: rect.minX, y: rect.midY - buttonRect.height * 0.18, width: rect.width, height: buttonRect.height * 0.36),
            shadow: textShadow()
        )
    }

    private func drawSub2APIContent(
        _ content: Sub2APIButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        let labelHeight = buttonRect.height * 0.13
        let valueHeight = buttonRect.height * 0.39
        let gap = buttonRect.height * 0.045
        let totalHeight = labelHeight + labelHeight + gap + valueHeight
        let top = rect.midY + totalHeight / 2
        let shadow = textShadow()
        let valueFont = AutoSizedSingleLineText(
            text: content.availableConcurrencyText,
            sampleText: content.availableConcurrencyText.count <= 4
                ? String(repeating: "0", count: 4)
                : content.availableConcurrencyText,
            fontStyle: .monospacedDigitSystem,
            weight: .heavy,
            maxFontSize: buttonRect.height * 0.36,
            minFontSize: buttonRect.height * 0.22
        )
        .fittedFont(
            allowedWidth: rect.width * 0.94,
            allowedHeight: valueHeight
        )
        let labelColor = NSColor(calibratedWhite: 0.86, alpha: 1)

        drawCenteredAutoSizedSingleLineText(
            content.serviceName,
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.13,
            minFontSize: buttonRect.height * 0.085,
            color: labelColor,
            rect: NSRect(x: rect.minX, y: top - labelHeight, width: rect.width, height: labelHeight),
            shadow: shadow
        )
        drawCenteredAutoSizedSingleLineText(
            content.groupName,
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.13,
            minFontSize: buttonRect.height * 0.085,
            color: labelColor,
            rect: NSRect(x: rect.minX, y: top - labelHeight * 2, width: rect.width, height: labelHeight),
            shadow: shadow
        )
        drawCenteredSingleLineText(
            content.availableConcurrencyText,
            font: valueFont,
            color: sub2APIAvailabilityColor(for: content.availabilityLevel),
            rect: NSRect(x: rect.minX, y: top - totalHeight, width: rect.width, height: valueHeight),
            shadow: shadow
        )
    }

    private func sub2APIAvailabilityColor(for level: Sub2APIAvailabilityLevel) -> NSColor {
        switch level {
        case .healthy:
            return NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.42, alpha: 1)
        case .warning:
            return NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        case .critical:
            return NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.24, alpha: 1)
        }
    }

    private func drawMihoyoGameContent(
        _ content: MihoyoGameButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        let valueFont = NSFont.systemFont(ofSize: buttonRect.height * 0.235, weight: .heavy)
        let valueSuffixFont = NSFont.systemFont(ofSize: buttonRect.height * 0.145, weight: .heavy)
        let labelHeight = buttonRect.height * 0.13
        let valueHeight = buttonRect.height * 0.25
        let gap = buttonRect.height * 0.035
        let totalHeight = labelHeight + valueHeight + gap + labelHeight + valueHeight
        let top = rect.midY + totalHeight / 2
        let shadow = textShadow()

        drawCenteredAutoSizedSingleLineText(
            content.staminaLabel,
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.12,
            minFontSize: buttonRect.height * 0.08,
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
        drawCenteredAutoSizedSingleLineText(
            content.dailyLabel,
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.12,
            minFontSize: buttonRect.height * 0.08,
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

    private func drawCenteredAutoSizedSingleLineText(
        _ text: String,
        weight: NSFont.Weight,
        maxFontSize: CGFloat,
        minFontSize: CGFloat,
        color: NSColor,
        rect: NSRect,
        shadow: NSShadow? = nil
    ) {
        let font = AutoSizedSingleLineText(
            text: text,
            weight: weight,
            maxFontSize: maxFontSize,
            minFontSize: minFontSize
        )
        .fittedFont(allowedWidth: rect.width, allowedHeight: rect.height)
        drawCenteredSingleLineText(
            text,
            font: font,
            color: color,
            rect: rect,
            shadow: shadow
        )
    }

    private func drawCenteredSingleLineText(
        _ text: String,
        font: NSFont,
        color: NSColor,
        rect: NSRect,
        shadow: NSShadow? = nil
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        attributes[.shadow] = shadow
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            attributes: attributes
        )
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
