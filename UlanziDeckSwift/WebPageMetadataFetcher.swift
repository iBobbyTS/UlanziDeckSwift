import AppKit
import Foundation

nonisolated enum WebPageURLError: Error {
    case invalid
}

nonisolated struct WebPageURL: Equatable, Sendable {
    let url: URL

    init(_ rawValue: String) throws {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw WebPageURLError.invalid
        }

        let urlString = trimmedValue.contains("://") ? trimmedValue : "https://\(trimmedValue)"
        guard var components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.user == nil,
              components.password == nil,
              let host = components.host,
              !host.isEmpty
        else {
            throw WebPageURLError.invalid
        }

        components.scheme = scheme
        if components.path == "/" {
            components.path = ""
        }

        guard let url = components.url else {
            throw WebPageURLError.invalid
        }

        self.url = url
    }

    var normalizedString: String {
        url.absoluteString
    }

    var displayHost: String {
        url.host ?? normalizedString
    }

    func resolvedURL(for rawReference: String) -> URL? {
        let reference = rawReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reference.isEmpty else {
            return nil
        }

        return URL(string: reference, relativeTo: url)?.absoluteURL
    }
}

nonisolated struct WebPageMetadata: Equatable, Sendable {
    let title: String?
    let iconSnapshot: FileIconSnapshotData?
}

nonisolated protocol WebPageMetadataFetching: Sendable {
    func fetchMetadata(for urlString: String) async -> WebPageMetadata?
}

nonisolated struct WebPageMetadataFetcher: WebPageMetadataFetching {
    private static let defaultMaximumHTMLBytes = 256 * 1024
    private static let defaultMaximumIconBytes = 1024 * 1024

    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval
    private let maximumHTMLBytes: Int
    private let maximumIconBytes: Int

    nonisolated init(
        urlSession: URLSession = .shared,
        timeoutSeconds: TimeInterval = 10,
        maximumHTMLBytes: Int = Self.defaultMaximumHTMLBytes,
        maximumIconBytes: Int = Self.defaultMaximumIconBytes
    ) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
        self.maximumHTMLBytes = maximumHTMLBytes
        self.maximumIconBytes = maximumIconBytes
    }

    func fetchMetadata(for urlString: String) async -> WebPageMetadata? {
        guard let webPageURL = try? WebPageURL(urlString) else {
            return nil
        }

        let html = await fetchText(from: webPageURL.url) ?? ""
        let title = Self.extractedTitle(from: html)
        let iconURL = Self.iconURL(from: html, baseURL: webPageURL)
            ?? webPageURL.url.appendingPathComponent("favicon.ico")
        let iconSnapshot = await fetchIconSnapshot(from: iconURL)

        guard title != nil || iconSnapshot != nil else {
            return nil
        }

        return WebPageMetadata(title: title, iconSnapshot: iconSnapshot)
    }

    private func fetchText(from url: URL) async -> String? {
        let data = await fetchData(
            from: url,
            maximumBytes: maximumHTMLBytes,
            acceptedMIMETypes: Self.acceptedHTMLMIMETypes
        )
        guard let data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private func fetchIconSnapshot(from url: URL) async -> FileIconSnapshotData? {
        guard let data = await fetchData(
            from: url,
            maximumBytes: maximumIconBytes,
            acceptedMIMETypes: Self.acceptedIconMIMETypes
        ),
              let image = NSImage(data: data)
        else {
            return nil
        }

        return FileIconSnapshot.snapshotData(for: image)
    }

    private func fetchData(
        from url: URL,
        maximumBytes: Int,
        acceptedMIMETypes: Set<String>
    ) async -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (bytes, response) = try await urlSession.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  Self.isAcceptedURL(response.url),
                  Self.isAcceptedMIMEType(httpResponse.mimeType, acceptedMIMETypes: acceptedMIMETypes),
                  Self.isAcceptedContentLength(httpResponse.expectedContentLength, maximumBytes: maximumBytes)
            else {
                return nil
            }

            var data = Data()
            data.reserveCapacity(min(maximumBytes, 64 * 1024))
            for try await byte in bytes {
                guard data.count < maximumBytes else {
                    return nil
                }
                data.append(byte)
            }

            return data
        } catch {
            return nil
        }
    }

    private static let acceptedHTMLMIMETypes: Set<String> = [
        "text/html",
        "application/xhtml+xml",
    ]

    private static let acceptedIconMIMETypes: Set<String> = [
        "image/apng",
        "image/avif",
        "image/gif",
        "image/jpeg",
        "image/png",
        "image/svg+xml",
        "image/webp",
        "image/x-icon",
        "image/vnd.microsoft.icon",
    ]

    private static func isAcceptedURL(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else {
            return false
        }

        return scheme == "http" || scheme == "https"
    }

    private static func isAcceptedMIMEType(_ mimeType: String?, acceptedMIMETypes: Set<String>) -> Bool {
        guard let mimeType = mimeType?.lowercased() else {
            return true
        }

        return acceptedMIMETypes.contains(mimeType)
    }

    private static func isAcceptedContentLength(_ expectedContentLength: Int64, maximumBytes: Int) -> Bool {
        expectedContentLength < 0 || expectedContentLength <= Int64(maximumBytes)
    }

    private static func extractedTitle(from html: String) -> String? {
        guard let range = html.range(
            of: #"(?is)<title[^>]*>(.*?)</title>"#,
            options: [.regularExpression]
        ) else {
            return nil
        }

        let matchedText = String(html[range])
        guard let start = matchedText.range(of: ">"),
              let end = matchedText.range(of: "</title>", options: [.caseInsensitive, .backwards]),
              start.upperBound < end.lowerBound
        else {
            return nil
        }

        return normalizedHTMLText(String(matchedText[start.upperBound..<end.lowerBound]))
    }

    private static func iconURL(from html: String, baseURL: WebPageURL) -> URL? {
        let linkPattern = #"<link\b[^>]*>"#
        let matches = html.matches(of: linkPattern, options: [.regularExpression, .caseInsensitive])

        for tag in matches {
            guard let rel = attributeValue(named: "rel", in: tag),
                  rel.lowercased().split(whereSeparator: { $0.isWhitespace }).contains(where: { $0 == "icon" || $0 == "shortcut" || $0 == "apple-touch-icon" }),
                  let href = attributeValue(named: "href", in: tag),
                  let url = baseURL.resolvedURL(for: href)
            else {
                continue
            }

            return url
        }

        return nil
    }

    private static func attributeValue(named name: String, in tag: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let quotedPattern = #"\b\#(escapedName)\s*=\s*["']([^"']+)["']"#
        if let range = tag.range(of: quotedPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(tag[range])
            if let equalsIndex = matchedText.firstIndex(of: "=") {
                let rawValue = matchedText[matchedText.index(after: equalsIndex)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }

        let unquotedPattern = #"\b\#(escapedName)\s*=\s*([^\s>]+)"#
        guard let range = tag.range(of: unquotedPattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let matchedText = String(tag[range])
        guard let equalsIndex = matchedText.firstIndex(of: "=") else {
            return nil
        }

        return matchedText[matchedText.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedHTMLText(_ value: String) -> String? {
        let decodedText = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
        let normalizedText = decodedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizedText.isEmpty ? nil : normalizedText
    }
}

private extension String {
    nonisolated func matches(of pattern: String, options: String.CompareOptions) -> [String] {
        var matches: [String] = []
        var searchRange = startIndex..<endIndex
        while let range = range(of: pattern, options: options, range: searchRange) {
            matches.append(String(self[range]))
            searchRange = range.upperBound..<endIndex
        }

        return matches
    }
}

protocol WebPageOpening {
    @MainActor
    func openWebPage(_ configuration: DeckKeyOpenWebPageConfiguration) -> Bool
}

struct WebPageOpener: WebPageOpening {
    @MainActor
    func openWebPage(_ configuration: DeckKeyOpenWebPageConfiguration) -> Bool {
        guard let url = configuration.url else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}
