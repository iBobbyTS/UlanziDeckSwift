import Foundation
import Security

// MARK: - 登录会话

nonisolated struct MihoyoLoginSession: Codable, Equatable, Sendable {
    let accountID: String
    let stokenV2: String
    let mid: String
    let cookieToken: String
    let ltoken: String?
    let deviceID: String
    let deviceFP: String

    var cookieHeader: String {
        var segments = [
            "account_id=\(accountID)",
            "stuid=\(accountID)",
            "stoken_v2=\(stokenV2)",
            "stoken=\(stokenV2)",
            "mid=\(mid)",
            "cookie_token=\(cookieToken)",
            "ltuid=\(accountID)",
            "ltuid_v2=\(accountID)",
            "ltmid_v2=\(mid)",
            "DEVICEFP=\(deviceFP)",
        ]

        if let ltoken, !ltoken.isEmpty {
            segments.append("ltoken=\(ltoken)")
            segments.append("ltoken_v2=\(ltoken)")
        }

        return segments.joined(separator: ";")
    }
}

nonisolated struct MihoyoQRLoginSession: Equatable, Sendable {
    let ticket: String
    let url: String
    let deviceID: String
}

nonisolated enum MihoyoQRCodeStatusResult: Equatable, Sendable {
    case waitingForScan
    case scanned
    case confirmed(MihoyoLoginSession)
    case expired(String)
    case failed(String)
}

nonisolated enum MihoyoLoginState: Equatable, Sendable {
    case notLoggedIn
    case creatingQRCode
    case waitingForScan(MihoyoQRLoginSession)
    case scanned(MihoyoQRLoginSession)
    case loggedIn(accountID: String)
    case failed(String)
    case expired(String)

    var statusText: String {
        switch self {
        case .notLoggedIn:
            return "未登录"
        case .creatingQRCode:
            return "正在生成二维码"
        case .waitingForScan:
            return "等待扫码"
        case .scanned:
            return "已扫码，等待确认"
        case let .loggedIn(accountID):
            return "已登录（账号 \(accountID)）"
        case let .failed(message):
            return "登录失败：\(message)"
        case let .expired(message):
            return "登录已失效：\(message)"
        }
    }

    var qrCodeURLString: String? {
        switch self {
        case let .waitingForScan(session), let .scanned(session):
            return session.url
        case .notLoggedIn, .creatingQRCode, .loggedIn, .failed, .expired:
            return nil
        }
    }

    var canRefreshGameStatus: Bool {
        if case .loggedIn = self {
            return true
        }

        return false
    }

    var loginButtonTitle: String {
        switch self {
        case .notLoggedIn:
            return "生成登录二维码"
        case .creatingQRCode:
            return "正在生成"
        case .waitingForScan, .scanned:
            return "重新生成二维码"
        case .loggedIn, .failed, .expired:
            return "重新登录"
        }
    }
}

nonisolated protocol MihoyoSessionStoring {
    func loadSession() -> MihoyoLoginSession?
    func saveSession(_ session: MihoyoLoginSession)
    func clearSession()
}

nonisolated struct KeychainMihoyoSessionStore: MihoyoSessionStoring {
    static let defaultService = "com.iBobby.UlanziDeckSwift.mihoyo.session"
    static let defaultAccount = "default"

    private let service: String
    private let account: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(service: String = Self.defaultService, account: String = Self.defaultAccount) {
        self.service = service
        self.account = account
    }

    func loadSession() -> MihoyoLoginSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? decoder.decode(MihoyoLoginSession.self, from: data)
    }

    func saveSession(_ session: MihoyoLoginSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        clearSession()
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clearSession() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

nonisolated struct UserDefaultsMihoyoSessionStore: MihoyoSessionStoring {
    static let defaultStorageKey = "com.iBobby.UlanziDeckSwift.mihoyo.session.v1"

    private let defaults: UserDefaults
    private let storageKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, storageKey: String = Self.defaultStorageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func loadSession() -> MihoyoLoginSession? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        return try? decoder.decode(MihoyoLoginSession.self, from: data)
    }

    func saveSession(_ session: MihoyoLoginSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    func clearSession() {
        defaults.removeObject(forKey: storageKey)
    }
}
