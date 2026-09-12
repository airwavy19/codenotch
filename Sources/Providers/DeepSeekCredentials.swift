import Foundation

/// Locates a DeepSeek API key without ever copying it into preferences or an
/// archive. Pi is checked because its provider login is the existing DeepSeek
/// setup on this Mac; an explicitly exported key wins for people using the
/// official SDK directly.
enum DeepSeekCredentials {
    struct Credential: Equatable {
        let token: String
        let source: String
    }

    static var piAuthURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pi/agent/auth.json")
    }

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment,
                     piAuthURL: URL = Self.piAuthURL) -> Credential? {
        if let token = clean(environment["DEEPSEEK_API_KEY"]) {
            return Credential(token: token, source: "DEEPSEEK_API_KEY")
        }
        guard let data = try? Data(contentsOf: piAuthURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deepseek = root["deepseek"] as? [String: Any]
        else { return nil }

        for field in ["key", "apiKey", "api_key", "token"] {
            if let token = clean(deepseek[field] as? String) {
                return Credential(token: token, source: "Pi")
            }
        }
        return nil
    }

    private static func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
