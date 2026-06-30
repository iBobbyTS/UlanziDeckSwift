import AppKit
import Foundation

nonisolated enum DefaultButtonBackgroundSnapshot {
    static func visual(for function: DeckKeyFunction) -> DeckKeyVisualConfiguration? {
        if let symbolName = systemSymbolName(for: function) {
            return visualFromSystemSymbol(named: symbolName)
        }

        guard let sourceAssetName = sourceAssetName(for: function),
              let sourceImage = NSImage(named: NSImage.Name(sourceAssetName)),
              let snapshot = FileIconSnapshot.snapshotData(for: sourceImage)
        else {
            return nil
        }

        return DeckKeyVisualConfiguration(
            backgroundPNGData: snapshot.iconPNGData,
            blurredBackgroundPNGData: snapshot.blurredIconPNGData
        )
    }

    private static func sourceAssetName(for function: DeckKeyFunction) -> String? {
        switch function {
        case .openFolder:
            return "FolderBackground"
        case .connectSMBServer:
            return "SMBServerBackground"
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return function.game?.buttonBackgroundAssetName
        case .none, .tally, .openFile, .brightness, .sub2API, .pageFolder, .pageBack:
            return nil
        }
    }

    private static func systemSymbolName(for function: DeckKeyFunction) -> String? {
        switch function {
        case .pageFolder:
            return "folder"
        case .pageBack:
            return "arrow.uturn.left"
        case .none, .tally, .openFolder, .openFile, .connectSMBServer, .brightness, .sub2API, .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return nil
        }
    }

    private static func visualFromSystemSymbol(named symbolName: String) -> DeckKeyVisualConfiguration? {
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 512, weight: .regular)
            .applying(.init(hierarchicalColor: .white))
        guard let sourceImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration),
            let image = imageWithBlackBackground(for: sourceImage) else {
            return nil
        }

        guard let snapshot = FileIconSnapshot.snapshotData(for: image) else {
            return nil
        }

        return DeckKeyVisualConfiguration(
            backgroundPNGData: snapshot.iconPNGData,
            blurredBackgroundPNGData: snapshot.blurredIconPNGData
        )
    }

    private static func imageWithBlackBackground(for image: NSImage) -> NSImage? {
        let pixelSize = NSSize(width: FileIconSnapshot.targetLongEdge, height: FileIconSnapshot.targetLongEdge)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        rep.size = pixelSize

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        context?.imageInterpolation = .high

        let canvasRect = NSRect(origin: .zero, size: pixelSize)
        NSColor.black.setFill()
        canvasRect.fill()

        image.isTemplate = false
        let imageRect = NSRect(origin: .zero, size: image.size)
        if imageRect.width > 0, imageRect.height > 0 {
            let scale = min(canvasRect.width / imageRect.width, canvasRect.height / imageRect.height)
            let drawSize = NSSize(width: imageRect.width * scale, height: imageRect.height * scale)
            let drawRect = NSRect(
                x: canvasRect.midX - drawSize.width / 2,
                y: canvasRect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(
                in: drawRect,
                from: imageRect,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: pixelSize)
    }
}

extension DeckKeyConfiguration {
    nonisolated mutating func refreshDefaultButtonBackgroundSnapshot() {
        guard let defaultVisual = DefaultButtonBackgroundSnapshot.visual(for: function) else {
            sanitizeButtonVisualBlurState()
            return
        }

        switch function {
        case .openFolder:
            openFolder.visual.replaceBackground(with: defaultVisual)
        case .connectSMBServer:
            smbServer.visual.replaceBackground(with: defaultVisual)
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            mihoyoGame.visual.replaceBackground(with: defaultVisual)
        case .pageFolder:
            pageFolder.visual.replaceBackground(with: defaultVisual)
        case .pageBack:
            visual.replaceBackground(with: defaultVisual)
        case .none, .tally, .openFile, .brightness, .sub2API:
            break
        }

        sanitizeButtonVisualBlurState()
    }

    nonisolated mutating func clearDefaultButtonBackgroundSnapshot(for function: DeckKeyFunction? = nil) {
        switch function ?? self.function {
        case .openFolder:
            openFolder.visual.clearBackground()
        case .connectSMBServer:
            smbServer.visual.clearBackground()
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            mihoyoGame.visual.clearBackground()
        case .pageFolder:
            pageFolder.visual.clearBackground()
        case .pageBack:
            visual.clearBackground()
        case .none, .tally, .openFile, .brightness, .sub2API:
            break
        }

        sanitizeButtonVisualBlurState()
    }

    nonisolated mutating func sanitizeButtonVisualBlurState() {
        if visual.usesBlurredBackground && !buttonVisualCanUseBlurredBackground {
            visual.usesBlurredBackground = false
        }
    }
}

private extension DeckKeyVisualConfiguration {
    nonisolated mutating func replaceBackground(with visual: DeckKeyVisualConfiguration) {
        backgroundPNGData = visual.backgroundPNGData
        blurredBackgroundPNGData = visual.blurredBackgroundPNGData
        usesBlurredBackground = false
    }

    nonisolated mutating func clearBackground() {
        backgroundPNGData = nil
        blurredBackgroundPNGData = nil
        usesBlurredBackground = false
    }
}
