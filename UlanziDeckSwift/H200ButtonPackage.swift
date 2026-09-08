import AppKit
import Foundation

/// New API 可用率图表的纵轴合同：始终固定为 0% 到 100%。
enum NewAPIAvailabilityChartScale {
    nonisolated static let minimum: Double = 0
    nonisolated static let maximum: Double = 100

    nonisolated static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(maximum, max(minimum, value)) / (maximum - minimum)
    }
}

nonisolated struct H200ButtonPackage: Equatable {
    let payload: Data
    let manifestData: Data
    let displayCount: Int
}

nonisolated protocol H200ButtonIconRendering {
    func pngData(
        for display: DeckKeyDisplay,
        colorTemperatureKelvin: Double?
    ) throws -> Data
}

extension H200ButtonIconRendering {
    nonisolated func pngData(for display: DeckKeyDisplay) throws -> Data {
        try pngData(for: display, colorTemperatureKelvin: nil)
    }
}

nonisolated struct H200ButtonPackageBuilder {
    private let renderer: H200ButtonIconRendering

    nonisolated init(renderer: H200ButtonIconRendering = H200ButtonIconRenderer()) {
        self.renderer = renderer
    }

    func buildPackage(
        displays: [DeckKeyDisplay],
        colorTemperatureKelvin: Double? = nil
    ) throws -> H200ButtonPackage {
        let sortedDisplays = displays.sorted { first, second in
            if first.row == second.row {
                return first.column < second.column
            }

            return first.row < second.row
        }

        let manifest = try buildManifest(displays: sortedDisplays)
        let manifestData = try makeJSONData(manifest)
        let imageFiles = try sortedDisplays.map { display in
            ZIPArchiveFile(
                path: iconPath(for: display),
                data: try imageData(
                    for: display,
                    colorTemperatureKelvin: colorTemperatureKelvin
                )
            )
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

    private func imageData(
        for display: DeckKeyDisplay,
        colorTemperatureKelvin: Double?
    ) throws -> Data {
        guard display.isWide && display.displayMode != .function else {
            return try renderer.pngData(
                for: display,
                colorTemperatureKelvin: colorTemperatureKelvin
            )
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

    static func verticallyCenteredLineRect(font: NSFont, in rect: NSRect) -> NSRect {
        guard rect.width > 0, rect.height > 0 else {
            return rect
        }

        let lineHeight = Swift.min(singleLineHeight(font: font), rect.height)
        return NSRect(
            x: rect.minX,
            y: rect.midY - lineHeight / 2,
            width: rect.width,
            height: lineHeight
        )
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

    private static func singleLineHeight(font: NSFont) -> CGFloat {
        Swift.max(1, ceil(font.ascender - font.descender + font.leading))
    }

    private func singleLineHeight(font: NSFont) -> CGFloat {
        Self.singleLineHeight(font: font)
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

    func pngData(
        for display: DeckKeyDisplay,
        colorTemperatureKelvin: Double?
    ) throws -> Data {
        let size = display.devicePixelSize
        let rep = try Self.makeBitmap(size: size)

        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(display: display, in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()

        return try H200ButtonColorTemperatureFilter.pngData(
            from: rep,
            colorTemperatureKelvin: colorTemperatureKelvin
        )
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
        if display.isDailyReminder {
            drawDailyReminderContent(display, in: cardRect, buttonRect: rect)
            return
        }
        if display.buttonVisualContent.hasCustomDisplayName {
            drawShortcutContent(display.title, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.codexUsageButtonContent {
            drawCodexUsageContent(content, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.mihoyoGameButtonContent {
            drawMihoyoGameContent(content, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.newAPIModelAvailabilityButtonContent {
            drawNewAPIModelAvailabilityContent(content, in: cardRect, buttonRect: rect)
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
        if let content = display.fileButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.webPageButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.smbServerButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.pageFolderButtonContent {
            drawShortcutContent(content.displayName, in: cardRect, buttonRect: rect)
            return
        }
        if let content = display.pageBackButtonContent {
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

    private func drawDailyReminderContent(_ display: DeckKeyDisplay, in rect: NSRect, buttonRect: NSRect) {
        let lines = display.title.components(separatedBy: "\n")
        let minimumNumberHeight = max(18, rect.height * 0.2)
        let maximumTextHeight = max(1, rect.height - minimumNumberHeight)
        let textFont = fittedManualLineBreakFont(
            text: lines.joined(separator: "\n"),
            width: rect.width,
            maximumHeight: maximumTextHeight,
            maxSize: rect.height * 0.6,
            minSize: max(8, rect.height * 0.08)
        )
        let lineHeight = ceil(textFont.ascender - textFont.descender + textFont.leading)
        let textHeight = min(maximumTextHeight, max(lineHeight, lineHeight * CGFloat(lines.count)))
        let firstY = rect.maxY - textHeight
        for (index, line) in lines.enumerated() {
            let lineRect = NSRect(x: rect.minX, y: firstY + CGFloat(lines.count - index - 1) * lineHeight, width: rect.width, height: lineHeight)
            drawCenteredSingleLineText(line, font: textFont, color: .white, rect: lineRect, shadow: textShadow())
        }

        let numberRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(1, rect.height - textHeight))
        drawCenteredAutoSizedSingleLineText(
            display.subtitle,
            weight: .semibold,
            maxFontSize: numberRect.height * 0.8,
            minFontSize: max(8, numberRect.height * 0.18),
            color: NSColor(calibratedWhite: 0.9, alpha: 1),
            rect: numberRect,
            shadow: textShadow()
        )
    }

    private func fittedManualLineBreakFont(text: String, width: CGFloat, maximumHeight: CGFloat, maxSize: CGFloat, minSize: CGFloat) -> NSFont {
        var low = max(1, minSize)
        var high = max(low, maxSize)
        for _ in 0..<12 {
            let size = (low + high) / 2
            let font = NSFont.systemFont(ofSize: size, weight: .bold)
            let lines = text.components(separatedBy: "\n")
            let naturalWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            let lineHeight = ceil(font.ascender - font.descender + font.leading)
            let totalHeight = lineHeight * CGFloat(lines.count)
            if totalHeight <= maximumHeight && naturalWidth <= width * 0.96 {
                low = size
            } else {
                high = size
            }
        }
        return NSFont.systemFont(ofSize: low, weight: .bold)
    }

    private func drawBackground(for display: DeckKeyDisplay, in rect: NSRect) {
        let visual = display.buttonVisualContent
        if let backgroundPNGData = visual.backgroundPNGData,
           let image = NSImage(data: backgroundPNGData) {
            drawFittedBackgroundImage(image, in: rect)
            drawDimmingIfNeeded(visual.dimsBackground, in: rect)
            return
        }

        if let backgroundAssetName = visual.backgroundAssetName,
           let image = NSImage(named: NSImage.Name(backgroundAssetName)) {
            if visual.usesFittedBackgroundImage {
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

            drawDimmingIfNeeded(visual.dimsBackground, in: rect)
            return
        }

        Self.buttonBackgroundColor.setFill()
        rect.fill()
        drawDimmingIfNeeded(visual.dimsBackground, in: rect)
    }

    private func drawDimmingIfNeeded(_ enabled: Bool, in rect: NSRect) {
        if enabled {
            NSColor(calibratedWhite: 0, alpha: 0.38).setFill()
            rect.fill()
        }
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

    private func drawNewAPIModelAvailabilityContent(
        _ content: NewAPIModelAvailabilityButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        let chartHeight = buttonRect.height * 0.5
        let chartRect = NSRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(chartHeight, rect.height * 0.56)
        ).insetBy(dx: buttonRect.width * 0.035, dy: buttonRect.height * 0.035)
        let textRect = NSRect(
            x: rect.minX,
            y: chartRect.maxY,
            width: rect.width,
            height: max(0, rect.maxY - chartRect.maxY)
        )
        let shadow = textShadow()

        drawCenteredAutoSizedSingleLineText(
            "\(content.serviceName) | \(content.groupName)",
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.12,
            minFontSize: buttonRect.height * 0.075,
            color: NSColor(calibratedWhite: 0.88, alpha: 1),
            rect: NSRect(x: textRect.minX, y: textRect.midY, width: textRect.width, height: textRect.height * 0.42),
            shadow: shadow
        )
        drawCenteredAutoSizedSingleLineText(
            content.successRateText,
            weight: .heavy,
            maxFontSize: buttonRect.height * 0.27,
            minFontSize: buttonRect.height * 0.16,
            color: newAPIAvailabilityStatusColor(for: content.successRate),
            rect: NSRect(x: textRect.minX, y: textRect.minY, width: textRect.width, height: textRect.height * 0.62),
            shadow: shadow
        )

        let values = content.series.map(\.successRate).filter(\.isFinite)
        guard !values.isEmpty, chartRect.width > 0, chartRect.height > 0 else { return }
        // 给描边预留完整的安全边界，避免 0%/100% 端点的线帽被视觉上裁切。
        // 理论上半个线宽即可，这里向外扩展一个完整线宽以抵抗抗锯齿。
        let lineWidth = max(2, buttonRect.height * 0.018)
        // 保持 0%–100% 的数据绘制区域不变，只扩大描边/渐变画布。
        let canvasRect = chartRect.insetBy(dx: -lineWidth, dy: -lineWidth)
        let points = values.enumerated().map { index, value in
            let x = values.count == 1
                ? chartRect.midX
                : chartRect.minX + CGFloat(index) / CGFloat(values.count - 1) * chartRect.width
            // 纵轴固定 0%–100%，禁止按当前数据集自动调整范围。
            let normalized = NewAPIAvailabilityChartScale.normalized(value)
            return NSPoint(x: x, y: chartRect.minY + CGFloat(normalized) * chartRect.height)
        }
        guard let first = points.first else { return }
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
        if points.count == 1 {
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.appendArc(withCenter: first, radius: lineWidth / 2, startAngle: 0, endAngle: 360)
            newAPIAvailabilityGradientColor(for: values[0]).setStroke()
            path.stroke()
            return
        }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpointX = (previous.x + current.x) / 2
            let control1 = NSPoint(x: midpointX, y: previous.y)
            let control2 = NSPoint(x: midpointX, y: current.y)
            path.curve(to: current, controlPoint1: control1, controlPoint2: control2)
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let cgPath = path.cgPath
        context.saveGState()
        context.addPath(cgPath)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        let colors = [
            NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.42, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.24, alpha: 1).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.5, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
            context.restoreGState()
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: canvasRect.midX, y: canvasRect.maxY),
            end: CGPoint(x: canvasRect.midX, y: canvasRect.minY),
            options: []
        )
        context.restoreGState()
    }

    private func newAPIAvailabilityStatusColor(for value: Double) -> NSColor {
        let clamped = min(100, max(0, value.isFinite ? value : 0))
        if clamped > 70 {
            return NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.42, alpha: 1)
        }
        if clamped > 30 {
            return NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        }
        return NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.24, alpha: 1)
    }

    private func newAPIAvailabilityGradientColor(for value: Double) -> NSColor {
        let clamped = min(100, max(0, value.isFinite ? value : 0))
        if clamped > 70 {
            return interpolateNewAPIColor(yellow: true, progress: (clamped - 70) / 30)
        }
        if clamped > 30 {
            return interpolateNewAPIColor(yellow: false, progress: (clamped - 30) / 40)
        }
        return NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.24, alpha: 1)
    }

    private func interpolateNewAPIColor(yellow: Bool, progress: Double) -> NSColor {
        let t = min(1, max(0, progress))
        let start = yellow
            ? NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1)
            : NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.24, alpha: 1)
        let end = yellow
            ? NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.42, alpha: 1)
            : NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        return NSColor(
            calibratedRed: start.redComponent + (end.redComponent - start.redComponent) * t,
            green: start.greenComponent + (end.greenComponent - start.greenComponent) * t,
            blue: start.blueComponent + (end.blueComponent - start.blueComponent) * t,
            alpha: 1
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
            color: mihoyoGameMetricColor(for: content.staminaColor),
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
            color: mihoyoGameMetricColor(for: content.dailyColor),
            rect: NSRect(x: rect.minX, y: top - totalHeight, width: rect.width, height: valueHeight),
            shadow: shadow
        )
    }

    private func drawCodexUsageContent(
        _ content: UsageButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        guard content.metrics.count == 1 else {
            drawMultipleUsageMetrics(content, in: rect, buttonRect: buttonRect)
            return
        }

        let percentageHeight = buttonRect.height * 0.36
        let resetLabelHeight = buttonRect.height * 0.10
        let resetHeight = content.detailValueText == nil ? 0 : buttonRect.height * 0.16
        let gap = buttonRect.height * 0.012
        let nicknameHeight = buttonRect.height * 0.125
        let nicknameGap = buttonRect.height * 0.015
        let nicknameExtraHeight = content.accountNickname == nil ? 0 : nicknameHeight + nicknameGap
        let metricsHeight = percentageHeight + gap + resetLabelHeight + gap + resetHeight
        let totalHeight = nicknameExtraHeight + metricsHeight
        let top = rect.midY + totalHeight / 2
        let metricsTop = top - nicknameExtraHeight
        let shadow = textShadow()

        if let accountNickname = content.accountNickname {
            drawCenteredAutoSizedSingleLineText(
                accountNickname,
                weight: .semibold,
                maxFontSize: buttonRect.height * 0.12,
                minFontSize: buttonRect.height * 0.09,
                color: NSColor(calibratedWhite: 0.88, alpha: 1),
                rect: NSRect(
                    x: rect.minX,
                    y: top - nicknameHeight,
                    width: rect.width,
                    height: nicknameHeight
                ),
                shadow: shadow
            )
        }

        drawCenteredAutoSizedSingleLineText(
            content.percentageText,
            weight: .heavy,
            maxFontSize: buttonRect.height * 0.35,
            minFontSize: buttonRect.height * 0.18,
            color: mihoyoGameMetricColor(for: content.percentageColor),
            rect: NSRect(
                x: rect.minX,
                y: metricsTop - percentageHeight,
                width: rect.width,
                height: percentageHeight
            ),
            shadow: shadow
        )
        drawCenteredAutoSizedSingleLineText(
            content.detailLabelText,
            weight: .semibold,
            maxFontSize: buttonRect.height * 0.095,
            minFontSize: buttonRect.height * 0.075,
            color: .white,
            rect: NSRect(
                x: rect.minX,
                y: metricsTop - percentageHeight - gap - resetLabelHeight,
                width: rect.width,
                height: resetLabelHeight
            ),
            shadow: shadow
        )
        if let detailValueText = content.detailValueText {
            drawCenteredAutoSizedSingleLineText(
                detailValueText,
                weight: .semibold,
                maxFontSize: buttonRect.height * 0.145,
                minFontSize: buttonRect.height * 0.09,
                color: mihoyoGameMetricColor(for: content.detailValueColor),
                rect: NSRect(
                    x: rect.minX,
                    y: metricsTop - metricsHeight,
                    width: rect.width,
                    height: resetHeight
                ),
                shadow: shadow
            )
        }
    }

    private func drawMultipleUsageMetrics(
        _ content: UsageButtonContent,
        in rect: NSRect,
        buttonRect: NSRect
    ) {
        let percentageHeight = buttonRect.height * 0.19
        let detailHeight = buttonRect.height * 0.115
        let detailGap = buttonRect.height * 0.006
        let windowGap = buttonRect.height * 0.018
        let nicknameHeight = buttonRect.height * 0.105
        let nicknameGap = buttonRect.height * 0.018
        let nicknameExtraHeight = content.accountNickname == nil ? 0 : nicknameHeight + nicknameGap
        let metricsHeight = content.metrics.enumerated().reduce(CGFloat.zero) { height, item in
            let (index, metric) = item
            let detailExtraHeight = metric.detailValueText == nil ? 0 : detailGap + detailHeight
            let followingWindowGap = index == content.metrics.indices.last ? 0 : windowGap
            return height + percentageHeight + detailExtraHeight + followingWindowGap
        }
        let top = rect.midY + (nicknameExtraHeight + metricsHeight) / 2
        let shadow = textShadow()
        var cursor = top

        if let accountNickname = content.accountNickname {
            drawCenteredAutoSizedSingleLineText(
                accountNickname,
                weight: .semibold,
                maxFontSize: buttonRect.height * 0.105,
                minFontSize: buttonRect.height * 0.075,
                color: NSColor(calibratedWhite: 0.88, alpha: 1),
                rect: NSRect(
                    x: rect.minX,
                    y: cursor - nicknameHeight,
                    width: rect.width,
                    height: nicknameHeight
                ),
                shadow: shadow
            )
            cursor -= nicknameExtraHeight
        }

        for (index, metric) in content.metrics.enumerated() {
            drawMultipleMetricPercentage(
                metric.percentageText,
                valueColor: mihoyoGameMetricColor(for: metric.percentageColor),
                maxFontSize: buttonRect.height * 0.185,
                minFontSize: buttonRect.height * 0.115,
                rect: NSRect(
                    x: rect.minX,
                    y: cursor - percentageHeight,
                    width: rect.width,
                    height: percentageHeight
                ),
                shadow: shadow
            )
            cursor -= percentageHeight

            if let detailValueText = metric.detailValueText {
                cursor -= detailGap
                drawCenteredAutoSizedSingleLineText(
                    detailValueText,
                    weight: .semibold,
                    maxFontSize: buttonRect.height * 0.115,
                    minFontSize: buttonRect.height * 0.075,
                    color: mihoyoGameMetricColor(for: metric.detailValueColor),
                    rect: NSRect(
                        x: rect.minX,
                        y: cursor - detailHeight,
                        width: rect.width,
                        height: detailHeight
                    ),
                    shadow: shadow
                )
                cursor -= detailHeight
            }

            if index != content.metrics.indices.last {
                cursor -= windowGap
            }
        }
    }

    private func mihoyoGameMetricColor(for color: MihoyoGameMetricColor) -> NSColor {
        switch color {
        case .green:
            return NSColor(calibratedRed: 0.21, green: 0.73, blue: 0.36, alpha: 1)
        case .yellow:
            return NSColor(calibratedRed: 0.88, green: 0.65, blue: 0.15, alpha: 1)
        case .red:
            return NSColor(calibratedRed: 0.88, green: 0.23, blue: 0.20, alpha: 1)
        }
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

    private func drawMultipleMetricPercentage(
        _ text: String,
        valueColor: NSColor,
        maxFontSize: CGFloat,
        minFontSize: CGFloat,
        rect: NSRect,
        shadow: NSShadow?
    ) {
        guard let separator = text.firstIndex(of: " ") else {
            drawCenteredAutoSizedSingleLineText(
                text,
                weight: .heavy,
                maxFontSize: maxFontSize,
                minFontSize: minFontSize,
                color: valueColor,
                rect: rect,
                shadow: shadow
            )
            return
        }

        let label = String(text[..<separator])
        let value = String(text[text.index(after: separator)...])
        let font = AutoSizedSingleLineText(
            text: text,
            weight: .heavy,
            maxFontSize: maxFontSize,
            minFontSize: minFontSize
        ).fittedFont(allowedWidth: rect.width, allowedHeight: rect.height)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ])
        attributed.addAttribute(
            .foregroundColor,
            value: valueColor,
            range: NSRange(location: label.count + 1, length: value.count)
        )
        if let shadow {
            attributed.addAttribute(.shadow, value: shadow, range: NSRange(location: 0, length: attributed.length))
        }
        let lineRect = AutoSizedSingleLineText.verticallyCenteredLineRect(font: font, in: rect)
        attributed.draw(with: lineRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
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
        let lineRect = AutoSizedSingleLineText.verticallyCenteredLineRect(font: font, in: rect)
        paragraph.minimumLineHeight = lineRect.height
        paragraph.maximumLineHeight = lineRect.height
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        attributes[.shadow] = shadow
        (text as NSString).draw(
            with: lineRect,
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
    case cannotApplyColorTemperature
}
