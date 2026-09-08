import XCTest
@testable import Paktly

final class EmailCompletionTests: XCTestCase {
    func testDomainSuggestionsRequireEmailLocalPart() {
        XCTAssertEqual(EmailCompletion.suggestions(for: "shola@"), EmailCompletion.domains.map { "shola@\($0)" })
        XCTAssertEqual(EmailCompletion.suggestions(for: "shola@G"), ["shola@gmail.com"])
        for value in ["shola", "@shola", "a@@g", "a b@g", "shola@company.com", "shola@gmail.com"] {
            XCTAssertTrue(EmailCompletion.suggestions(for: value).isEmpty, value)
        }
    }
}
