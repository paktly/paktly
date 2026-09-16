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
        try await queue.enqueue(groupID: UUID().uuidString.lowercased(), draft: draft, userID: "owner")
        let count = await queue.count(userID: "owner")
        XCTAssertEqual(count, 1)
        try await queue.clear()
        let clearedCount = await queue.count(userID: "owner")
        XCTAssertEqual(clearedCount, 0)
        let reopened = OfflineExpenseQueue(fileURL: fileURL)
        let persistedCount = await reopened.count(userID: "owner")
        XCTAssertEqual(persistedCount, 0, "Deleted account expenses must not reappear after restarting")
    }
    func testSynchronizationIsScopedToAccountAndPreservesNewEntries() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let queue = OfflineExpenseQueue(fileURL: fileURL)
        let draft = ExpenseDraft(clientOperationId: UUID().uuidString, description: "Dinner", category: "Food",
            amountMinor: 100, currency: "USD", paidBy: "owner", expenseDate: .now, notes: nil,
            split: .init(method: "EQUAL", participantIds: ["owner"], shares: nil, items: nil))
        try await queue.enqueue(groupID: "plan", draft: draft, userID: "owner")
        let other = await queue.synchronize(userID: "other") { _ in XCTFail("Must not upload another account's expense") }
        XCTAssertEqual(other, 0)
        let completed = await queue.synchronize(userID: "owner") { pending in
            XCTAssertEqual(pending.draft.clientOperationId, draft.clientOperationId)
            try await queue.enqueue(groupID: "new-plan", draft: draft, userID: "owner")
        }
        XCTAssertEqual(completed, 1)
        let remaining = await queue.count(userID: "owner")
        XCTAssertEqual(remaining, 1, "An enqueue during upload must not be overwritten")
        let cleared = await queue.synchronize(userID: "owner") { _ in try await queue.clear() }
        XCTAssertEqual(cleared, 0)
        let afterClear = await queue.count(userID: "owner")
        XCTAssertEqual(afterClear, 0)
    }

}
