import Foundation

nonisolated enum AuthenticatedHTTPResponseError: Error, LocalizedError, Equatable {
    case nonHTTPResponse
    case unauthorized
    case unexpectedStatus(Int)
    case unexpectedOrigin
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .nonHTTPResponse:
            return "服务器响应不是 HTTP 响应"
        case .unauthorized:
            return "认证凭据无效或已过期"
        case let .unexpectedStatus(statusCode):
            return "服务器返回 HTTP \(statusCode)"
        case .unexpectedOrigin:
            return "服务器尝试将认证请求重定向到其他来源"
        case .responseTooLarge:
            return "服务器响应超过允许大小"
        }
    }
}

nonisolated enum AuthenticatedHTTPResponseLoader {
    static let defaultMaximumBytes = 1024 * 1024

    static func data(
        for request: URLRequest,
        urlSession: URLSession,
        maximumBytes: Int = defaultMaximumBytes
    ) async throws -> Data {
        guard let expectedURL = request.url else {
            throw AuthenticatedHTTPResponseError.unexpectedOrigin
        }

        let (bytes, response) = try await urlSession.bytes(
            for: request,
            delegate: SameOriginAuthenticatedRedirectDelegate.shared
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticatedHTTPResponseError.nonHTTPResponse
        }
        guard httpResponse.statusCode != 401 else {
            throw AuthenticatedHTTPResponseError.unauthorized
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthenticatedHTTPResponseError.unexpectedStatus(httpResponse.statusCode)
        }
        guard sameOrigin(expectedURL, httpResponse.url) else {
            throw AuthenticatedHTTPResponseError.unexpectedOrigin
        }
        if httpResponse.expectedContentLength > Int64(maximumBytes) {
            throw AuthenticatedHTTPResponseError.responseTooLarge
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes, 64 * 1024))
        for try await byte in bytes {
            guard data.count < maximumBytes else {
                throw AuthenticatedHTTPResponseError.responseTooLarge
            }
            data.append(byte)
        }
        return data
    }

    fileprivate static func sameOrigin(_ expected: URL, _ actual: URL?) -> Bool {
        guard let actual else {
            return false
        }

        return expected.scheme?.lowercased() == actual.scheme?.lowercased()
            && expected.host?.lowercased() == actual.host?.lowercased()
            && effectivePort(expected) == effectivePort(actual)
    }

    private static func effectivePort(_ url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }
}

nonisolated final class SameOriginAuthenticatedRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = SameOriginAuthenticatedRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let originalRequest = task.originalRequest,
              let originalURL = originalRequest.url,
              AuthenticatedHTTPResponseLoader.sameOrigin(originalURL, request.url)
        else {
            completionHandler(nil)
            return
        }

        var authenticatedRequest = request
        authenticatedRequest.setValue(
            originalRequest.value(forHTTPHeaderField: "Authorization"),
            forHTTPHeaderField: "Authorization"
        )
        completionHandler(authenticatedRequest)
    }
}
