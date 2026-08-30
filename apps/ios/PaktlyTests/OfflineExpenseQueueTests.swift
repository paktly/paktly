import XCTest
@testable import Paktly

final class OfflineExpenseQueueTests: XCTestCase {
    func testExpensePersistsForLaterSynchronization() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let queue = OfflineExpenseQueue(fileURL: fileURL)
        let draft = ExpenseDraft(
            clientOperationId: UUID().uuidString.lowercased(), description: "Offline dinner", category: "Food",
            amountMinor: 12000, currency: "USD", paidBy: UUID().uuidString.lowercased(), expenseDate: .now,
            notes: nil, split: .init(method: "EQUAL", participantIds: [UUID().uuidString.lowercased()], shares: nil, items: nil)
        )
        try await queue.enqueue(groupID: UUID().uuidString.lowercased(), draft: draft)
        let count = await queue.count()
        XCTAssertEqual(count, 1)
    }
}
