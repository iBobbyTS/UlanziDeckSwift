import AppKit
import Foundation

nonisolated enum DefaultButtonBackgroundSnapshot {
    static func visual(for function: DeckKeyFunction) -> DeckKeyVisualConfiguration? {
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
        case .openFolder, .pageFolder:
            return "FolderBackground"
        case .connectSMBServer:
            return "SMBServerBackground"
        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            return function.game?.buttonBackgroundAssetName
        case .none, .tally, .openFile, .brightness, .sub2API, .pageBack:
            return nil
        }
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
        case .none, .tally, .openFile, .brightness, .sub2API, .pageBack:
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
        case .none, .tally, .openFile, .brightness, .sub2API, .pageBack:
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
