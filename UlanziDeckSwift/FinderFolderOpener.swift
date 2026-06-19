import AppKit
import Foundation

enum FinderFolderOpenResult: Equatable {
    case opened(refreshedConfiguration: DeckKeyOpenFolderConfiguration?)
    case needsReselection
    case failed
}

protocol FinderFolderOpening {
    @MainActor
    func openFolder(_ configuration: DeckKeyOpenFolderConfiguration) -> FinderFolderOpenResult
}

struct FinderFolderOpener: FinderFolderOpening {
    @MainActor
    func openFolder(_ configuration: DeckKeyOpenFolderConfiguration) -> FinderFolderOpenResult {
        guard let bookmarkData = configuration.bookmarkData else {
            return .needsReselection
        }

        let url: URL
        var isStale = false
        do {
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            return .failed
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard NSWorkspace.shared.open(url) else {
            return .failed
        }

        guard isStale,
              let refreshedConfiguration = try? DeckKeyOpenFolderConfiguration(folderURL: url)
        else {
            return .opened(refreshedConfiguration: nil)
        }

        return .opened(refreshedConfiguration: refreshedConfiguration)
    }
}
