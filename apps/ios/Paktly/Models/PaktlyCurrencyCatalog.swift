import Foundation

enum PaktlyCurrencyCatalog {
    static let popular = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "NGN", "INR", "CNY", "CHF"]
    static let all = Locale.commonISOCurrencyCodes.sorted()

    private static let knownSymbols: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "¥", "INR": "₹",
        "NGN": "₦", "KRW": "₩", "RUB": "₽", "TRY": "₺", "BRL": "R$", "CAD": "C$",
        "AUD": "A$", "NZD": "NZ$", "CHF": "CHF", "SEK": "kr", "NOK": "kr", "DKK": "kr",
        "PLN": "zł", "CZK": "Kč", "HUF": "Ft", "ZAR": "R", "GHS": "₵", "KES": "KSh",
        "AED": "د.إ", "SAR": "﷼", "ILS": "₪", "THB": "฿", "PHP": "₱", "VND": "₫",
        "IDR": "Rp", "MYR": "RM", "SGD": "S$", "HKD": "HK$", "MXN": "MX$"
    ]

    private static let countriesByCurrency: [String: String] = {
        var values: [String: Set<String>] = [:]
        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)
            guard let currency = locale.currencyCode, let region = locale.regionCode,
                  let country = Locale.current.localizedString(forRegionCode: region) else { continue }
            values[currency, default: []].insert(country)
        }
        return values.mapValues { $0.sorted().joined(separator: " ") }
    }()

    static func name(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static func symbol(for code: String) -> String {
        knownSymbols[code] ?? code
    }

    static func matches(_ code: String, query: String) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return [code, name(for: code), symbol(for: code), countriesByCurrency[code] ?? ""]
            .map { normalized($0) }
            .contains { $0.contains(needle) }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }
}
