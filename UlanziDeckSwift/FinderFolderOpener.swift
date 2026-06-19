import AppKit
import Foundation

enum FinderResourceOpenResult<Configuration: Equatable>: Equatable {
    case opened(refreshedConfiguration: Configuration?)
    case needsReselection
    case failed
}

typealias FinderFolderOpenResult = FinderResourceOpenResult<DeckKeyOpenFolderConfiguration>
typealias FinderFileOpenResult = FinderResourceOpenResult<DeckKeyOpenFileConfiguration>

private protocol FinderSecurityScopedResourceConfiguration {
    static var securityScopedBookmarkResolutionOptions: URL.BookmarkResolutionOptions { get }

    var bookmarkData: Data? { get }
}

extension DeckKeyOpenFolderConfiguration: FinderSecurityScopedResourceConfiguration {}
extension DeckKeyOpenFileConfiguration: FinderSecurityScopedResourceConfiguration {}

protocol FinderFolderOpening {
    @MainActor
    func openFolder(_ configuration: DeckKeyOpenFolderConfiguration) -> FinderFolderOpenResult
}

protocol FinderFileOpening {
    @MainActor
    func openFile(_ configuration: DeckKeyOpenFileConfiguration) -> FinderFileOpenResult
}

private enum FinderSecurityScopedResourceOpener {
    @MainActor
    static func open<Configuration: FinderSecurityScopedResourceConfiguration & Equatable>(
        _ configuration: Configuration,
        refreshedConfiguration: (URL) -> Configuration?
    ) -> FinderResourceOpenResult<Configuration> {
        guard let bookmarkData = configuration.bookmarkData else {
            return .needsReselection
        }

        let url: URL
        var isStale = false
        do {
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: Configuration.securityScopedBookmarkResolutionOptions,
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
              let refreshedConfiguration = refreshedConfiguration(url)
        else {
            return .opened(refreshedConfiguration: nil)
        }

        return .opened(refreshedConfiguration: refreshedConfiguration)
    }
}

struct FinderFolderOpener: FinderFolderOpening {
    @MainActor
    func openFolder(_ configuration: DeckKeyOpenFolderConfiguration) -> FinderFolderOpenResult {
        FinderSecurityScopedResourceOpener.open(configuration) { url in
            try? DeckKeyOpenFolderConfiguration(folderURL: url)
        }
    }
}

struct FinderFileOpener: FinderFileOpening {
    @MainActor
    func openFile(_ configuration: DeckKeyOpenFileConfiguration) -> FinderFileOpenResult {
        FinderSecurityScopedResourceOpener.open(configuration) { url in
            try? DeckKeyOpenFileConfiguration(fileURL: url)
        }
    }
}
