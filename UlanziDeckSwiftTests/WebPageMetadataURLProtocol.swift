import Foundation

final class WebPageMetadataURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        let statusCode: Int
        let mimeType: String?
        let contentLength: Int64?
        let data: Data

        init(statusCode: Int, mimeType: String?, contentLength: Int64? = nil, data: Data) {
            self.statusCode = statusCode
            self.mimeType = mimeType
            self.contentLength = contentLength
            self.data = data
        }
    }

    private static let lock = NSLock()
    private static var stubs: [URL: Stub] = [:]

    static func setStubs(_ newStubs: [URL: Stub]) {
        lock.lock()
        stubs = newStubs
        lock.unlock()
    }

    private static func stub(for url: URL) -> Stub? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return stubs[url]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let stub = Self.stub(for: url)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }

        var headers: [String: String] = [:]
        if let mimeType = stub.mimeType {
            headers["Content-Type"] = mimeType
        }
        if let contentLength = stub.contentLength {
            headers["Content-Length"] = "\(contentLength)"
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
