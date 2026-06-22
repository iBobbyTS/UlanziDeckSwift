import CryptoKit
import Foundation

// MARK: - 游戏与状态模型

nonisolated enum MihoyoGame: String, Codable, Equatable, CaseIterable, Sendable {
    case genshin
    case starRail
    case zenlessZoneZero

    var displayName: String {
        switch self {
        case .genshin:
            return "原神"
        case .starRail:
            return "崩坏：星穹铁道"
        case .zenlessZoneZero:
            return "绝区零"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .genshin:
            return "原神"
        case .starRail:
            return "星铁"
        case .zenlessZoneZero:
            return "绝区零"
        }
    }

    var roleGameBiz: String {
        switch self {
        case .genshin:
            return "hk4e_cn"
        case .starRail:
            return "hkrpg_cn"
        case .zenlessZoneZero:
            return "nap_cn"
        }
    }

    var staminaShortName: String {
        switch self {
        case .genshin:
            return "树脂"
        case .starRail:
            return "开拓力"
        case .zenlessZoneZero:
            return "电量"
        }
    }

    var dailyShortName: String {
        switch self {
        case .genshin:
            return "每日委托"
        case .starRail:
            return "每日实训"
        case .zenlessZoneZero:
            return "每日活跃度"
        }
    }

    var buttonBackgroundAssetName: String {
        switch self {
        case .genshin:
            return "MihoyoGenshinBackground"
        case .starRail:
            return "MihoyoStarRailBackground"
        case .zenlessZoneZero:
            return "MihoyoZenlessZoneZeroBackground"
        }
    }
}

nonisolated struct MihoyoBoundRole: Equatable, Sendable {
    let game: MihoyoGame
    let gameBiz: String
    let gameUID: String
    let region: String
    let nickname: String
    let level: Int?

    var displayName: String {
        if nickname.isEmpty {
            return "UID \(gameUID)"
        }

        return "\(nickname)（\(gameUID)）"
    }
}

nonisolated enum MihoyoGameStatusSource: String, Equatable, Sendable {
    case record
    case widget

    var displayName: String {
        switch self {
        case .record:
            return "实时便笺"
        case .widget:
            return "小组件"
        }
    }
}

nonisolated struct MihoyoDailyStatus: Equatable, Sendable {
    let game: MihoyoGame
    let role: MihoyoBoundRole
    let staminaName: String
    let currentStamina: Int?
    let maxStamina: Int?
    let staminaRecoverSeconds: Int?
    let dailyName: String
    let dailyCurrent: Int?
    let dailyMax: Int?
    let dailyDone: Bool?
    let source: MihoyoGameStatusSource

    var staminaMayBeCappedBySource: Bool {
        source == .widget
    }

    var staminaValueText: String {
        Self.valueText(current: currentStamina, maximum: maxStamina)
    }

    var dailyValueText: String {
        Self.valueText(current: dailyCurrent, maximum: dailyMax)
    }

    var staminaColor: MihoyoGameMetricColor {
        Self.staminaColor(current: currentStamina, maximum: maxStamina)
    }

    var dailyColor: MihoyoGameMetricColor {
        Self.dailyColor(game: game, current: dailyCurrent, maximum: dailyMax)
    }

    var buttonTitle: String {
        "\(game.staminaShortName) \(staminaValueText)"
    }

    var buttonSubtitle: String {
        "\(game.dailyShortName) \(dailyValueText)"
    }

    var buttonContent: MihoyoGameButtonContent {
        MihoyoGameButtonContent(
            game: game,
            staminaLabel: game.staminaShortName,
            staminaValue: staminaValueText,
            staminaColor: staminaColor,
            dailyLabel: game.dailyShortName,
            dailyValue: dailyValueText,
            dailyColor: dailyColor
        )
    }

    var recoverDescription: String {
        if let currentStamina, let maxStamina, currentStamina >= maxStamina {
            return "已满或超上限"
        }

        guard let staminaRecoverSeconds, staminaRecoverSeconds > 0 else {
            return "未知"
        }

        return Self.durationText(seconds: staminaRecoverSeconds)
    }

    private static func valueText(current: Int?, maximum: Int?) -> String {
        switch (current, maximum) {
        case let (.some(current), .some(maximum)):
            return "\(current)/\(maximum)"
        case let (.some(current), .none):
            return "\(current)"
        case let (.none, .some(maximum)):
            return "--/\(maximum)"
        case (.none, .none):
            return "--"
        }
    }

    private static func staminaColor(current: Int?, maximum: Int?) -> MihoyoGameMetricColor {
        guard let current, let maximum, maximum > 0 else {
            return .yellow
        }

        if current >= maximum {
            return .red
        }

        if current * 5 < maximum * 4 {
            return .green
        }

        return .yellow
    }

    private static func dailyColor(game: MihoyoGame, current: Int?, maximum: Int?) -> MihoyoGameMetricColor {
        guard let current else {
            return .yellow
        }

        if let maximum, maximum > 0, current >= maximum {
            return .green
        }

        switch game {
        case .genshin, .starRail:
            if current == 0 {
                return .red
            }
        case .zenlessZoneZero:
            if current == 100 {
                return .red
            }
        }

        return .yellow
    }

    private static func durationText(seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return "\(days)天\(hours)小时"
        }

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }

        return "\(max(1, minutes))分钟"
    }
}

nonisolated enum MihoyoGameMetricColor: Equatable, Sendable {
    case green
    case yellow
    case red
}

nonisolated struct MihoyoGameButtonContent: Equatable, Sendable {
    let game: MihoyoGame
    let staminaLabel: String
    let staminaValue: String
    let staminaColor: MihoyoGameMetricColor
    let dailyLabel: String
    let dailyValue: String
    let dailyColor: MihoyoGameMetricColor

    init(
        game: MihoyoGame,
        staminaLabel: String,
        staminaValue: String,
        staminaColor: MihoyoGameMetricColor = .yellow,
        dailyLabel: String,
        dailyValue: String,
        dailyColor: MihoyoGameMetricColor = .yellow
    ) {
        self.game = game
        self.staminaLabel = staminaLabel
        self.staminaValue = staminaValue
        self.staminaColor = staminaColor
        self.dailyLabel = dailyLabel
        self.dailyValue = dailyValue
        self.dailyColor = dailyColor
    }
}

nonisolated enum MihoyoGameStatusResult: Equatable, Sendable {
    case success(MihoyoDailyStatus)
    case loginRequired
    case loginExpired(String)
    case noBoundRole(MihoyoGame)
    case networkError(String)
}

// MARK: - 服务协议

nonisolated protocol MihoyoGameServicing: Sendable {
    func createQRCodeLogin() async throws -> MihoyoQRLoginSession
    func queryQRCodeLogin(_ session: MihoyoQRLoginSession) async throws -> MihoyoQRCodeStatusResult
    func fetchDailyStatus(game: MihoyoGame, session: MihoyoLoginSession) async -> MihoyoGameStatusResult
}

// MARK: - 网络实现

nonisolated struct MihoyoGameClient: MihoyoGameServicing {
    private static let mysVersion = "2.102.1"
    private static let hypVersion = "1.3.3.182"
    private static let passportAppID = "ddxf5dufpuyo"

    private static let passportBaseURL = URL(string: "https://passport-api.mihoyo.com")!
    private static let recordBaseURL = URL(string: "https://api-takumi-record.mihoyo.com")!
    private static let oldTakumiBaseURL = URL(string: "https://api-takumi.mihoyo.com")!
    private static let fpURL = URL(string: "https://public-data-api.mihoyo.com/device-fp/api/getFp")!

    private let urlSession: URLSession
    private let timeoutSeconds: TimeInterval

    init(urlSession: URLSession = .shared, timeoutSeconds: TimeInterval = 10) {
        self.urlSession = urlSession
        self.timeoutSeconds = timeoutSeconds
    }

    func createQRCodeLogin() async throws -> MihoyoQRLoginSession {
        let deviceID = MihoyoCrypto.randomHex(32) + MihoyoCrypto.randomHex(32)
        let payload = try await requestAPIPayload(
            method: "POST",
            url: Self.passportBaseURL.appending(path: "/account/ma-cn-passport/app/createQRLogin"),
            headers: qrLoginHeaders(deviceID: deviceID),
            jsonBody: [:]
        )
        let data = try apiData(payload)
        let ticket = MihoyoJSON.string(data["ticket"])
        let url = MihoyoJSON.string(data["url"])
        guard !ticket.isEmpty, !url.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "二维码响应缺少 ticket 或 url")
        }

        return MihoyoQRLoginSession(ticket: ticket, url: url, deviceID: deviceID)
    }

    func queryQRCodeLogin(_ session: MihoyoQRLoginSession) async throws -> MihoyoQRCodeStatusResult {
        let payload = try await requestAPIPayload(
            method: "POST",
            url: Self.passportBaseURL.appending(path: "/account/ma-cn-passport/app/queryQRLoginStatus"),
            headers: qrLoginHeaders(deviceID: session.deviceID),
            jsonBody: ["ticket": session.ticket]
        )
        let data = try apiData(payload)
        let status = MihoyoJSON.string(data["status"])

        switch status {
        case "Created":
            return .waitingForScan
        case "Scanned":
            return .scanned
        case "Confirmed":
            return .confirmed(try await loginSession(fromConfirmedData: data))
        case "Expired":
            return .expired("二维码已过期")
        case "Cancelled", "Canceled":
            return .failed("扫码登录已取消")
        default:
            return .failed(status.isEmpty ? "未知扫码状态" : "未知扫码状态：\(status)")
        }
    }

    func fetchDailyStatus(game: MihoyoGame, session: MihoyoLoginSession) async -> MihoyoGameStatusResult {
        let role: MihoyoBoundRole
        do {
            role = try await findRole(game: game, session: session)
        } catch let error as MihoyoRoleLookupError {
            return .noBoundRole(error.game)
        } catch let error as MihoyoAPIError {
            if error.isAuthFailure {
                return .loginExpired(error.userMessage)
            }

            return .networkError(error.userMessage)
        } catch {
            return .networkError(error.localizedDescription)
        }

        do {
            let payload = try await notePayload(role: role, session: session)
            let data = payload["data"] as? [String: Any] ?? [:]
            return .success(MihoyoGameStatusMapper.dailyStatus(for: role, data: data, source: .record))
        } catch let recordError as MihoyoAPIError {
            do {
                let payload = try await widgetPayload(role: role, session: session)
                let data = payload["data"] as? [String: Any] ?? [:]
                return .success(MihoyoGameStatusMapper.dailyStatus(for: role, data: data, source: .widget))
            } catch let widgetError as MihoyoAPIError {
                if recordError.isAuthFailure || widgetError.isAuthFailure {
                    return .loginExpired(widgetError.userMessage)
                }

                return .networkError(widgetError.userMessage)
            } catch {
                return .networkError(error.localizedDescription)
            }
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    private func findRole(game: MihoyoGame, session: MihoyoLoginSession) async throws -> MihoyoBoundRole {
        let roles = try await boundRoles(session: session)
        guard let role = roles.first(where: { $0.game == game }) else {
            throw MihoyoRoleLookupError(game: game)
        }

        return role
    }

    private func boundRoles(session: MihoyoLoginSession) async throws -> [MihoyoBoundRole] {
        let queryItems = [URLQueryItem(name: "game_biz", value: "")]
        let query = "game_biz="
        let headers = commonHeaders(session: session, query: query)
        let payload: [String: Any]

        do {
            payload = try await requestAPIPayload(
                method: "GET",
                url: Self.oldTakumiBaseURL.appending(path: "/binding/api/getUserGameRolesByCookie"),
                queryItems: queryItems,
                headers: headers
            )
        } catch {
            payload = try await requestAPIPayload(
                method: "GET",
                url: Self.passportBaseURL.appending(path: "/binding/api/getUserGameRolesByCookieToken"),
                queryItems: queryItems,
                headers: headers
            )
        }

        let data = payload["data"] as? [String: Any] ?? [:]
        let items = data["list"] as? [[String: Any]] ?? []
        return items.compactMap { item in
            let gameBiz = MihoyoJSON.string(item["game_biz"])
            guard let game = MihoyoGame.allCases.first(where: { $0.roleGameBiz == gameBiz }) else {
                return nil
            }

            let gameUID = MihoyoJSON.firstString(item, keys: ["game_uid", "game_role_id"])
            let region = MihoyoJSON.firstString(item, keys: ["region", "server", "region_name"])
            guard !gameUID.isEmpty, !region.isEmpty else {
                return nil
            }

            return MihoyoBoundRole(
                game: game,
                gameBiz: gameBiz,
                gameUID: gameUID,
                region: region,
                nickname: MihoyoJSON.string(item["nickname"]),
                level: MihoyoJSON.int(item["level"])
            )
        }
    }

    private func notePayload(role: MihoyoBoundRole, session: MihoyoLoginSession) async throws -> [String: Any] {
        let url: URL
        switch role.game {
        case .genshin:
            url = Self.recordBaseURL.appending(path: "/game_record/app/genshin/api/dailyNote")
        case .starRail:
            url = Self.recordBaseURL.appending(path: "/game_record/app/hkrpg/api/note")
        case .zenlessZoneZero:
            url = Self.recordBaseURL.appending(path: "/event/game_record_zzz/api/zzz/note")
        }

        let queryItems = [
            URLQueryItem(name: "role_id", value: role.gameUID),
            URLQueryItem(name: "server", value: role.region),
        ]
        let query = "role_id=\(role.gameUID)&server=\(role.region)"
        let headers = role.game == .zenlessZoneZero
            ? zzzHeaders(session: session, query: query)
            : commonHeaders(session: session, query: query)

        return try await requestAPIPayload(method: "GET", url: url, queryItems: queryItems, headers: headers)
    }

    private func widgetPayload(role: MihoyoBoundRole, session: MihoyoLoginSession) async throws -> [String: Any] {
        switch role.game {
        case .genshin:
            var headers = commonHeaders(session: session)
            headers["DS"] = MihoyoCrypto.dsToken()
            headers["x-rpc-channel"] = "miyousheluodi"
            return try await requestAPIPayload(
                method: "GET",
                url: Self.recordBaseURL.appending(path: "/game_record/genshin/aapi/widget/v2"),
                queryItems: [URLQueryItem(name: "game_id", value: "2")],
                headers: headers
            )
        case .starRail:
            var headers = commonHeaders(session: session)
            headers["DS"] = MihoyoCrypto.dsToken()
            headers["x-rpc-channel"] = "beta"
            headers["Referer"] = "https://app.mihoyo.com"
            headers["User-Agent"] = "okhttp/4.8.0"
            return try await requestAPIPayload(
                method: "GET",
                url: Self.recordBaseURL.appending(path: "/game_record/app/hkrpg/aapi/widget"),
                headers: headers
            )
        case .zenlessZoneZero:
            var headers = commonHeaders(session: session)
            headers["DS"] = MihoyoCrypto.dsToken()
            headers["x-rpc-page"] = "v1.0.14_#/zzz"
            headers["x-rpc-platform"] = "2"
            return try await requestAPIPayload(
                method: "GET",
                url: Self.recordBaseURL.appending(path: "/event/game_record_zzz/api/zzz/widget"),
                headers: headers
            )
        }
    }

    private func loginSession(fromConfirmedData data: [String: Any]) async throws -> MihoyoLoginSession {
        let userInfo = data["user_info"] as? [String: Any] ?? [:]
        let accountID = MihoyoJSON.firstString(userInfo, keys: ["aid", "uid", "account_id"])
        let mid = MihoyoJSON.string(userInfo["mid"])
        guard !accountID.isEmpty, !mid.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "扫码响应缺少账号信息")
        }

        let tokens = data["tokens"] as? [[String: Any]] ?? []
        let stoken = tokens.compactMap { token -> String? in
            let name = MihoyoJSON.string(token["name"])
            let tokenValue = MihoyoJSON.string(token["token"])
            if ["stoken_v2", "stoken"].contains(name), !tokenValue.isEmpty {
                return tokenValue
            }

            if MihoyoJSON.int(token["token_type"]) == 1, !tokenValue.isEmpty {
                return tokenValue
            }

            return nil
        }.first ?? ""
        guard !stoken.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "扫码响应缺少 stoken")
        }

        let cookieToken = try await cookieTokenBySToken(stoken, accountID: accountID, mid: mid)
        let ltoken = try? await ltokenBySToken(stoken, accountID: accountID, mid: mid)
        let deviceID = MihoyoCrypto.randomDeviceID()
        let deviceFP = (try? await generateDeviceFP(deviceID: deviceID)) ?? MihoyoCrypto.randomHex(13)

        return MihoyoLoginSession(
            accountID: accountID,
            stokenV2: stoken,
            mid: mid,
            cookieToken: cookieToken,
            ltoken: ltoken,
            deviceID: deviceID,
            deviceFP: deviceFP
        )
    }

    private func cookieTokenBySToken(_ stoken: String, accountID: String, mid: String) async throws -> String {
        let headers = passportWebHeaders(stoken: stoken, accountID: accountID, mid: mid)
        let payload = try await requestAPIPayload(
            method: "GET",
            url: Self.passportBaseURL.appending(path: "/account/auth/api/getCookieAccountInfoBySToken"),
            queryItems: [
                URLQueryItem(name: "stoken", value: stoken),
                URLQueryItem(name: "uid", value: accountID),
                URLQueryItem(name: "mid", value: mid),
            ],
            headers: headers
        )
        let data = try apiData(payload)
        let cookieToken = MihoyoJSON.string(data["cookie_token"])
        guard !cookieToken.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "响应缺少 cookie_token")
        }

        return cookieToken
    }

    private func ltokenBySToken(_ stoken: String, accountID: String, mid: String) async throws -> String {
        let payload = try await requestAPIPayload(
            method: "GET",
            url: Self.passportBaseURL.appending(path: "/account/auth/api/getLTokenBySToken"),
            headers: passportWebHeaders(stoken: stoken, accountID: accountID, mid: mid)
        )
        let data = try apiData(payload)
        let ltoken = MihoyoJSON.string(data["ltoken"])
        guard !ltoken.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "响应缺少 ltoken")
        }

        return ltoken
    }

    private func generateDeviceFP(deviceID: String) async throws -> String {
        let seedID = MihoyoCrypto.randomHex(16)
        let body: [String: Any] = [
            "device_id": MihoyoCrypto.randomHex(16),
            "seed_id": seedID,
            "platform": "1",
            "seed_time": "\(Int(Date().timeIntervalSince1970 * 1000))",
            "ext_fields": """
            {"proxyStatus":"0","accelerometer":"-0.159515x-0.830887x-0.682495","ramCapacity":"3746","IDFV":"\(deviceID.uppercased())","gyroscope":"-0.191951x-0.112927x0.632637","isJailBreak":"0","model":"iPhone12,5","ramRemain":"115","chargeStatus":"1","networkType":"WIFI","vendor":"--","osVersion":"17.0.2","batteryStatus":"50","screenSize":"414x896","cpuCores":"6","appMemory":"55","romCapacity":"488153","romRemain":"157348","cpuType":"CPU_TYPE_ARM64","magnetometer":"-84.426331x-89.708435x-37.117889"}
            """,
            "app_name": "bbs_cn",
            "device_fp": MihoyoCrypto.randomHex(13),
        ]
        let headers: [String: String] = [
            "x-rpc-app_version": Self.mysVersion,
            "x-rpc-client_type": "5",
            "User-Agent": mobileUserAgent(appVersion: Self.mysVersion),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
        ]
        let payload = try await requestAPIPayload(method: "POST", url: Self.fpURL, headers: headers, jsonBody: body)
        let data = try apiData(payload)
        guard MihoyoJSON.int(data["code"]) == 200 else {
            throw MihoyoAPIError(retcode: MihoyoJSON.int(data["code"]), message: MihoyoJSON.string(data["msg"]))
        }

        let deviceFP = MihoyoJSON.string(data["device_fp"])
        guard !deviceFP.isEmpty else {
            throw MihoyoAPIError(retcode: nil, message: "响应缺少 device_fp")
        }

        return deviceFP
    }

    private func qrLoginHeaders(deviceID: String) -> [String: String] {
        [
            "x-rpc-device_id": deviceID,
            "User-Agent": "HYPContainer/\(Self.hypVersion)",
            "x-rpc-app_id": Self.passportAppID,
            "x-rpc-client_type": "3",
        ]
    }

    private func commonHeaders(
        session: MihoyoLoginSession,
        query: String = "",
        page: String? = nil
    ) -> [String: String] {
        var headers: [String: String] = [
            "x-rpc-app_version": Self.mysVersion,
            "X-Requested-With": "com.mihoyo.hyperion",
            "User-Agent": mobileUserAgent(appVersion: Self.mysVersion),
            "x-rpc-client_type": "5",
            "x-rpc-device_id": session.deviceID,
            "x-rpc-device_fp": session.deviceFP,
            "x-rpc-device_name": "OPPO PHK110",
            "x-rpc-device_model": "PHK110",
            "x-rpc-platform": "2",
            "x-rpc-sys_version": "13",
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
            "DS": MihoyoCrypto.dsToken(query: query),
            "Cookie": session.cookieHeader,
        ]

        if let page {
            headers["x-rpc-page"] = page
        }

        return headers
    }

    private func zzzHeaders(session: MihoyoLoginSession, query: String = "") -> [String: String] {
        let appVersion = "2.40.1"
        return [
            "Cookie": session.cookieHeader,
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 12; Mi 10 Build/SKQ1.221119.001; wv) "
                    + "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/111.0.5563.116 "
                    + "Mobile Safari/537.36 miHoYoBBS/\(appVersion)"
            ),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com",
            "x-rpc-app_version": appVersion,
            "x-rpc-client_type": "5",
            "x-rpc-device_id": session.deviceID,
            "x-rpc-device_fp": session.deviceFP,
            "DS": MihoyoCrypto.dsToken(query: query),
        ]
    }

    private func passportWebHeaders(stoken: String, accountID: String, mid: String) -> [String: String] {
        [
            "x-rpc-app_version": Self.mysVersion,
            "X-Requested-With": "com.mihoyo.hyperion",
            "User-Agent": mobileUserAgent(appVersion: Self.mysVersion),
            "x-rpc-client_type": "5",
            "x-rpc-device_id": MihoyoCrypto.randomHex(32),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
            "Cookie": "stuid=\(accountID);stoken=\(stoken);mid=\(mid)",
        ]
    }

    private func mobileUserAgent(appVersion: String) -> String {
        (
            "Mozilla/5.0 (Linux; Android 13; PHK110 Build/SKQ1.221119.001; wv) "
                + "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.133 "
                + "Mobile Safari/537.36 miHoYoBBS/\(appVersion)"
        )
    }

    private func requestAPIPayload(
        method: String,
        url: URL,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        jsonBody: [String: Any]? = nil
    ) async throws -> [String: Any] {
        let payload = try await requestJSON(
            method: method,
            url: url,
            queryItems: queryItems,
            headers: headers,
            jsonBody: jsonBody
        )
        let retcode = MihoyoJSON.int(payload["retcode"]) ?? -1
        guard retcode == 0 else {
            throw MihoyoAPIError(retcode: retcode, message: MihoyoJSON.string(payload["message"]))
        }

        return payload
    }

    private func apiData(_ payload: [String: Any]) throws -> [String: Any] {
        guard let data = payload["data"] as? [String: Any] else {
            throw MihoyoAPIError(retcode: MihoyoJSON.int(payload["retcode"]), message: "响应缺少 data")
        }

        return data
    }

    private func requestJSON(
        method: String,
        url: URL,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String],
        jsonBody: [String: Any]? = nil
    ) async throws -> [String: Any] {
        var requestURL = url
        if let queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let composedURL = components?.url {
                requestURL = composedURL
            }
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.timeoutInterval = timeoutSeconds
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if let jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, _) = try await urlSession.data(for: request)
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MihoyoAPIError(retcode: nil, message: "响应不是 JSON 对象")
        }

        return payload
    }
}

// MARK: - 字段映射

nonisolated enum MihoyoGameStatusMapper {
    static func dailyStatus(
        for role: MihoyoBoundRole,
        data: [String: Any],
        source: MihoyoGameStatusSource
    ) -> MihoyoDailyStatus {
        switch role.game {
        case .genshin:
            let finished = MihoyoJSON.int(data["finished_task_num"])
            let total = MihoyoJSON.int(data["total_task_num"]) ?? 4
            let claimed = data["is_extra_task_reward_received"] as? Bool
            let dailyDone = claimed ?? finished.map { $0 == total }
            return MihoyoDailyStatus(
                game: role.game,
                role: role,
                staminaName: "树脂",
                currentStamina: MihoyoJSON.int(data["current_resin"]),
                maxStamina: MihoyoJSON.int(data["max_resin"]),
                staminaRecoverSeconds: MihoyoJSON.int(data["resin_recovery_time"]),
                dailyName: "每日委托",
                dailyCurrent: finished,
                dailyMax: total,
                dailyDone: dailyDone,
                source: source
            )
        case .starRail:
            let current = MihoyoJSON.int(data["current_train_score"])
            let maximum = MihoyoJSON.int(data["max_train_score"])
            return MihoyoDailyStatus(
                game: role.game,
                role: role,
                staminaName: "开拓力",
                currentStamina: MihoyoJSON.int(data["current_stamina"]),
                maxStamina: MihoyoJSON.int(data["max_stamina"]),
                staminaRecoverSeconds: MihoyoJSON.int(data["stamina_recover_time"]),
                dailyName: "每日实训",
                dailyCurrent: current,
                dailyMax: maximum,
                dailyDone: current.flatMap { current in maximum.map { current == $0 } },
                source: source
            )
        case .zenlessZoneZero:
            let energy = data["energy"] as? [String: Any] ?? [:]
            let progress = energy["progress"] as? [String: Any] ?? [:]
            let vitality = data["vitality"] as? [String: Any] ?? [:]
            let dailyCurrent = MihoyoJSON.int(vitality["current"])
            let dailyMax = MihoyoJSON.int(vitality["max"])
            return MihoyoDailyStatus(
                game: role.game,
                role: role,
                staminaName: "电量",
                currentStamina: MihoyoJSON.int(progress["current"]),
                maxStamina: MihoyoJSON.int(progress["max"]),
                staminaRecoverSeconds: MihoyoJSON.int(energy["restore"]),
                dailyName: "活跃度",
                dailyCurrent: dailyCurrent,
                dailyMax: dailyMax,
                dailyDone: dailyCurrent.flatMap { current in dailyMax.map { current == $0 } },
                source: source
            )
        }
    }
}

// MARK: - 辅助类型

nonisolated private struct MihoyoAPIError: Error, Equatable, LocalizedError {
    let retcode: Int?
    let message: String

    var errorDescription: String? {
        userMessage
    }

    var userMessage: String {
        message.isEmpty ? "请求失败" : message
    }

    var isAuthFailure: Bool {
        if let retcode, [-100, -101, 10001, 10103].contains(retcode) {
            return true
        }

        let lowercasedMessage = message.lowercased()
        return ["cookie", "stoken", "login", "auth", "登录", "失效", "过期"].contains {
            lowercasedMessage.contains($0.lowercased())
        }
    }
}

nonisolated private struct MihoyoRoleLookupError: Error, Equatable {
    let game: MihoyoGame
}

nonisolated private enum MihoyoCrypto {
    private static let dsSalt = "xV8v4Qu54lUKrEYFZkJhB8cuOh9Asafs"

    static func randomDeviceID() -> String {
        UUID().uuidString.lowercased()
    }

    static func randomHex(_ length: Int) -> String {
        let alphabet = Array("0123456789abcdef")
        return String((0..<length).map { _ in alphabet.randomElement() ?? "0" })
    }

    static func dsToken(query: String = "", body: [String: Any]? = nil) -> String {
        let t = "\(Int(Date().timeIntervalSince1970))"
        let r = "\(Int.random(in: 100_000...200_000))"
        let b = jsonBody(body)
        let sign = md5("salt=\(dsSalt)&t=\(t)&r=\(r)&b=\(b)&q=\(query)")
        return "\(t),\(r),\(sign)"
    }

    private static func md5(_ text: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func jsonBody(_ body: [String: Any]?) -> String {
        guard let body, let data = try? JSONSerialization.data(withJSONObject: body) else {
            return ""
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

nonisolated enum MihoyoJSON {
    static func string(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let value?:
            return "\(value)"
        case nil:
            return ""
        }
    }

    static func firstString(_ dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            let value = string(dictionary[key])
            if !value.isEmpty {
                return value
            }
        }

        return ""
    }

    static func int(_ value: Any?) -> Int? {
        guard let value else {
            return nil
        }

        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else {
                return nil
            }

            return number.intValue
        }

        if let int = value as? Int {
            return int
        }

        if let string = value as? String {
            return Int(string)
        }

        return nil
    }
}
