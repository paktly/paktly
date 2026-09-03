import Foundation
import Security

struct APISmartAccount: Codable, Sendable {
    let provider: String
    let network: String
    let address: String
}

struct APIUser: Codable, Identifiable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let username: String?
    let smartAccount: APISmartAccount?
}
struct APIGroup: Codable, Identifiable, Sendable { let id: String; let name: String; let description: String?; let defaultCurrency: String; let role: String?; let memberCount: Int? }
struct APIGroupMember: Codable, Identifiable, Sendable { let id: String; let email: String; let displayName: String; let avatarUrl: String?; let role: String }
struct APIExpense: Codable, Identifiable, Sendable {
    let id: String; let currentVersion: Int; let description: String; let category: String
    let originalAmountMinor: Int; let originalCurrency: String; let convertedAmountMinor: Int
    let groupCurrency: String; let paidBy: String; let expenseDate: Date; let notes: String?; let splitMethod: String; let payerName: String?
}
struct APIBalance: Codable, Identifiable, Sendable { let userId: String; let displayName: String; let netMinor: Int; var id: String { userId } }
struct APISuggestedSettlement: Codable, Identifiable, Sendable { let fromUserId: String; let toUserId: String; let amountMinor: Int; var id: String { fromUserId + ":\(toUserId):\(amountMinor)" } }
struct APIActivity: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let entityType: String?
    let entityId: String?
    let summary: String
    let createdAt: Date
}
struct APINotification: Codable, Identifiable, Sendable {
    let id: String
    let groupId: String?
    let type: String
    let title: String
    let body: String
    let entityType: String?
    let entityId: String?
    let category: String?
    let readAt: Date?
    let createdAt: Date
}
struct APIInvitation: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let groupId: String
    let email: String
    let status: String
    let expiresAt: Date
    let createdAt: Date
    let groupName: String
    let inviterName: String
}

struct APIAssistantDraft: Codable, Sendable {
    let intent: String
    let summary: String
    let needsClarification: Bool
    let clarification: String?
    let planId: String?
    let description: String?
    let amountMinor: Int?
    let currency: String?
    let payerId: String?
    let participantIds: [String]
    let planName: String?
    let planDescription: String?
    let inviteIdentifier: String?
}
struct APIJoinLinkPreview: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let groupId: String
    let groupName: String
    let creatorName: String
    let memberCount: Int
    let expiresAt: Date
}
struct APIJoinLink: Codable, Identifiable, Sendable {
    let id: String
    let groupId: String
    let groupName: String
    let url: URL
    let code: String
    let maxUses: Int
    let useCount: Int
    let expiresAt: Date
    let createdAt: Date
}

struct ExpenseDraft: Codable, Sendable {
    struct Weighted: Codable, Sendable { let userId: String; let value: Int }
    struct Item: Codable, Sendable { let amountMinor: Int; let participantIds: [String] }
    struct Split: Codable, Sendable {
        let method: String; let participantIds: [String]?; let shares: [Weighted]?; let items: [Item]?
    }
    struct ExchangeRate: Codable, Sendable { let numerator: Int; let denominator: Int; let provider: String; let timestamp: Date }
    let clientOperationId: String; let description: String; let category: String; let amountMinor: Int
    let currency: String; let paidBy: String; let expenseDate: Date; let notes: String?; let split: Split; let exchangeRate: ExchangeRate?

    init(clientOperationId: String, description: String, category: String, amountMinor: Int, currency: String, paidBy: String, expenseDate: Date, notes: String?, split: Split, exchangeRate: ExchangeRate? = nil) {
        self.clientOperationId = clientOperationId; self.description = description; self.category = category; self.amountMinor = amountMinor
        self.currency = currency; self.paidBy = paidBy; self.expenseDate = expenseDate; self.notes = notes; self.split = split; self.exchangeRate = exchangeRate
    }
}

private struct DevelopmentSessionRequest: Encodable {
    let email: String
    let displayName: String
}

private struct DevelopmentSessionResponse: Decodable {
    let accessToken: String
    let user: APIUser
}

private struct SocketFiSessionRequest: Encodable {
    let accessToken: String
    let displayName: String?
}

private struct SocketFiSessionResponse: Decodable {
    let accessToken: String
    let user: APIUser
}

private struct EmailOTPRequest: Encodable { let email: String }
private struct EmailOTPChallengeResponse: Decodable { let challengeId: String }
private struct EmailOTPVerifyRequest: Encodable { let challengeId: String; let email: String; let code: String }
private struct EmailOTPSessionResponse: Decodable {
    let accessToken: String
    let isNewUser: Bool
    let user: APIUser
}
private struct AppleAuthenticationRequest: Encodable {
    let identityToken: String
    let nonce: String
    let displayName: String?
}
private struct GoogleAuthenticationRequest: Encodable { let identityToken: String }
private struct LinkSmartWalletRequest: Encodable { let accessToken: String }
private struct LinkSmartWalletResponse: Decodable { let wallet: String?; let network: String }
private struct UsernameAvailabilityRequest: Encodable { let username: String }
struct UsernameAvailabilityResponse: Decodable, Sendable {
    let username: String
    let available: Bool
    let reason: String?
}

private struct ProfilePayload: Decodable {
    let id: String
    let email: String
    let displayName: String
    let username: String?
    let smartAccount: APISmartAccount?
}

private struct ProfileResponse: Decodable {
    let profile: ProfilePayload
}

private struct UpdateProfileRequest: Encodable {
    let displayName: String
    let username: String?
}

private struct UpdatedProfilePayload: Decodable {
    let displayName: String
}

private struct UpdatedProfileResponse: Decodable {
    let profile: UpdatedProfilePayload
}

private struct GroupsResponse: Decodable {
    let groups: [APIGroup]
}

private struct GroupResponse: Decodable {
    let group: APIGroup
}

private struct GroupDetailResponse: Decodable {
    let group: APIGroup
    let members: [APIGroupMember]
}

private struct CreateGroupRequest: Encodable {
    let name: String
    let description: String?
    let defaultCurrency: String
}

private struct ExpensesResponse: Decodable {
    let expenses: [APIExpense]
}

private struct ExpenseIdentifier: Decodable {
    let id: String
}

private struct ExpenseResponse: Decodable {
    let expense: ExpenseIdentifier
}

private struct UpdateExpenseRequest: Encodable {
    let expectedVersion: Int
    let description: String
    let category: String
    let amountMinor: Int
    let currency: String
    let paidBy: String
    let expenseDate: Date
    let notes: String?
    let split: ExpenseDraft.Split
    let exchangeRate: ExpenseDraft.ExchangeRate?
}

private struct BalancesResponse: Decodable {
    let balances: [APIBalance]
    let suggestedSettlements: [APISuggestedSettlement]
}

private struct ActivityResponse: Decodable {
    let events: [APIActivity]
}

private struct NotificationsResponse: Decodable {
    let notifications: [APINotification]
    let unreadCount: Int
}

private struct NotificationResponse: Decodable {
    let notification: APINotification
}

private struct EmptyRequest: Encodable {}
private struct EmptyResponse: Decodable {}
private struct UpdatedCountResponse: Decodable { let updated: Int }

private struct PushDeviceRegistrationRequest: Encodable {
    let installationId: String
    let token: String
    let environment: String
    let locale: String
    let timezone: String
    let appVersion: String?
    let deviceModel: String?
}

struct APINotificationPreferences: Codable, Sendable {
    var invitations: Bool
    var expenses: Bool
    var settlements: Bool
    var contributions: Bool
    var planReminders: Bool
    var marketing: Bool
    var soundEnabled: Bool
    var badgesEnabled: Bool
    var lockScreenDetail: String
}

private struct NotificationPreferencesResponse: Decodable { let preferences: APINotificationPreferences }

private struct InvitationRequest: Encodable { let identifier: String }

private struct InvitationPayload: Decodable {
    let id: String
    let token: String?
}

private struct InvitationResponse: Decodable {
    let invitation: InvitationPayload
}
private struct AssistantInterpretRequest: Encodable {
    let prompt: String
    let contextPlanId: String?
}
private struct AssistantInterpretResponse: Decodable { let draft: APIAssistantDraft }
private struct AssistantTranscriptionResponse: Decodable { let transcript: String }

private struct PendingInvitationsResponse: Decodable {
    let invitations: [APIInvitation]
}

private struct InvitationDetailResponse: Decodable {
    let invitation: APIInvitation
}
private struct CreateJoinLinkRequest: Encodable { let expiresInDays: Int; let maxUses: Int }
private struct JoinLinkCredentialRequest: Encodable { let token: String?; let code: String? }
private struct JoinLinkResponse: Decodable { let joinLink: APIJoinLink }
private struct JoinLinkPreviewResponse: Decodable { let joinLink: APIJoinLinkPreview }
private struct JoinLinkAcceptanceResponse: Decodable { let groupId: String; let status: String }

private struct InvitationStatusPayload: Decodable { let id: String; let status: String }
private struct InvitationStatusResponse: Decodable { let invitation: InvitationStatusPayload }

private struct AcceptInvitationRequest: Encodable {
    let token: String
}

private struct AcceptInvitationResponse: Decodable {
    let groupId: String
}

private struct SettlementRequest: Encodable {
    let fromUserId: String
    let toUserId: String
    let amountMinor: Int
    let method = "MARKED_PAID"
    let note: String? = nil
    let clientOperationId = UUID().uuidString.lowercased()
}

private struct SettlementIdentifier: Decodable {
    let id: String
}

private struct SettlementResponse: Decodable {
    let settlement: SettlementIdentifier
}

actor APIClient {
    static let shared: APIClient = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "PaktlyAPIBaseURL") as? String,
            !value.isEmpty,
            let url = URL(string: value)
        else {
            fatalError("PaktlyAPIBaseURL must be configured for this build.")
        }
        return APIClient(baseURL: url)
    }()

    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 timestamp, received \(value)."
            )
        }
        self.decoder = decoder
    }

    func developmentSignIn(email: String, displayName: String) async throws -> APIUser {
        let body = DevelopmentSessionRequest(email: email, displayName: displayName)
        let response = try await send(
            DevelopmentSessionResponse.self,
            path: "auth/dev-session",
            method: "POST",
            body: body,
            authenticated: false
        )
        try KeychainTokenStore.save(response.accessToken)
        return response.user
    }

    func socketFiSignIn(accessToken: String, displayName: String?) async throws -> APIUser {
        let response = try await send(
            SocketFiSessionResponse.self,
            path: "auth/socketfi",
            method: "POST",
            body: SocketFiSessionRequest(accessToken: accessToken, displayName: displayName),
            authenticated: false
        )
        try KeychainTokenStore.save(response.accessToken)
        return response.user
    }

    func requestEmailOTP(email: String) async throws -> String {
        let response = try await send(
            EmailOTPChallengeResponse.self,
            path: "auth/email/request",
            method: "POST",
            body: EmailOTPRequest(email: email),
            authenticated: false
        )
        return response.challengeId
    }

    func verifyEmailOTP(challengeId: String, email: String, code: String) async throws -> (APIUser, Bool) {
        let response = try await send(
            EmailOTPSessionResponse.self,
            path: "auth/email/verify",
            method: "POST",
            body: EmailOTPVerifyRequest(challengeId: challengeId, email: email, code: code),
            authenticated: false
        )
        try KeychainTokenStore.save(response.accessToken)
        return (response.user, response.isNewUser)
    }

    func authenticateWithApple(identityToken: String, nonce: String, displayName: String?) async throws -> (APIUser, Bool) {
        let response = try await send(
            EmailOTPSessionResponse.self,
            path: "auth/apple",
            method: "POST",
            body: AppleAuthenticationRequest(identityToken: identityToken, nonce: nonce, displayName: displayName),
            authenticated: false
        )
        try KeychainTokenStore.save(response.accessToken)
        return (response.user, response.isNewUser)
    }

    func authenticateWithGoogle(identityToken: String) async throws -> (APIUser, Bool) {
        let response = try await send(
            EmailOTPSessionResponse.self,
            path: "auth/google",
            method: "POST",
            body: GoogleAuthenticationRequest(identityToken: identityToken),
            authenticated: false
        )
        try KeychainTokenStore.save(response.accessToken)
        return (response.user, response.isNewUser)
    }

    func linkSmartWallet(socketFiAccessToken: String) async throws {
        _ = try await send(
            LinkSmartWalletResponse.self,
            path: "me/smart-wallet/socketfi",
            method: "POST",
            body: LinkSmartWalletRequest(accessToken: socketFiAccessToken)
        )
    }

    func groups() async throws -> [APIGroup] {
        let response = try await send(GroupsResponse.self, path: "groups")
        return response.groups
    }

    func me() async throws -> APIUser {
        let response = try await send(ProfileResponse.self, path: "me")
        return APIUser(
            id: response.profile.id,
            email: response.profile.email,
            displayName: response.profile.displayName,
            username: response.profile.username,
            smartAccount: response.profile.smartAccount
        )
    }

    func updateProfile(displayName: String, username: String?) async throws {
        let body = UpdateProfileRequest(displayName: displayName, username: username)
        _ = try await send(
            UpdatedProfileResponse.self,
            path: "me",
            method: "PATCH",
            body: body
        )
    }

    func usernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponse {
        try await send(
            UsernameAvailabilityResponse.self,
            path: "me/username-availability",
            method: "POST",
            body: UsernameAvailabilityRequest(username: username)
        )
    }

    func createGroup(
        name: String,
        description: String?,
        currency: String
    ) async throws -> APIGroup {
        let body = CreateGroupRequest(
            name: name,
            description: description,
            defaultCurrency: currency
        )
        let response = try await send(
            GroupResponse.self,
            path: "groups",
            method: "POST",
            body: body
        )
        return response.group
    }

    func interpretAssistant(prompt: String, contextPlanId: String?) async throws -> APIAssistantDraft {
        let response = try await send(
            AssistantInterpretResponse.self,
            path: "assistant/interpret",
            method: "POST",
            body: AssistantInterpretRequest(prompt: prompt, contextPlanId: contextPlanId)
        )
        return response.draft
    }

    func transcribeAssistant(audioURL: URL) async throws -> String {
        let audio = try Data(contentsOf: audioURL)
        let boundary = "PaktlyBoundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"command.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = makeRequest(path: "assistant/transcribe", method: "POST", body: body, authenticated: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let data = try await perform(request)
        return try decoder.decode(AssistantTranscriptionResponse.self, from: data).transcript
    }

    func group(_ id: String) async throws -> (APIGroup, [APIGroupMember]) {
        let response = try await send(GroupDetailResponse.self, path: "groups/\(id)")
        return (response.group, response.members)
    }

    func expenses(groupID: String) async throws -> [APIExpense] {
        let response = try await send(
            ExpensesResponse.self,
            path: "groups/\(groupID)/expenses"
        )
        return response.expenses
    }

    func addExpense(groupID: String, draft: ExpenseDraft) async throws {
        _ = try await send(
            ExpenseResponse.self,
            path: "groups/\(groupID)/expenses",
            method: "POST",
            body: draft
        )
    }

    func updateExpense(id: String, expectedVersion: Int, draft: ExpenseDraft) async throws {
        let body = UpdateExpenseRequest(
            expectedVersion: expectedVersion,
            description: draft.description,
            category: draft.category,
            amountMinor: draft.amountMinor,
            currency: draft.currency,
            paidBy: draft.paidBy,
            expenseDate: draft.expenseDate,
            notes: draft.notes,
            split: draft.split,
            exchangeRate: draft.exchangeRate
        )
        _ = try await send(
            ExpenseResponse.self,
            path: "expenses/\(id)",
            method: "PATCH",
            body: body
        )
    }

    func deleteExpense(id: String) async throws {
        try await sendWithoutResponse(path: "expenses/\(id)", method: "DELETE")
    }

    func balances(groupID: String) async throws -> ([APIBalance], [APISuggestedSettlement]) {
        let response = try await send(
            BalancesResponse.self,
            path: "groups/\(groupID)/balances"
        )
        return (response.balances, response.suggestedSettlements)
    }

    func activity(groupID: String) async throws -> [APIActivity] {
        let response = try await send(
            ActivityResponse.self,
            path: "groups/\(groupID)/activity"
        )
        return response.events
    }

    func notifications() async throws -> ([APINotification], Int) {
        let response = try await send(NotificationsResponse.self, path: "notifications")
        return (response.notifications, response.unreadCount)
    }

    func registerPushDevice(installationId: String, token: String, environment: String) async throws {
        _ = try await send(
            EmptyResponse.self,
            path: "devices/push",
            method: "POST",
            body: PushDeviceRegistrationRequest(
                installationId: installationId,
                token: token,
                environment: environment,
                locale: Locale.current.identifier,
                timezone: TimeZone.current.identifier,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                deviceModel: nil
            )
        )
    }

    func unregisterPushDevice(installationId: String) async throws {
        try await sendWithoutResponse(path: "devices/push/\(installationId)", method: "DELETE")
    }

    func notificationPreferences() async throws -> APINotificationPreferences {
        let response = try await send(NotificationPreferencesResponse.self, path: "notification-preferences")
        return response.preferences
    }

    func updateNotificationPreferences(_ preferences: APINotificationPreferences) async throws -> APINotificationPreferences {
        let response = try await send(
            NotificationPreferencesResponse.self,
            path: "notification-preferences",
            method: "PATCH",
            body: preferences
        )
        return response.preferences
    }

    func markAllNotificationsRead() async throws {
        _ = try await send(UpdatedCountResponse.self, path: "notifications/read-all", method: "POST", body: EmptyRequest())
    }

    func markNotificationRead(id: String) async throws {
        _ = try await send(
            NotificationResponse.self,
            path: "notifications/\(id)/read",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func invite(groupID: String, identifier: String) async throws -> String? {
        let response = try await send(
            InvitationResponse.self,
            path: "groups/\(groupID)/invitations",
            method: "POST",
            body: InvitationRequest(identifier: identifier)
        )
        return response.invitation.token
    }

    func createJoinLink(groupID: String) async throws -> APIJoinLink {
        let response = try await send(
            JoinLinkResponse.self,
            path: "groups/\(groupID)/join-links",
            method: "POST",
            body: CreateJoinLinkRequest(expiresInDays: 7, maxUses: 50)
        )
        return response.joinLink
    }

    func revokeJoinLink(groupID: String) async throws {
        try await sendWithoutResponse(path: "groups/\(groupID)/join-links/current", method: "DELETE")
    }

    func previewJoinLink(token: String? = nil, code: String? = nil) async throws -> APIJoinLinkPreview {
        let response = try await send(
            JoinLinkPreviewResponse.self,
            path: "join-links/preview",
            method: "POST",
            body: JoinLinkCredentialRequest(token: token, code: code)
        )
        return response.joinLink
    }

    func acceptJoinLink(token: String? = nil, code: String? = nil) async throws -> String {
        let response = try await send(
            JoinLinkAcceptanceResponse.self,
            path: "join-links/accept",
            method: "POST",
            body: JoinLinkCredentialRequest(token: token, code: code)
        )
        return response.groupId
    }

    func pendingInvitations() async throws -> [APIInvitation] {
        let response = try await send(PendingInvitationsResponse.self, path: "invitations")
        return response.invitations
    }

    func resolveInvitation(token: String) async throws -> APIInvitation {
        let response = try await send(
            InvitationDetailResponse.self,
            path: "invitations/resolve",
            method: "POST",
            body: AcceptInvitationRequest(token: token)
        )
        return response.invitation
    }

    func acceptInvitation(id: String) async throws {
        _ = try await send(
            AcceptInvitationResponse.self,
            path: "invitations/\(id)/accept",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func declineInvitation(id: String) async throws {
        _ = try await send(
            InvitationStatusResponse.self,
            path: "invitations/\(id)/decline",
            method: "POST",
            body: EmptyRequest()
        )
    }

    func acceptInvitation(token: String) async throws {
        _ = try await send(
            AcceptInvitationResponse.self,
            path: "invitations/accept",
            method: "POST",
            body: AcceptInvitationRequest(token: token)
        )
    }

    func settle(groupID: String, from: String, to: String, amountMinor: Int) async throws {
        let body = SettlementRequest(
            fromUserId: from,
            toUserId: to,
            amountMinor: amountMinor
        )
        _ = try await send(
            SettlementResponse.self,
            path: "groups/\(groupID)/settlements",
            method: "POST",
            body: body
        )
    }

    private func send<Response: Decodable>(
        _ responseType: Response.Type,
        path: String,
        method: String = "GET",
        authenticated: Bool = true
    ) async throws -> Response {
        let request = makeRequest(
            path: path,
            method: method,
            body: nil,
            authenticated: authenticated
        )
        let data = try await perform(request)
        return try decoder.decode(responseType, from: data)
    }

    private func send<Response: Decodable, Body: Encodable>(
        _ responseType: Response.Type,
        path: String,
        method: String,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        let encodedBody = try encoder.encode(body)
        let request = makeRequest(
            path: path,
            method: method,
            body: encodedBody,
            authenticated: authenticated
        )
        let data = try await perform(request)
        return try decoder.decode(responseType, from: data)
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        authenticated: Bool = true
    ) async throws {
        let request = makeRequest(
            path: path,
            method: method,
            body: nil,
            authenticated: authenticated
        )
        _ = try await perform(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool
    ) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = KeychainTokenStore.load() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.requestFailed(statusCode)
        }
        return data
    }
}

enum APIError: Error {
    case requestFailed(Int)
    case secureStorage
}

enum KeychainTokenStore {
    private static let service = "io.paktly.app.session"

    static func save(_ token: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        _ = SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData] = Data(token.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIError.secureStorage
        }
    }

    static func load() -> String? {
        var result: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
