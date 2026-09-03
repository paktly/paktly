import Foundation
import Combine
import UserNotifications

struct PlanInvitationFailure: Error {
    let failedIdentifiers: [String]
}

struct PresentedInvitation: Identifiable, Equatable {
    let invitation: APIInvitation
    var id: String { invitation.id }
}
struct PresentedPlan: Identifiable, Equatable { let id: String }

@MainActor
final class AppModel: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }
    @Published private(set) var groups: [APIGroup] = []
    @Published private(set) var notifications: [APINotification] = []
    @Published private(set) var unreadNotificationCount = 0
    @Published private(set) var invitations: [APIInvitation] = []
    @Published private(set) var presentedInvitation: PresentedInvitation?
    @Published private(set) var invitationError: String?
    @Published private(set) var presentedPlan: PresentedPlan?
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
            async let groupsRequest = client.groups()
            async let userRequest = client.me()
            let loadedGroups = try await groupsRequest
            let loadedUser = try await userRequest
            self.groups = loadedGroups
            currentUser = loadedUser

            // Notifications and invitations enhance the dashboard, but neither
            // should prevent owned or joined plans from loading.
            if let loadedNotifications = try? await client.notifications() {
                notifications = loadedNotifications.0
                unreadNotificationCount = loadedNotifications.1
                try? await UNUserNotificationCenter.current().setBadgeCount(loadedNotifications.1)
            }
            if let loadedInvitations = try? await client.pendingInvitations() {
                invitations = loadedInvitations
            }
            if let pendingPush = PendingPushStore.load() {
                await routeRemoteNotification(pendingPush)
                PendingPushStore.clear()
            }
            if let invitationToken = PendingInvitationStore.load() {
                do {
                    let invitation = try await client.resolveInvitation(token: invitationToken)
                    presentedInvitation = PresentedInvitation(invitation: invitation)
                    invitationError = nil
                } catch {
                    PendingInvitationStore.clear()
                    invitationError = "This invitation is unavailable or belongs to a different email address."
                }
            }
            if let first = self.groups.first, let balanceData = try? await client.balances(groupID: first.id) {
                dashboardCurrency = first.defaultCurrency
                let own = balanceData.0.first { $0.userId == currentUser?.id }?.netMinor ?? 0
                youOweMinor = max(0, -own); youAreOwedMinor = max(0, own)
            } else { youOweMinor = 0; youAreOwedMinor = 0 }
            pendingSyncCount = await offlineQueue.count(); state = .loaded
        } catch { state = .failed("We couldn’t refresh your shared plans.") }
    }

    func handleIncomingURL(_ url: URL) {
        let isWebInvitation = ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host == "paktly.io" && url.path == "/invite"
        let isAppInvitation = url.scheme?.lowercased() == "paktly" && url.host == "invite"
        guard isWebInvitation || isAppInvitation,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              token.count >= 20 else { return }
        PendingInvitationStore.save(token)
        if KeychainTokenStore.load() != nil {
            Task { await refresh() }
        }
    }

    func handleRemoteNotification(_ payload: [String: String]) {
        guard KeychainTokenStore.load() != nil else {
            PendingPushStore.save(payload)
            return
        }
        Task {
            await routeRemoteNotification(payload)
        }
    }

    func dismissPresentedPlan() { presentedPlan = nil }

    private func routeRemoteNotification(_ payload: [String: String]) async {
        if let notificationId = payload["notificationId"] { try? await client.markNotificationRead(id: notificationId) }
        if let loadedInvitations = try? await client.pendingInvitations() { invitations = loadedInvitations }
        if let invitationId = payload["entityId"], payload["entityType"] == "INVITATION",
           let invitation = invitations.first(where: { $0.id == invitationId }) {
            presentInvitation(invitation)
        } else if let groupId = payload["groupId"] {
            presentedPlan = PresentedPlan(id: groupId)
        }
        if let loadedNotifications = try? await client.notifications() {
            notifications = loadedNotifications.0
            unreadNotificationCount = loadedNotifications.1
            try? await UNUserNotificationCenter.current().setBadgeCount(loadedNotifications.1)
        }
    }

    func presentInvitation(_ invitation: APIInvitation) {
        invitationError = nil
        presentedInvitation = PresentedInvitation(invitation: invitation)
    }

    func dismissInvitation() {
        presentedInvitation = nil
        PendingInvitationStore.clear()
    }

    func acceptPresentedInvitation() async throws {
        guard let invitation = presentedInvitation?.invitation else { return }
        try await client.acceptInvitation(id: invitation.id)
        presentedInvitation = nil
        PendingInvitationStore.clear()
        await refresh()
    }

    func declinePresentedInvitation() async throws {
        guard let invitation = presentedInvitation?.invitation else { return }
        try await client.declineInvitation(id: invitation.id)
        presentedInvitation = nil
        PendingInvitationStore.clear()
        await refresh()
    }

    func createPlan(name: String, description: String?, currency: String, memberIdentifiers: [String] = []) async throws -> APIGroup {
        let group = try await client.createGroup(
            name: name,
            description: description,
            currency: currency
        )

        let normalizedIdentifiers = memberIdentifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        var failedIdentifiers: [String] = []
        for identifier in normalizedIdentifiers {
            do {
                try await client.invite(groupID: group.id, identifier: identifier)
            } catch {
                failedIdentifiers.append(identifier)
            }
        }

        await refresh()
        if !failedIdentifiers.isEmpty {
            throw PlanInvitationFailure(failedIdentifiers: failedIdentifiers)
        }
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

private enum PendingInvitationStore {
    private static let key = "io.paktly.pending-invitation"

    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
    }

    static func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

private enum PendingPushStore {
    private static let key = "io.paktly.pending-push"
    static func save(_ payload: [String: String]) { UserDefaults.standard.set(payload, forKey: key) }
    static func load() -> [String: String]? { UserDefaults.standard.dictionary(forKey: key) as? [String: String] }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
