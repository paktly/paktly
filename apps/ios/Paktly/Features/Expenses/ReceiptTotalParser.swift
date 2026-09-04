import Foundation

/// Selects the amount actually charged from OCR lines. Receipt totals are often
/// separated from their labels, so choosing the largest number is not reliable.
enum ReceiptTotalParser {
    private struct Candidate {
        let amount: Decimal
        let text: String
        let score: Int
        let lineIndex: Int
    }

    private static let strongLabels = [
        "grand total", "amount due", "balance due", "total due", "amount paid",
        "total paid", "card total", "payment total", "الإجمالي", "الإجمالى",
        "المبلغ المطلوب", "المجموع", "الصافي"
    ]
    private static let excludedLabels = [
        "subtotal", "sub total", "sub-total", "tax", "vat", "tip", "gratuity",
        "discount", "savings", "change", "cash tendered", "tendered", "الضريبة",
        "الفرعي", "الباقي"
    ]
    private static let invalidNumberContexts = [
        "phone", "tel", "invoice", "order", "transaction", "auth", "approval",
        "reference", "receipt #", "check #", "table", "server", "cashier",
        "visa", "mastercard", "amex", "account", "card ending", "card no"
    ]
    private static let currencyMarkers = [
        "$", "€", "£", "¥", "₦", "₹", "د.إ", "د.ك", "ر.س", "USD", "EUR",
        "GBP", "CAD", "AUD", "NZD", "KWD", "AED", "SAR", "QAR", "BHD",
        "OMR", "JPY", "CNY", "NGN", "INR"
    ]

    static func total(from rawLines: [String]) -> String? {
        let lines = rawLines.map(normalizeNumerals)
        var labelled: [Candidate] = []

        for (index, line) in lines.enumerated() {
            guard let labelScore = totalLabelScore(for: line) else { continue }
            for nearbyIndex in nearbyIndices(around: index, count: lines.count) {
                let distance = abs(nearbyIndex - index)
                let proximityScore = distance == 0 ? 50 : 34 - (distance * 9)
                for amount in monetaryValues(in: lines[nearbyIndex], allowWholeNumbers: true) {
                    labelled.append(Candidate(
                        amount: amount.value,
                        text: amount.text,
                        score: labelScore + proximityScore + amount.confidence,
                        lineIndex: nearbyIndex
                    ))
                }
            }
        }

        if let best = labelled.max(by: candidateOrdering) { return best.text }

        // If no total label survived OCR, prefer currency-bearing decimal values
        // near the bottom of the receipt and reject IDs, dates, and card numbers.
        let denominator = max(lines.count - 1, 1)
        let fallback = lines.enumerated().flatMap { index, line -> [Candidate] in
            let lower = line.lowercased()
            guard !invalidNumberContexts.contains(where: lower.contains), !looksLikeDateOrTime(line) else { return [] }
            let hasCurrency = currencyMarkers.contains { line.localizedCaseInsensitiveContains($0) }
            return monetaryValues(in: line, allowWholeNumbers: hasCurrency).map { amount in
                Candidate(
                    amount: amount.value,
                    text: amount.text,
                    score: amount.confidence + (hasCurrency ? 35 : 0) + (index * 20 / denominator),
                    lineIndex: index
                )
            }
        }
        return fallback.max(by: candidateOrdering)?.text
    }

    private static func totalLabelScore(for line: String) -> Int? {
        let lower = line.lowercased()
        guard !excludedLabels.contains(where: lower.contains) else { return nil }
        if strongLabels.contains(where: lower.contains) { return 140 }
        if lower.range(of: #"\btotal\b"#, options: .regularExpression) != nil { return 110 }
        return nil
    }

    private static func nearbyIndices(around index: Int, count: Int) -> [Int] {
        // Vision may put the label and value into separate observations. Search
        // the label row first, followed by the next two rows and previous row.
        [index, index + 1, index + 2, index - 1].filter { $0 >= 0 && $0 < count }
    }

    private static func candidateOrdering(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        if lhs.lineIndex != rhs.lineIndex { return lhs.lineIndex < rhs.lineIndex }
        return lhs.amount < rhs.amount
    }

    private struct ParsedAmount {
        let value: Decimal
        let text: String
        let confidence: Int
    }

    private static func monetaryValues(in line: String, allowWholeNumbers: Bool) -> [ParsedAmount] {
        line.matches(of: /(?:\d{1,3}(?:[,. ]\d{3})+|\d+)(?:[.,]\d{1,3})?/)
            .map { String($0.output).replacingOccurrences(of: " ", with: "") }
            .filter { $0.count <= 14 }
            .compactMap { raw in
                let normalized = normalizedAmount(raw)
                guard let value = Decimal(string: normalized), value > 0, value < 1_000_000_000 else { return nil }
                let hasMinorUnits = normalized.contains(".")
                guard allowWholeNumbers || hasMinorUnits else { return nil }
                return ParsedAmount(value: value, text: NSDecimalNumber(decimal: value).stringValue, confidence: hasMinorUnits ? 16 : 0)
            }
    }

    private static func normalizedAmount(_ raw: String) -> String {
        let commaCount = raw.filter { $0 == "," }.count
        let periodCount = raw.filter { $0 == "." }.count
        if commaCount > 0, periodCount > 0 {
            if raw.lastIndex(of: ",")! > raw.lastIndex(of: ".")! {
                return raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
            return raw.replacingOccurrences(of: ",", with: "")
        }
        if commaCount > 0 {
            let trailing = raw.split(separator: ",", omittingEmptySubsequences: false).last?.count ?? 0
            return trailing == 3 ? raw.replacingOccurrences(of: ",", with: "") : raw.replacingOccurrences(of: ",", with: ".")
        }
        if periodCount > 1 { return raw.replacingOccurrences(of: ".", with: "") }
        return raw
    }

    private static func looksLikeDateOrTime(_ line: String) -> Bool {
        line.range(of: #"\b\d{1,2}[:/]\d{1,2}(?:[:/]\d{2,4})?\b"#, options: .regularExpression) != nil
    }

    private static func normalizeNumerals(_ value: String) -> String {
        let digits: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4", "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
            "٫": ".", "٬": ","
        ]
        return String(value.map { digits[$0] ?? $0 })
    }
}
