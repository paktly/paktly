import AuthenticationServices
import Foundation
import Security
import UIKit

private struct SocketFiNativeConfiguration {
    let apiURL: URL
    let clientID: String
    let applicationID: String
    let network: String
    let rpID: String

    static func live(bundle: Bundle = .main) -> SocketFiNativeConfiguration {
        func value(_ key: String) -> String {
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
                fatalError("\(key) must be configured for this build.")
            }
            return value
        }
        guard let apiURL = URL(string: value("SocketFiAPIBaseURL")) else {
            fatalError("SocketFiAPIBaseURL is invalid.")
        }
        return SocketFiNativeConfiguration(
            apiURL: apiURL,
            clientID: value("SocketFiClientID"),
            applicationID: value("SocketFiApplicationID"),
            network: value("SocketFiNetwork"),
            rpID: value("SocketFiRPID")
        )
    }
}

private struct NativeStartRequest: Encodable {
    let clientId: String
    let applicationId: String
    let platform = "ios"
    let network: String
    let mode: String
    let username: String?
}

private struct NativeStartResponse: Decodable {
    struct Payload: Decodable {
        let tempAccess: String
        let rpId: String
    }
    let data: Payload
}

private struct AuthOptionsRequest: Encodable {
    let tempAccess: String
    let clientId: String
    let mode: String
}

private struct PublicKeyCredentialOptions: Decodable {
    struct User: Decodable {
        let id: String
        let name: String
        let displayName: String
    }
    struct Credential: Decodable {
        let id: String
    }
    let challenge: String
    let user: User?
    let allowCredentials: [Credential]?
}

private struct AuthOptionsResponse: Decodable {
    let options: PublicKeyCredentialOptions
    let createPopAccess: Bool?
}

private struct SocketFiSessionPayload: Decodable {
    let socketfiAccessToken: String
    let address: [String: String]?
    let username: String?
}

private struct VerifyResponse: Decodable {
    let verified: Bool?
    let options: PublicKeyCredentialOptions?
    let createPopAccess: Bool?
    let session: SocketFiSessionPayload?
}

private struct RegistrationCredential: Encodable {
    struct Response: Encodable {
        let clientDataJSON: String
        let attestationObject: String
        let transports = ["internal"]
    }
    let id: String
    let rawId: String
    let type = "public-key"
    let response: Response
    let authenticatorAttachment = "platform"
}

private struct AssertionCredential: Encodable {
    struct Response: Encodable {
        let clientDataJSON: String
        let authenticatorData: String
        let signature: String
        let userHandle: String
    }
    let id: String
    let rawId: String
    let type = "public-key"
    let response: Response
    let authenticatorAttachment = "platform"
}

private enum NativeCredential {
    case registration(RegistrationCredential)
    case assertion(AssertionCredential)
}

private enum SocketFiNativeError: LocalizedError {
    case invalidChallenge
    case invalidResponse
    case unsupportedCredential
    case requestFailed(Int, String)
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .invalidChallenge: "SocketFi returned an invalid passkey challenge."
        case .invalidResponse: "SocketFi returned an incomplete authentication response."
        case .unsupportedCredential: "This device did not return a supported passkey credential."
        case let .requestFailed(_, message): message
        case .usernameTaken: "That username is already taken. Try another one."
        }
    }
}

@MainActor
final class SocketFiNativeSmartAccountService: NSObject, SmartAccountService, @unchecked Sendable {
    private let configuration: SocketFiNativeConfiguration
    private var account: SmartAccount?
    private var authorizationContinuation: CheckedContinuation<NativeCredential, Error>?

    override convenience init() {
        self.init(configuration: .live())
    }

    private init(configuration: SocketFiNativeConfiguration) {
        self.configuration = configuration
        super.init()
    }

    func authenticate(mode: SmartAccountAuthenticationMode, username: String? = nil) async throws -> SmartAccountSession {
        let start = try await post(
            NativeStartResponse.self,
            path: "api/native/auth/start",
            body: NativeStartRequest(
                clientId: configuration.clientID,
                applicationId: configuration.applicationID,
                network: configuration.network,
                mode: mode.rawValue,
                username: username
            )
        )
        let request = AuthOptionsRequest(
            tempAccess: start.data.tempAccess,
            clientId: configuration.clientID,
            mode: mode.rawValue
        )
        let initial = try await post(
            AuthOptionsResponse.self,
            path: "oauth/init-auth",
            body: request
        )
        let credential = try await authorize(
            options: initial.options,
            rpID: start.data.rpId,
            registration: mode == .signUp
        )
        var verified = try await verify(
            credential,
            path: "oauth/verify-auth",
            request: request
        )

        if verified.createPopAccess == true, let options = verified.options {
            let proof = try await authorize(options: options, rpID: start.data.rpId, registration: false)
            verified = try await verify(
                proof,
                path: "oauth/create-wallet",
                request: request
            )
        }

        guard
            verified.verified == true,
            let session = verified.session,
            let wallet = session.address?[configuration.network]
        else {
            throw SocketFiNativeError.invalidResponse
        }

        let account = SmartAccount(id: wallet, displayAddress: wallet.abbreviatedAddress)
        self.account = account
        try SocketFiTokenStore.save(session.socketfiAccessToken)
        return SmartAccountSession(
            account: account,
            expiresAt: Date().addingTimeInterval(3_600),
            socketFiAccessToken: session.socketfiAccessToken
        )
    }

    func currentAccount() async throws -> SmartAccount {
        guard let account else { throw SmartAccountError.noActiveSession }
        return account
    }

    func authorizeTransaction(_ request: TransactionRequest) async throws -> AuthorizedTransaction {
        guard account != nil else { throw SmartAccountError.noActiveSession }
        guard let accessToken = SocketFiTokenStore.load() else {
            throw SmartAccountError.noActiveSession
        }
        let payload = try JSONDecoder().decode(NativeTransactionPayload.self, from: request.payload)
        let started = try await post(
            NativeTransactionStartResponse.self,
            path: "api/native/transactions/start",
            body: NativeTransactionStartRequest(
                clientId: configuration.clientID,
                applicationId: configuration.applicationID,
                network: configuration.network,
                contractId: payload.contractId,
                callFunction: .init(name: payload.functionName),
                argsXdr: payload.argsXdr
            ),
            bearerToken: accessToken
        )
        let initialized = try await post(
            NativeTransactionInitResponse.self,
            path: "api/tx/transaction-intents/init",
            body: NativeTransactionInitRequest(
                txSession: started.txSession,
                clientId: configuration.clientID
            )
        )
        let credential = try await authorize(
            options: initialized.options,
            rpID: configuration.rpID,
            registration: false
        )
        guard case let .assertion(assertion) = credential else {
            throw SocketFiNativeError.unsupportedCredential
        }
        let result = try await post(
            NativeTransactionResult.self,
            path: payload.submit
                ? "api/tx/transaction-intents/sign-and-submit"
                : "api/tx/transaction-intents/sign",
            body: NativeTransactionSignRequest(
                txSession: started.txSession,
                sigData: assertion
            )
        )
        guard result.success else { throw SocketFiNativeError.invalidResponse }
        return AuthorizedTransaction(id: result.data?.txHash ?? started.txSession)
    }

    func signOut() async {
        account = nil
        SocketFiTokenStore.clear()
    }

    private func verify(
        _ credential: NativeCredential,
        path: String,
        request: AuthOptionsRequest
    ) async throws -> VerifyResponse {
        switch credential {
        case let .registration(value):
            return try await post(
                VerifyResponse.self,
                path: path,
                body: VerifyRequest(
                    tempAccess: request.tempAccess,
                    clientId: request.clientId,
                    mode: request.mode,
                    authData: value
                )
            )
        case let .assertion(value):
            return try await post(
                VerifyResponse.self,
                path: path,
                body: VerifyRequest(
                    tempAccess: request.tempAccess,
                    clientId: request.clientId,
                    mode: request.mode,
                    authData: value
                )
            )
        }
    }

    private func authorize(
        options: PublicKeyCredentialOptions,
        rpID: String,
        registration: Bool
    ) async throws -> NativeCredential {
        guard let challenge = Data(base64URLEncoded: options.challenge) else {
            throw SocketFiNativeError.invalidChallenge
        }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: rpID
        )
        let authorizationRequest: ASAuthorizationRequest
        if registration {
            guard
                let user = options.user,
                let userID = Data(base64URLEncoded: user.id)
            else { throw SocketFiNativeError.invalidChallenge }
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: user.name,
                userID: userID
            )
            request.userVerificationPreference = .required
            authorizationRequest = request
        } else {
            let request = provider.createCredentialAssertionRequest(challenge: challenge)
            request.userVerificationPreference = .required
            request.allowedCredentials = options.allowCredentials?.compactMap { descriptor in
                guard let id = Data(base64URLEncoded: descriptor.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: id)
            } ?? []
            authorizationRequest = request
        }

        return try await withCheckedThrowingContinuation { continuation in
            precondition(authorizationContinuation == nil)
            authorizationContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [authorizationRequest])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func post<Response: Decodable, Body: Encodable>(
        _ responseType: Response.Type,
        path: String,
        body: Body,
        bearerToken: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: configuration.apiURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let apiError = try? JSONDecoder().decode(SocketFiErrorResponse.self, from: data)
            if status == 409, apiError?.code == "USERNAME_TAKEN" {
                throw SocketFiNativeError.usernameTaken
            }
            let message = apiError?.error ?? "SocketFi authentication failed."
            throw SocketFiNativeError.requestFailed(status, message)
        }
        return try JSONDecoder().decode(responseType, from: data)
    }
}

extension SocketFiNativeSmartAccountService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let result: Result<NativeCredential, Error>
        if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
           let attestationObject = registration.rawAttestationObject {
            let id = registration.credentialID.base64URLEncodedString()
            result = .success(.registration(RegistrationCredential(
                id: id,
                rawId: id,
                response: .init(
                    clientDataJSON: registration.rawClientDataJSON.base64URLEncodedString(),
                    attestationObject: attestationObject.base64URLEncodedString()
                )
            )))
        } else if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let id = assertion.credentialID.base64URLEncodedString()
            result = .success(.assertion(AssertionCredential(
                id: id,
                rawId: id,
                response: .init(
                    clientDataJSON: assertion.rawClientDataJSON.base64URLEncodedString(),
                    authenticatorData: assertion.rawAuthenticatorData.base64URLEncodedString(),
                    signature: assertion.signature.base64URLEncodedString(),
                    userHandle: assertion.userID.base64URLEncodedString()
                )
            )))
        } else {
            result = .failure(SocketFiNativeError.unsupportedCredential)
        }
        finishAuthorization(result)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finishAuthorization(.failure(error))
    }

    private func finishAuthorization(_ result: Result<NativeCredential, Error>) {
        let continuation = authorizationContinuation
        authorizationContinuation = nil
        continuation?.resume(with: result)
    }
}

extension SocketFiNativeSmartAccountService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
    }
}

private struct VerifyRequest<Credential: Encodable>: Encodable {
    let tempAccess: String
    let clientId: String
    let mode: String
    let authData: Credential
}

private struct SocketFiErrorResponse: Decodable {
    let error: String
    let code: String?
}

private struct NativeTransactionPayload: Decodable {
    let contractId: String
    let functionName: String
    let argsXdr: [String]
    let submit: Bool
}

private struct NativeTransactionStartRequest: Encodable {
    struct CallFunction: Encodable { let name: String }
    let clientId: String
    let applicationId: String
    let platform = "ios"
    let network: String
    let contractId: String
    let callFunction: CallFunction
    let argsXdr: [String]
}

private struct NativeTransactionStartResponse: Decodable {
    let txSession: String
}

private struct NativeTransactionInitRequest: Encodable {
    let txSession: String
    let clientId: String
}

private struct NativeTransactionInitResponse: Decodable {
    let options: PublicKeyCredentialOptions
}

private struct NativeTransactionSignRequest: Encodable {
    let txSession: String
    let sigData: AssertionCredential
}

private struct NativeTransactionResult: Decodable {
    struct Payload: Decodable {
        let txHash: String?
    }
    let success: Bool
    let data: Payload?
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized += String(repeating: "=", count: (4 - normalized.count % 4) % 4)
        self.init(base64Encoded: normalized)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var abbreviatedAddress: String {
        guard count > 12 else { return self }
        return "\(prefix(6))…\(suffix(6))"
    }
}

private enum SocketFiTokenStore {
    private static let service = "io.paktly.app.socketfi"

    static func save(_ token: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        _ = SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData] = Data(token.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw APIError.secureStorage
        }
    }

    static func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        _ = SecItemDelete(query as CFDictionary)
    }

    static func load() -> String? {
        var result: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
