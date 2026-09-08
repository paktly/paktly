import Foundation

actor OfflineExpenseQueue {
    struct Pending: Codable, Identifiable, Sendable { let id: UUID; let groupID: String; let draft: ExpenseDraft }
    private let fileURL: URL
    private var generation = 0
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "pending-expenses.json")
    }
    func enqueue(groupID: String, draft: ExpenseDraft) throws {
        var entries = load(); entries.append(Pending(id: UUID(), groupID: groupID, draft: draft)); try save(entries)
    }
    func synchronize(using client: APIClient) async -> Int {
        let startedGeneration = generation
        var remaining: [Pending] = []; var completed = 0
        for pending in load() {
            guard generation == startedGeneration else { return completed }
            do { try await client.addExpense(groupID: pending.groupID, draft: pending.draft); completed += 1 }
            catch { remaining.append(pending) }
        }
        guard generation == startedGeneration else { return completed }
        try? save(remaining); return completed
    }
    func clear() throws { generation += 1; try save([]) }
    func count() -> Int { load().count }
    private func load() -> [Pending] { guard let data = try? Data(contentsOf: fileURL) else { return [] }; return (try? JSONDecoder().decode([Pending].self, from: data)) ?? [] }
    private func save(_ entries: [Pending]) throws { try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic) }
}
