import Foundation

public struct ClaudeOAuthUsageReader {
    private let tokenProvider: () throws -> String
    private let session: URLSession
    private let timeout: TimeInterval
    private let fileManager: FileManager
    private let cacheURL: URL
    private let planCacheURL: URL
    private let freshCacheAge: TimeInterval
    private let staleCacheAge: TimeInterval
    private let retryInterval: TimeInterval
    private let planCacheAge: TimeInterval

    public init(
        tokenProvider: @escaping () throws -> String = ClaudeOAuthUsageReader.loadClaudeCodeOAuthToken,
        session: URLSession = .shared,
        timeout: TimeInterval = 8,
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        fileManager: FileManager = .default,
        freshCacheAge: TimeInterval = 5 * 60,
        staleCacheAge: TimeInterval = 30 * 60,
        retryInterval: TimeInterval = 5 * 60,
        planCacheAge: TimeInterval = 24 * 60 * 60
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.timeout = timeout
        self.fileManager = fileManager
        self.cacheURL = claudeHome.appendingPathComponent("token-scope-oauth-usage.json")
        self.planCacheURL = claudeHome.appendingPathComponent("token-scope-oauth-plan.json")
        self.freshCacheAge = freshCacheAge
        self.staleCacheAge = staleCacheAge
        self.retryInterval = retryInterval
        self.planCacheAge = planCacheAge
    }

    public init(
        cacheURL: URL,
        tokenProvider: @escaping () throws -> String = ClaudeOAuthUsageReader.loadClaudeCodeOAuthToken,
        session: URLSession = .shared,
        timeout: TimeInterval = 8,
        fileManager: FileManager = .default,
        freshCacheAge: TimeInterval = 5 * 60,
        staleCacheAge: TimeInterval = 30 * 60,
        retryInterval: TimeInterval = 5 * 60,
        planCacheAge: TimeInterval = 24 * 60 * 60
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.timeout = timeout
        self.fileManager = fileManager
        self.cacheURL = cacheURL
        self.planCacheURL = cacheURL.deletingLastPathComponent().appendingPathComponent("token-scope-oauth-plan.json")
        self.freshCacheAge = freshCacheAge
        self.staleCacheAge = staleCacheAge
        self.retryInterval = retryInterval
        self.planCacheAge = planCacheAge
    }

    public func load(now: Date = Date()) -> ClaudeUsageLimits? {
        loadWithStatus(now: now).limits
    }

    public func loadWithStatus(now: Date = Date(), forceRefresh: Bool = false) -> ClaudeOAuthUsageLoadResult {
        if !forceRefresh, let cached = loadCached(now: now, maximumAge: freshCacheAge) {
            return ClaudeOAuthUsageLoadResult(limits: cached, statusMessage: nil)
        }

        if !forceRefresh, let failure = failureState(now: now) {
            let cached = loadCached(now: now, maximumAge: staleCacheAge)
            switch failure {
            case .manualRefreshOnly(let message):
                return ClaudeOAuthUsageLoadResult(limits: cached, statusMessage: message)
            case .retryAfter(let retryAt):
                return ClaudeOAuthUsageLoadResult(
                    limits: cached,
                    statusMessage: "Claude OAuth 조회 실패 · \(formatRetry(retryAt.timeIntervalSince(now))) 후 재시도"
                )
            }
        }

        let token: String
        do {
            token = try tokenProvider()
        } catch {
            saveFailure(message: "토큰 없음", now: now, retryAfter: nil)
            return ClaudeOAuthUsageLoadResult(
                limits: loadCached(now: now, maximumAge: staleCacheAge),
                statusMessage: "Claude OAuth 토큰 없음 · Claude Code 로그인 후 수동 새로고침"
            )
        }

        let usageResponse = requestJSON(url: "https://api.anthropic.com/api/oauth/usage", token: token)
        guard let usageJSON = usageResponse.json else {
            saveFailure(message: usageResponse.message, now: now, retryAfter: retryDelay(for: usageResponse))
            return ClaudeOAuthUsageLoadResult(
                limits: loadCached(now: now, maximumAge: staleCacheAge),
                statusMessage: failureStatusMessage(for: usageResponse, forceRefresh: forceRefresh)
            )
        }

        let planName = loadPlanCached(now: now) ?? fetchPlanName(token: token, now: now)
        saveCache(usageJSON: usageJSON, planName: planName, capturedAt: now)
        clearFailure()
        return ClaudeOAuthUsageLoadResult(limits: parseUsage(usageJSON, planName: planName), statusMessage: nil)
    }

    public func parseUsage(_ json: [String: Any], planName: String? = nil) -> ClaudeUsageLimits? {
        let fiveHour = parseWindow(json["five_hour"])
        let sevenDay = parseWindow(json["seven_day"])

        guard fiveHour != nil || sevenDay != nil else {
            return nil
        }

        return ClaudeUsageLimits(
            source: .oauthAPI,
            sourcePath: "https://api.anthropic.com/api/oauth/usage",
            planName: planName,
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: parseWindow(json["seven_day_sonnet"]),
            sevenDayOpus: parseWindow(json["seven_day_opus"]),
            extraUsage: parseExtraUsage(json["extra_usage"])
        )
    }

    public func parseUsage(_ text: String, planName: String? = nil) -> ClaudeUsageLimits? {
        guard let json = ClaudeUsageLimitParsing.jsonDictionary(from: text) else {
            return nil
        }

        return parseUsage(json, planName: planName)
    }

    public func parsePlanName(_ json: [String: Any]) -> String? {
        guard let memberships = json["memberships"] as? [[String: Any]] else {
            return nil
        }

        for membership in memberships {
            guard let organization = membership["organization"] as? [String: Any],
                  (organization["billing_type"] as? String) == "stripe_subscription",
                  let tier = organization["rate_limit_tier"] as? String
            else {
                continue
            }

            if tier.contains("max_20x") { return "Max 20x" }
            if tier.contains("max_5x") { return "Max 5x" }
            if tier.contains("max") { return "Max" }
            if tier.contains("team") { return "Team" }
            return "Pro"
        }

        return nil
    }

    public func parsePlanName(_ text: String) -> String? {
        guard let json = ClaudeUsageLimitParsing.jsonDictionary(from: text) else {
            return nil
        }

        return parsePlanName(json)
    }

    private func loadCached(now: Date, maximumAge: TimeInterval) -> ClaudeUsageLimits? {
        guard maximumAge > 0,
              fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data),
              let capturedAt = ClaudeUsageLimitParsing.date(json["captured_at"] as? String),
              now.timeIntervalSince(capturedAt) <= maximumAge,
              let usageJSON = json["usage"] as? [String: Any]
        else {
            return nil
        }

        return parseUsage(usageJSON, planName: (json["plan_name"] as? String) ?? loadPlanCached(now: now))
    }

    private func saveCache(usageJSON: [String: Any], planName: String?, capturedAt: Date) {
        var payload: [String: Any] = [
            "captured_at": cacheDateString(capturedAt),
            "usage": usageJSON
        ]
        if let planName = planName ?? existingPlanName() {
            payload["plan_name"] = planName
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else {
            return
        }

        try? fileManager.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: [.atomic])
    }

    private func cacheDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func loadPlanCached(now: Date) -> String? {
        guard fileManager.fileExists(atPath: planCacheURL.path),
              let data = try? Data(contentsOf: planCacheURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data),
              let capturedAt = ClaudeUsageLimitParsing.date(json["captured_at"] as? String),
              now.timeIntervalSince(capturedAt) <= planCacheAge
        else {
            return nil
        }

        return json["plan_name"] as? String
    }

    private func fetchPlanName(token: String, now: Date) -> String? {
        let accountResponse = requestJSON(url: "https://api.anthropic.com/api/oauth/account", token: token)
        guard let accountJSON = accountResponse.json,
              let planName = parsePlanName(accountJSON)
        else {
            return existingPlanName()
        }

        savePlanName(planName, capturedAt: now)
        return planName
    }

    private func savePlanName(_ planName: String, capturedAt: Date) {
        let payload: [String: Any] = [
            "captured_at": cacheDateString(capturedAt),
            "plan_name": planName
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        try? fileManager.createDirectory(at: planCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: planCacheURL, options: [.atomic])
    }

    private func existingPlanName() -> String? {
        if fileManager.fileExists(atPath: planCacheURL.path),
           let data = try? Data(contentsOf: planCacheURL),
           let json = ClaudeUsageLimitParsing.jsonDictionary(from: data),
           let planName = json["plan_name"] as? String {
            return planName
        }

        guard fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data)
        else {
            return nil
        }

        return json["plan_name"] as? String
    }

    private func failureState(now: Date) -> OAuthFailureState? {
        guard fileManager.fileExists(atPath: failureURL.path),
              let data = try? Data(contentsOf: failureURL),
              let json = ClaudeUsageLimitParsing.jsonDictionary(from: data),
              let failedAt = ClaudeUsageLimitParsing.date(json["failed_at"] as? String)
        else {
            return nil
        }

        if ClaudeUsageLimitParsing.bool(json["manual_refresh_only"]) == true {
            return .manualRefreshOnly((json["message"] as? String) ?? "Claude OAuth 재인증 필요 · Claude Code 로그인 후 수동 새로고침")
        }

        let retryAfter = ClaudeUsageLimitParsing.number(json["retry_after_seconds"]) ?? retryInterval
        let retryAt = failedAt.addingTimeInterval(retryAfter)
        return retryAt > now ? .retryAfter(retryAt) : nil
    }

    private func saveFailure(message: String, now: Date, retryAfter: TimeInterval?) {
        var payload: [String: Any] = [
            "failed_at": cacheDateString(now),
            "message": message
        ]
        if let retryAfter {
            payload["retry_after_seconds"] = retryAfter
        } else {
            payload["manual_refresh_only"] = true
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? fileManager.createDirectory(at: failureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: failureURL, options: [.atomic])
    }

    private func clearFailure() {
        try? fileManager.removeItem(at: failureURL)
    }

    private var failureURL: URL {
        cacheURL.deletingLastPathComponent().appendingPathComponent("token-scope-oauth-failure.json")
    }

    private func formatRetry(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return "\(total / 60)분 \(total % 60)초"
    }

    private func retryDelay(for result: OAuthHTTPResult) -> TimeInterval? {
        switch result.kind {
        case .unauthorized, .forbidden, .clientError:
            return nil
        case .rateLimited:
            return result.retryAfter ?? retryInterval
        case .serverError, .transport, .invalidResponse, .parseError, .timeout:
            return retryInterval
        case .success:
            return nil
        }
    }

    private func failureStatusMessage(for result: OAuthHTTPResult, forceRefresh: Bool) -> String {
        switch result.kind {
        case .unauthorized, .forbidden:
            return "Claude OAuth 재인증 필요 · Claude Code 로그인 후 수동 새로고침"
        case .clientError:
            return "Claude OAuth \(result.message) · 수동 확인 필요"
        default:
            let retryDelay = retryDelay(for: result) ?? retryInterval
            return forceRefresh
                ? "Claude OAuth 수동 조회 실패: \(result.message) · 자동 재시도 \(formatRetry(retryDelay)) 후"
                : "Claude OAuth \(result.message) · \(formatRetry(retryDelay)) 후 재시도"
        }
    }

    private func requestJSON(url: String, token: String) -> OAuthHTTPResult {
        guard let url = URL(string: url) else {
            return OAuthHTTPResult(json: nil, kind: .invalidResponse, message: "URL 오류")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let result = OAuthHTTPResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result.value = OAuthHTTPResult(json: nil, kind: .transport, message: networkErrorMessage(error))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                result.value = OAuthHTTPResult(json: nil, kind: .invalidResponse, message: "응답 오류")
                return
            }

            guard http.statusCode == 200 else {
                result.value = OAuthHTTPResult(
                    json: nil,
                    kind: OAuthHTTPResult.Kind(statusCode: http.statusCode),
                    message: "HTTP \(http.statusCode)",
                    retryAfter: retryAfter(from: http)
                )
                return
            }

            guard let data, let json = ClaudeUsageLimitParsing.jsonDictionary(from: data) else {
                result.value = OAuthHTTPResult(json: nil, kind: .parseError, message: "파싱 오류")
                return
            }

            result.value = OAuthHTTPResult(json: json, kind: .success, message: "성공")
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return result.value
    }

    private func parseWindow(_ value: Any?) -> ClaudeUsageLimits.Window? {
        guard let dictionary = value as? [String: Any],
              let utilization = ClaudeUsageLimitParsing.number(dictionary["utilization"])
        else {
            return nil
        }

        return ClaudeUsageLimits.Window(
            usedPercent: utilization,
            resetsAt: ClaudeUsageLimitParsing.date(dictionary["resets_at"] as? String)
        )
    }

    private func parseExtraUsage(_ value: Any?) -> ClaudeUsageLimits.ExtraUsage? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        return ClaudeUsageLimits.ExtraUsage(
            isEnabled: ClaudeUsageLimitParsing.bool(dictionary["is_enabled"]) ?? false,
            monthlyLimit: ClaudeUsageLimitParsing.number(dictionary["monthly_limit"]),
            usedCredits: ClaudeUsageLimitParsing.number(dictionary["used_credits"]),
            utilization: ClaudeUsageLimitParsing.number(dictionary["utilization"])
        )
    }

    public static func loadClaudeCodeOAuthToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ClaudeOAuthUsageError.tokenNotFound
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let json = ClaudeUsageLimitParsing.jsonDictionary(from: data),
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty
        else {
            throw ClaudeOAuthUsageError.tokenNotFound
        }

        return token
    }
}

public struct ClaudeOAuthUsageLoadResult: Sendable {
    public let limits: ClaudeUsageLimits?
    public let statusMessage: String?

    public init(limits: ClaudeUsageLimits?, statusMessage: String?) {
        self.limits = limits
        self.statusMessage = statusMessage
    }
}

private struct OAuthHTTPResult {
    enum Kind {
        case success
        case unauthorized
        case forbidden
        case rateLimited
        case clientError
        case serverError
        case transport
        case invalidResponse
        case parseError
        case timeout

        init(statusCode: Int) {
            switch statusCode {
            case 401:
                self = .unauthorized
            case 403:
                self = .forbidden
            case 429:
                self = .rateLimited
            case 400..<500:
                self = .clientError
            case 500..<600:
                self = .serverError
            default:
                self = .invalidResponse
            }
        }
    }

    let json: [String: Any]?
    let kind: Kind
    let message: String
    let retryAfter: TimeInterval?

    init(json: [String: Any]?, kind: Kind, message: String, retryAfter: TimeInterval? = nil) {
        self.json = json
        self.kind = kind
        self.message = message
        self.retryAfter = retryAfter
    }
}

private final class OAuthHTTPResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = OAuthHTTPResult(json: nil, kind: .timeout, message: "시간 초과")

    var value: OAuthHTTPResult {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

private enum OAuthFailureState {
    case retryAfter(Date)
    case manualRefreshOnly(String)
}

private func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
    let value = response.value(forHTTPHeaderField: "Retry-After")
        ?? response.allHeaderFields.first { key, _ in
            String(describing: key).caseInsensitiveCompare("Retry-After") == .orderedSame
        }.map { String(describing: $0.value) }

    guard let value else {
        return nil
    }

    if let seconds = TimeInterval(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
        return seconds
    }

    if let date = HTTPDateFormatter.shared.date(from: value) {
        return max(0, date.timeIntervalSinceNow)
    }

    return nil
}

private func networkErrorMessage(_ error: Error) -> String {
    let nsError = error as NSError
    guard nsError.domain == NSURLErrorDomain else {
        return "네트워크 오류 (\(nsError.code))"
    }

    switch nsError.code {
    case NSURLErrorNotConnectedToInternet:
        return "네트워크 오류 (\(nsError.code) offline)"
    case NSURLErrorTimedOut:
        return "네트워크 오류 (\(nsError.code) timeout)"
    case NSURLErrorSecureConnectionFailed,
         NSURLErrorServerCertificateHasBadDate,
         NSURLErrorServerCertificateUntrusted,
         NSURLErrorServerCertificateHasUnknownRoot,
         NSURLErrorServerCertificateNotYetValid,
         NSURLErrorClientCertificateRejected,
         NSURLErrorClientCertificateRequired:
        return "네트워크 오류 (\(nsError.code) TLS)"
    case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
        return "네트워크 오류 (\(nsError.code) host)"
    case NSURLErrorCancelled:
        return "네트워크 오류 (\(nsError.code) cancelled)"
    default:
        return "네트워크 오류 (\(nsError.code))"
    }
}

private final class HTTPDateFormatter: @unchecked Sendable {
    static let shared = HTTPDateFormatter()
    private let lock = NSLock()
    private let formatter: DateFormatter

    private init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    }

    func date(from value: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return formatter.date(from: value)
    }
}

public enum ClaudeOAuthUsageError: LocalizedError, Equatable {
    case tokenNotFound

    public var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "Claude Code OAuth token was not found in Keychain."
        }
    }
}
