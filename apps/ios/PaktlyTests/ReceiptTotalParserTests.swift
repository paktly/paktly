import XCTest
@testable import Paktly

final class ReceiptTotalParserTests: XCTestCase {
    func testFindsTotalOnSameLineInsteadOfLargerSubtotal() {
        XCTAssertEqual(ReceiptTotalParser.total(from: [
            "SUBTOTAL $120.00", "DISCOUNT $30.00", "TAX $7.20", "TOTAL $97.20"
        ]), "97.2")
    }

    func testFindsAmountOnLineAfterTotalLabel() {
        XCTAssertEqual(ReceiptTotalParser.total(from: [
            "Burger House", "Subtotal 18.00", "Tax 1.44", "AMOUNT DUE", "$19.44", "Visa ending 9444"
        ]), "19.44")
    }

    func testFindsAmountTwoLinesAfterTotalLabel() {
        XCTAssertEqual(ReceiptTotalParser.total(from: [
            "GRAND TOTAL", "USD", "1,234.56", "AUTH 849302"
        ]), "1234.56")
    }

    func testUnderstandsEuropeanDecimalFormatting() {
        XCTAssertEqual(ReceiptTotalParser.total(from: [
            "SUBTOTAL 40,00 EUR", "VAT 8,00 EUR", "TOTAL 48,00 EUR"
        ]), "48")
    }

    func testFallbackRejectsCardAndOrderNumbers() {
        XCTAssertEqual(ReceiptTotalParser.total(from: [
            "Corner Cafe", "Order 48291", "Coffee $4.50", "VISA 1234", "$4.86"
        ]), "4.86")
    }
}
