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
    private let smartAccountService: any SmartAccountService
    private let apiClient: APIClient

    init(smartAccountService: any SmartAccountService, apiClient: APIClient = .shared) {
        self.smartAccountService = smartAccountService
        self.apiClient = apiClient
    }

    func authenticate(email: String, displayName: String) async {
        guard state != .authenticating else { return }
        state = .authenticating

        do {
            let smartSession = try await smartAccountService.authenticate()
            _ = try await apiClient.developmentSignIn(email: email, displayName: displayName)
            state = .signedIn(smartSession)
        } catch {
            state = .failed
        }
    }

    func signOut() async {
        await smartAccountService.signOut()
        KeychainTokenStore.clear()
        state = .signedOut
    }
}
