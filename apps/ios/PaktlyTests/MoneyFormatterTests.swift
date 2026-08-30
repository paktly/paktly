import XCTest
@testable import Paktly

final class MoneyFormatterTests: XCTestCase {
    func testFormatsIntegerMinorUnitsWithoutFloatingPoint() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(
            MoneyFormatter.string(minorUnits: 12_345, locale: locale),
            "$123.45"
        )
    }
}
