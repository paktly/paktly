import Combine
import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case authenticating
        case needsProfile
        case signedIn
        case failed
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var errorMessage: String?
    @Published private(set) var isActivatingWallet = false
    @Published private(set) var walletActivationError: String?

    private let smartAccountService: any SmartAccountService
    private let apiClient: APIClient

    init(smartAccountService: any SmartAccountService, apiClient: APIClient = .shared) {
        self.smartAccountService = smartAccountService
        self.apiClient = apiClient
    }

    func restoreSession() async {
        guard state == .checking else { return }
        guard KeychainTokenStore.load() != nil else {
            state = .signedOut
            return
        }
        do {
            let user = try await apiClient.me()
            state = user.displayName == "Paktly member" ? .needsProfile : .signedIn
        } catch {
            KeychainTokenStore.clear()
            state = .signedOut
        }
    }

    func requestEmailCode(_ email: String) async throws -> String {
        errorMessage = nil
        return try await apiClient.requestEmailOTP(email: email)
    }

    func verifyEmailCode(challengeId: String, email: String, code: String) async {
        guard state != .authenticating else { return }
        state = .authenticating
        errorMessage = nil
        do {
            let (user, isNewUser) = try await apiClient.verifyEmailOTP(
                challengeId: challengeId,
                email: email,
                code: code
            )
            state = isNewUser || user.displayName == "Paktly member" ? .needsProfile : .signedIn
        } catch {
            errorMessage = "That code is incorrect or has expired."
            state = .failed
        }
    }

    func completeProfile(displayName: String, username: String?) async {
        state = .authenticating
        errorMessage = nil
        do {
            try await apiClient.updateProfile(displayName: displayName, username: username)
            state = .signedIn
        } catch {
            errorMessage = "We couldn’t save your profile. Check that the username is available."
            state = .needsProfile
        }
    }

    func activateSmartWallet(username: String?) async -> Bool {
        guard !isActivatingWallet else { return false }
        isActivatingWallet = true
        walletActivationError = nil
        defer { isActivatingWallet = false }
        do {
            let smartSession = try await smartAccountService.authenticate(mode: .signUp, username: username)
            try await apiClient.linkSmartWallet(socketFiAccessToken: smartSession.socketFiAccessToken)
            return true
        } catch {
            walletActivationError = (error as? any LocalizedError)?.errorDescription
                ?? "We couldn’t activate your smart wallet. Please try again."
            return false
        }
    }

    func signOut() async {
        await smartAccountService.signOut()
        KeychainTokenStore.clear()
        errorMessage = nil
        walletActivationError = nil
        state = .signedOut
    }
}
