import Foundation

struct WebAuthUser {
    let email: String
    let name: String
}

enum WebAuthError: LocalizedError {
    case invalidCredentials
    case invalidRequest
    case serviceUnavailable
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email ou senha inválidos."
        case .invalidRequest:
            return "Verifique os dados e tente novamente."
        case .serviceUnavailable:
            return "Serviço indisponível no momento."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case .serverMessage(let message):
            return message
        }
    }
}

actor WebAuthService {
    static let shared = WebAuthService()
    nonisolated static let mobileMetaRedirectURI = "psymanager://auth"

    private struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    private struct RegisterRequest: Encodable {
        let email: String
        let password: String
        let artistName: String
    }

    private struct UserDTO: Decodable {
        let email: String
        let name: String?
    }

    private struct AuthResponse: Decodable {
        let ok: Bool?
        let user: UserDTO?
        let mobileToken: String?
        let expiresIn: Int?
        let error: String?
    }

    private struct ErrorResponse: Decodable {
        let error: String?
    }

    private struct SocialCallbackPayload {
        let token: String
        let email: String
        let name: String
    }

    private var baseURL: String {
        let raw = UserDefaults.standard.string(forKey: "psy.web.baseURL") ?? "https://web-app-eight-hazel.vercel.app"
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeInstagramMetaLoginURL() -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/mobile-auth/meta") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: Self.mobileMetaRedirectURI)
        ]
        return components.url
    }

    func getDirectFacebookOAuthURL() async throws -> URL {
        // For production on real device: Use ASWebAuthenticationSession flow
        // This method is no longer needed, but kept for compatibility
        guard var components = URLComponents(string: "\(baseURL)/mobile-auth/meta") else {
            throw WebAuthError.invalidRequest
        }
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: Self.mobileMetaRedirectURI)
        ]
        guard let url = components.url else {
            throw WebAuthError.invalidRequest
        }
        return url
    }

    nonisolated func canHandleMobileAuthCallback(_ url: URL) -> Bool {
        url.scheme == "psymanager" && url.host == "auth"
    }

    func completeMobileAuthCallback(_ url: URL) throws -> WebAuthUser {
        let payload = try parseSocialCallbackPayload(from: url)
        persistSession(token: payload.token, user: UserDTO(email: payload.email, name: payload.name))
        return WebAuthUser(email: payload.email, name: payload.name)
    }

    func login(email: String, password: String) async throws -> WebAuthUser {
        let body = LoginRequest(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), password: password)
        let data = try await performAuthRequest(path: "/api/auth/local-login", body: body)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)

        guard decoded.ok == true,
              let user = decoded.user,
              let token = decoded.mobileToken,
              !token.isEmpty
        else {
            throw WebAuthError.invalidResponse
        }

        persistSession(token: token, user: user)
        return WebAuthUser(email: user.email, name: user.name ?? user.email)
    }

    func register(email: String, password: String, artistName: String) async throws {
        let body = RegisterRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        _ = try await performAuthRequest(path: "/api/auth/register", body: body)
    }

    func logout() {
        KeychainSecretStore.delete(KeychainSecretStore.webSyncAuthHeaderKey)
        KeychainSecretStore.delete(KeychainSecretStore.authUserEmailKey)
        KeychainSecretStore.delete(KeychainSecretStore.authUserNameKey)
        UserDefaults.standard.set(false, forKey: "psy.auth.isLoggedIn")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "psy.auth.sessionNonce")
    }

    private func performAuthRequest<T: Encodable>(path: String, body: T) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw WebAuthError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WebAuthError.invalidResponse
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        let fallbackError = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
        switch http.statusCode {
        case 400: throw WebAuthError.serverMessage(fallbackError ?? WebAuthError.invalidRequest.localizedDescription)
        case 401: throw WebAuthError.invalidCredentials
        case 503: throw WebAuthError.serviceUnavailable
        default: throw WebAuthError.serverMessage(fallbackError ?? "Erro de autenticação (\(http.statusCode)).")
        }
    }

    private func persistSession(token: String, user: UserDTO) {
        KeychainSecretStore.write(token, account: KeychainSecretStore.webSyncAuthHeaderKey)
        KeychainSecretStore.write(user.email, account: KeychainSecretStore.authUserEmailKey)
        KeychainSecretStore.write(user.name ?? user.email, account: KeychainSecretStore.authUserNameKey)
        UserDefaults.standard.set(true, forKey: "psy.auth.isLoggedIn")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "psy.auth.sessionNonce")
    }

    private func parseSocialCallbackPayload(from url: URL) throws -> SocialCallbackPayload {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WebAuthError.invalidResponse
        }

        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if let error = items["error"], !error.isEmpty {
            throw WebAuthError.serverMessage(socialLoginErrorMessage(for: error))
        }

        let token = items["mobileToken"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = items["email"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = items["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !token.isEmpty else {
            throw WebAuthError.invalidResponse
        }

        return SocialCallbackPayload(
            token: token,
            email: email.isEmpty ? "meta:user" : email,
            name: name.isEmpty ? "Conta Meta" : name
        )
    }

    private func socialLoginErrorMessage(for code: String) -> String {
        switch code {
        case "AccessDenied":
            return "Acesso negado no login com Instagram."
        case "OAuthSignin", "OAuthCallback", "Callback":
            return "Falha no retorno do login com Instagram."
        case "no_session":
            return "Nao foi possivel criar a sessao do app apos o login."
        case "session_unavailable":
            return "Sessao mobile indisponivel no servidor."
        default:
            return "Falha ao entrar com Instagram via Meta."
        }
    }
}
