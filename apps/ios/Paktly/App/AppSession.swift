import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    enum State: Equatable {
        case signedOut
        case authenticating
        case signedIn(SmartAccountSession)
        case failed
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var errorMessage: String?
    private let smartAccountService: any SmartAccountService
    private let apiClient: APIClient

    init(smartAccountService: any SmartAccountService, apiClient: APIClient = .shared) {
        self.smartAccountService = smartAccountService
        self.apiClient = apiClient
    }

    func authenticate(mode: SmartAccountAuthenticationMode, username: String? = nil, displayName: String? = nil) async {
        guard state != .authenticating else { return }
        state = .authenticating
        errorMessage = nil

        do {
            let smartSession = try await smartAccountService.authenticate(mode: mode, username: username)
            _ = try await apiClient.socketFiSignIn(
                accessToken: smartSession.socketFiAccessToken,
                displayName: displayName
            )
            state = .signedIn(smartSession)
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? "We couldn’t sign you in. Please try again."
            state = .failed
        }
    }

    func signOut() async {
        await smartAccountService.signOut()
        KeychainTokenStore.clear()
        errorMessage = nil
        state = .signedOut
    }
}
