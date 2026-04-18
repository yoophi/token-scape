import Foundation

public struct ClaudeOAuthUsageReader {
    private let tokenProvider: () throws -> String
    private let session: URLSession
    private let timeout: TimeInterval

    public init(
        tokenProvider: @escaping () throws -> String = ClaudeOAuthUsageReader.loadClaudeCodeOAuthToken,
        session: URLSession = .shared,
        timeout: TimeInterval = 8
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.timeout = timeout
    }

    public func load() -> ClaudeUsageLimits? {
        guard let token = try? tokenProvider(),
              let usageJSON = requestJSON(url: "https://api.anthropic.com/api/oauth/usage", token: token)
        else {
            return nil
        }

        let accountJSON = requestJSON(url: "https://api.anthropic.com/api/oauth/account", token: token)
        return parseUsage(usageJSON, planName: accountJSON.flatMap(parsePlanName))
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

    private func requestJSON(url: String, token: String) -> [String: Any]? {
        guard let url = URL(string: url) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let result = JSONResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data,
                  let json = ClaudeUsageLimitParsing.jsonDictionary(from: data)
            else {
                return
            }

            result.value = json
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

private final class JSONResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: [String: Any]?

    var value: [String: Any]? {
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

public enum ClaudeOAuthUsageError: LocalizedError, Equatable {
    case tokenNotFound

    public var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "Claude Code OAuth token was not found in Keychain."
        }
    }
}
