import Foundation

actor OfflineExpenseQueue {
    struct Pending: Codable, Identifiable, Sendable { let id: UUID; let groupID: String; let draft: ExpenseDraft; var userID: String? = nil }
    private let fileURL: URL
    private var generation = 0
    private var synchronizing = false
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "pending-expenses.json")
    }
    func enqueue(groupID: String, draft: ExpenseDraft, userID: String) throws {
        var entries = load(); entries.append(Pending(id: UUID(), groupID: groupID, draft: draft, userID: userID)); try save(entries)
    }
    func synchronize(using client: APIClient, userID: String) async -> Int {
        await synchronize(userID: userID) { pending in
            try await client.addExpense(groupID: pending.groupID, draft: pending.draft)
        }
    }
    func synchronize(userID: String, send: @Sendable (Pending) async throws -> Void) async -> Int {
        guard !synchronizing else { return 0 }
        synchronizing = true
        defer { synchronizing = false }
        let startedGeneration = generation
        var completed = 0
        // Legacy entries with no known owner are retained but never replayed as another user.
        for pending in load().filter({ $0.userID == userID }) {
            guard generation == startedGeneration else { return completed }
            do {
                try await send(pending)
                guard generation == startedGeneration else { return completed }
                // Reload after awaiting: another expense may have been queued in the meantime.
                try save(load().filter { $0.id != pending.id })
                completed += 1
            } catch { continue }
        }
        return completed
    }
    func cancelSynchronization() { generation += 1 }
    func clear() throws { generation += 1; try save([]) }
    func count(userID: String) -> Int { load().filter { $0.userID == userID }.count }
    private func load() -> [Pending] { guard let data = try? Data(contentsOf: fileURL) else { return [] }; return (try? JSONDecoder().decode([Pending].self, from: data)) ?? [] }
    private func save(_ entries: [Pending]) throws { try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic) }
}
