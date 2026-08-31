import Foundation

struct SmartAccount: Equatable, Sendable {
    let id: String
    let displayAddress: String
}

struct SmartAccountSession: Equatable, Sendable {
    let account: SmartAccount
    let expiresAt: Date
    let socketFiAccessToken: String
}

enum SmartAccountAuthenticationMode: String, Sendable {
    case signIn = "signin"
    case signUp = "signup"
}

struct TransactionRequest: Sendable {
    let operation: String
    let payload: Data
}

struct AuthorizedTransaction: Sendable {
    let id: String
}

@MainActor
protocol SmartAccountService: AnyObject, Sendable {
    func authenticate(mode: SmartAccountAuthenticationMode, username: String?) async throws -> SmartAccountSession
    func currentAccount() async throws -> SmartAccount
    func authorizeTransaction(_ request: TransactionRequest) async throws -> AuthorizedTransaction
    func signOut() async
}

/// Development-only composition used until the supported SocketFi SDK surface is verified.
@MainActor
final class PreviewSmartAccountService: SmartAccountService, @unchecked Sendable {
    private var account: SmartAccount?

    func authenticate(mode: SmartAccountAuthenticationMode, username: String? = nil) async throws -> SmartAccountSession {
        try await Task.sleep(for: .milliseconds(450))
        let account = SmartAccount(id: "demo-account", displayAddress: "G…PAKTLY")
        self.account = account
        return SmartAccountSession(
            account: account,
            expiresAt: Date().addingTimeInterval(3_600),
            socketFiAccessToken: "preview-socketfi-token"
        )
    }

    func currentAccount() async throws -> SmartAccount {
        guard let account else { throw SmartAccountError.noActiveSession }
        return account
    }

    func authorizeTransaction(_ request: TransactionRequest) async throws -> AuthorizedTransaction {
        guard account != nil else { throw SmartAccountError.noActiveSession }
        return AuthorizedTransaction(id: "preview-\(request.operation)")
    }

    func signOut() async {
        account = nil
    }
}

enum SmartAccountError: Error {
    case noActiveSession
}
