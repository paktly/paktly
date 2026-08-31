import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
import Security
import UIKit

enum FederatedAuthError: LocalizedError {
    case configuration(String)
    case missingToken
    case presentation

    var errorDescription: String? {
        switch self {
        case let .configuration(provider): "\(provider) sign-in isn’t configured for this build."
        case .missingToken: "The identity provider didn’t return a valid identity token."
        case .presentation: "Paktly couldn’t present the sign-in screen. Please try again."
        }
    }
}

enum AppleAuthNonce {
    static func make(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: 16)
        while result.count < length {
            let status = bytes.withUnsafeMutableBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return errSecParam }
                return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
            }
            guard status == errSecSuccess else {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            for byte in bytes where result.count < length {
                if byte < characters.count { result.append(characters[Int(byte)]) }
            }
        }
        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
enum GoogleAuthentication {
    static func identityToken() async throws -> String {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "PaktlyGoogleIOSClientID") as? String,
            let serverClientID = Bundle.main.object(forInfoDictionaryKey: "PaktlyGoogleServerClientID") as? String,
            !clientID.hasPrefix("CHANGE_ME"),
            !serverClientID.hasPrefix("CHANGE_ME")
        else { throw FederatedAuthError.configuration("Google") }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )
        guard let presenter = UIApplication.shared.paktlyTopViewController else {
            throw FederatedAuthError.presentation
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let token = result.user.idToken?.tokenString else { throw FederatedAuthError.missingToken }
        return token
    }

    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

private extension UIApplication {
    var paktlyTopViewController: UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var current = root
        while let presented = current?.presentedViewController { current = presented }
        return current
    }
}
