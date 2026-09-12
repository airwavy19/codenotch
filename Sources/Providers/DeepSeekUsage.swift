import Foundation

/// The response shape of DeepSeek's documented API-credit balance endpoint.
/// It can contain multiple currencies, but the notch intentionally reports
/// only USD: mixing currencies into one headline would make a false total.
enum DeepSeekUsage {
    static func usdBalance(in data: Data) throws -> Decimal? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["balance_infos"] as? [[String: Any]]
        else { throw UsageProviderError.badResponse(status: 200) }

        for row in rows {
            guard (row["currency"] as? String)?.uppercased() == "USD" else { continue }
            guard let raw = row["total_balance"] as? String,
                  let amount = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
            else { throw UsageProviderError.badResponse(status: 200) }
            return amount
        }
        return nil
    }

    static func formattedUSD(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        // `en_US_POSIX` is right for parsing wire values, but its currency
        // formatter inserts a non-breaking space after `$`. The notch needs a
        // compact, predictable headline, so use the normal US display locale.
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}
