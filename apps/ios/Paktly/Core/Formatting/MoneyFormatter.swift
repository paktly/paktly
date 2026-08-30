import Foundation

enum MoneyFormatter {
    static func string(
        minorUnits: Int64,
        currencyCode: String = "USD",
        locale: Locale = .current
    ) -> String {
        let amount = Decimal(minorUnits) / 100
        return amount.formatted(
            .currency(code: currencyCode)
                .locale(locale)
                .precision(.fractionLength(0...2))
        )
    }
}
