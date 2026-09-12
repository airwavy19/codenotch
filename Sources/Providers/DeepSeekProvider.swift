import Foundation
import os

/// Reads the current USD API credit balance directly from DeepSeek. This is a
/// balance, not a rate-window quota, so it deliberately renders as a number
/// with an empty ring rather than inventing a percentage or a reset date.
actor DeepSeekProvider: UsageProvider {
    nonisolated let id = "deepseek"
    nonisolated let displayName = "DeepSeek"
    nonisolated let glyph = ProviderGlyph.third

    private let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated var signInRoute: SignInRoute {
        .guidance("Set DEEPSEEK_API_KEY or sign in to DeepSeek through Pi; Codenotch reads the current USD API balance.")
    }

    nonisolated func account() -> ProviderAccount? {
        guard let credential = DeepSeekCredentials.load() else { return nil }
        return ProviderAccount(label: nil, plan: "API balance", source: credential.source,
                               manageURL: URL(string: "https://platform.deepseek.com/usage"))
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        guard let credential = DeepSeekCredentials.load() else {
            throw UsageProviderError.needsAuth
        }

        var request = URLRequest(url: balanceURL)
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw UsageProviderError.needsAuth }
        if status == 429 { throw UsageProviderError.rateLimited(retryAfter: 60) }
        guard (200..<300).contains(status) else {
            throw UsageProviderError.badResponse(status: status)
        }

        guard let balance = try DeepSeekUsage.usdBalance(in: data) else {
            throw UsageProviderError.nothingMetered("DeepSeek reported no USD API balance.")
        }
        let formatted = DeepSeekUsage.formattedUSD(balance)
        Log.usage.debug("deepseek: read current USD balance")
        return ProviderSnapshot(
            id: id, displayName: displayName, glyph: glyph, fidelity: .official,
            status: .ok,
            windows: [LimitWindow(id: "usd", label: "Current USD balance",
                                  displayText: formatted)],
            headlineID: "usd"
        )
    }
}
