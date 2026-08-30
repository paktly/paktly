import Foundation
import Security

struct APIUser: Codable, Identifiable, Sendable { let id: String; let email: String; let displayName: String }
struct APIGroup: Codable, Identifiable, Sendable { let id: String; let name: String; let description: String?; let defaultCurrency: String; let role: String?; let memberCount: Int? }
struct APIGroupMember: Codable, Identifiable, Sendable { let id: String; let email: String; let displayName: String; let avatarUrl: String?; let role: String }
struct APIExpense: Codable, Identifiable, Sendable {
    let id: String; let currentVersion: Int; let description: String; let category: String
    let originalAmountMinor: Int; let originalCurrency: String; let convertedAmountMinor: Int
    let groupCurrency: String; let paidBy: String; let expenseDate: Date; let notes: String?; let splitMethod: String; let payerName: String?
}
struct APIBalance: Codable, Identifiable, Sendable { let userId: String; let displayName: String; let netMinor: Int; var id: String { userId } }
struct APISuggestedSettlement: Codable, Sendable { let fromUserId: String; let toUserId: String; let amountMinor: Int }
struct APIActivity: Codable, Identifiable, Sendable { let id: String; let type: String; let summary: String; let createdAt: Date }
struct APINotification: Codable, Identifiable, Sendable { let id: String; let title: String; let body: String; let readAt: Date?; let createdAt: Date }

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

actor APIClient {
    static let shared: APIClient = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PaktlyAPIBaseURL") as? String,
              let url = URL(string: value), !value.isEmpty else {
            fatalError("PaktlyAPIBaseURL must be configured for this build.")
        }
        return APIClient(baseURL: url)
    }()
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
    }

    func developmentSignIn(email: String, displayName: String) async throws -> APIUser {
        struct Body: Encodable { let email: String; let displayName: String }
        struct Response: Decodable { let accessToken: String; let user: APIUser }
        let response: Response = try await send("auth/dev-session", method: "POST", body: Body(email: email, displayName: displayName), authenticated: false)
        try KeychainTokenStore.save(response.accessToken)
        return response.user
    }

    func groups() async throws -> [APIGroup] { struct R: Decodable { let groups: [APIGroup] }; return try await send("groups").groups }
    func me() async throws -> APIUser { struct R: Decodable { let profile: Profile }; struct Profile: Decodable { let id: String; let email: String; let displayName: String }; let profile: Profile = try await send("me").profile; return APIUser(id: profile.id, email: profile.email, displayName: profile.displayName) }
    func updateProfile(displayName: String) async throws { struct B: Encodable { let displayName: String }; struct R: Decodable { let profile: Profile }; struct Profile: Decodable { let displayName: String }; let _: R = try await send("me", method: "PATCH", body: B(displayName: displayName)) }
    func createGroup(name: String, description: String?, currency: String) async throws -> APIGroup {
        struct Body: Encodable { let name: String; let description: String?; let defaultCurrency: String }
        struct R: Decodable { let group: APIGroup }
        return try await send("groups", method: "POST", body: Body(name: name, description: description, defaultCurrency: currency)).group
    }
    func group(_ id: String) async throws -> (APIGroup, [APIGroupMember]) { struct R: Decodable { let group: APIGroup; let members: [APIGroupMember] }; let r: R = try await send("groups/\(id)"); return (r.group, r.members) }
    func expenses(groupID: String) async throws -> [APIExpense] { struct R: Decodable { let expenses: [APIExpense] }; return try await send("groups/\(groupID)/expenses").expenses }
    func addExpense(groupID: String, draft: ExpenseDraft) async throws { struct R: Decodable { let expense: Created }; struct Created: Decodable { let id: String }; let _: R = try await send("groups/\(groupID)/expenses", method: "POST", body: draft) }
    func updateExpense(id: String, expectedVersion: Int, draft: ExpenseDraft) async throws {
        struct Body: Encodable {
            let expectedVersion: Int; let description: String; let category: String; let amountMinor: Int; let currency: String
            let paidBy: String; let expenseDate: Date; let notes: String?; let split: ExpenseDraft.Split
            let exchangeRate: ExpenseDraft.ExchangeRate?
        }
        struct R: Decodable { let expense: Updated }; struct Updated: Decodable { let id: String }
        let body = Body(expectedVersion: expectedVersion, description: draft.description, category: draft.category, amountMinor: draft.amountMinor, currency: draft.currency, paidBy: draft.paidBy, expenseDate: draft.expenseDate, notes: draft.notes, split: draft.split, exchangeRate: draft.exchangeRate)
        let _: R = try await send("expenses/\(id)", method: "PATCH", body: body)
    }
    func deleteExpense(id: String) async throws { let _: EmptyResponse = try await send("expenses/\(id)", method: "DELETE") }
    func balances(groupID: String) async throws -> ([APIBalance], [APISuggestedSettlement]) { struct R: Decodable { let balances: [APIBalance]; let suggestedSettlements: [APISuggestedSettlement] }; let r: R = try await send("groups/\(groupID)/balances"); return (r.balances, r.suggestedSettlements) }
    func activity(groupID: String) async throws -> [APIActivity] { struct R: Decodable { let events: [APIActivity] }; return try await send("groups/\(groupID)/activity").events }
    func notifications() async throws -> [APINotification] { struct R: Decodable { let notifications: [APINotification] }; return try await send("notifications").notifications }
    func markNotificationRead(id: String) async throws { struct R: Decodable { let notification: APINotification }; let _: R = try await send("notifications/\(id)/read", method: "POST", body: EmptyRequest()) }
    func invite(groupID: String, email: String) async throws -> String? { struct B: Encodable { let email: String }; struct R: Decodable { let invitation: Invitation }; struct Invitation: Decodable { let id: String; let token: String? }; let response: R = try await send("groups/\(groupID)/invitations", method: "POST", body: B(email: email)); return response.invitation.token }
    func acceptInvitation(token: String) async throws { struct B: Encodable { let token: String }; struct R: Decodable { let groupId: String }; let _: R = try await send("invitations/accept", method: "POST", body: B(token: token)) }
    func settle(groupID: String, from: String, to: String, amountMinor: Int) async throws {
        struct B: Encodable { let fromUserId: String; let toUserId: String; let amountMinor: Int; let method = "MARKED_PAID"; let note: String? = nil; let clientOperationId = UUID().uuidString.lowercased() }
        struct R: Decodable { let settlement: Settlement }; struct Settlement: Decodable { let id: String }
        let _: R = try await send("groups/\(groupID)/settlements", method: "POST", body: B(fromUserId: from, toUserId: to, amountMinor: amountMinor))
    }

    private func send<Response: Decodable>(_ path: String, method: String = "GET", authenticated: Bool = true) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path)); request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = KeychainTokenStore.load() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
        if data.isEmpty, Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
        return try decoder.decode(Response.self, from: data)
    }

    private func send<Response: Decodable, Body: Encodable>(_ path: String, method: String, body: Body, authenticated: Bool = true) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path)); request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = KeychainTokenStore.load() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct EmptyResponse: Decodable {}
private struct EmptyRequest: Encodable {}
enum APIError: Error { case requestFailed(Int); case secureStorage }

enum KeychainTokenStore {
    private static let service = "io.paktly.app.session"
    static func save(_ token: String) throws {
        let data = Data(token.utf8); SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
        let status = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIError.secureStorage }
    }
    static func load() -> String? {
        var item: CFTypeRef?; let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }; return String(data: data, encoding: .utf8)
    }
    static func clear() { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary) }
}
