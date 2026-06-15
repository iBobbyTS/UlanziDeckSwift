import AppKit
import Foundation

protocol FinderFolderOpening {
    @MainActor
    func openFolder(at path: String) -> Bool
}

struct FinderFolderOpener: FinderFolderOpening {
    @MainActor
    func openFolder(at path: String) -> Bool {
        guard !path.isEmpty else {
            return false
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)
        return NSWorkspace.shared.open(url)
    }
}
