import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }
    @Published private(set) var groups: [APIGroup] = []
    @Published private(set) var notifications: [APINotification] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var youOweMinor = 0
    @Published private(set) var youAreOwedMinor = 0
    @Published private(set) var dashboardCurrency = "USD"
    @Published private(set) var currentUser: APIUser?
    let client: APIClient
    let offlineQueue: OfflineExpenseQueue

    init(client: APIClient = .shared, offlineQueue: OfflineExpenseQueue = OfflineExpenseQueue()) { self.client = client; self.offlineQueue = offlineQueue }

    func refresh() async {
        state = .loading
        _ = await offlineQueue.synchronize(using: client)
        do {
            async let groups = client.groups(); async let notifications = client.notifications(); async let user = client.me()
            self.groups = try await groups; self.notifications = try await notifications; currentUser = try await user
            if let first = self.groups.first, let balanceData = try? await client.balances(groupID: first.id) {
                dashboardCurrency = first.defaultCurrency
                let own = balanceData.0.first { $0.userId == currentUser?.id }?.netMinor ?? 0
                youOweMinor = max(0, -own); youAreOwedMinor = max(0, own)
            } else { youOweMinor = 0; youAreOwedMinor = 0 }
            pendingSyncCount = await offlineQueue.count(); state = .loaded
        } catch { state = .failed("We couldn’t refresh your shared plans.") }
    }

    func createPlan(name: String, description: String?, currency: String, memberEmails: [String] = []) async throws -> APIGroup {
        let group = try await client.createGroup(
            name: name,
            description: description,
            currency: currency
        )

        let normalizedEmails = memberEmails
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        for email in normalizedEmails {
            try? await client.invite(groupID: group.id, email: email)
        }

        await refresh()
        return group
    }

    func createGroup(name: String, description: String?, currency: String) async throws {
        _ = try await client.createGroup(name: name, description: description, currency: currency)
        await refresh()
    }

    func updateProfile(displayName: String, username: String?) async throws {
        try await client.updateProfile(displayName: displayName, username: username)
        currentUser = try await client.me()
    }

    func submitExpense(groupID: String, draft: ExpenseDraft) async -> Bool {
        do { try await client.addExpense(groupID: groupID, draft: draft) }
        catch is URLError { try? await offlineQueue.enqueue(groupID: groupID, draft: draft) }
        catch { state = .failed("The expense could not be saved. Check the split and try again."); return false }
        pendingSyncCount = await offlineQueue.count()
        return true
    }
}
