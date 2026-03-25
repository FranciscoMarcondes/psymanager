import AuthenticationServices
import UIKit
import SwiftUI

struct MobileLoginView: View {
    enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Entrar"
        case register = "Criar conta"

        var id: String { rawValue }
    }

    @AppStorage("psy.auth.isLoggedIn") private var isLoggedIn = false
    @AppStorage("psy.auth.sessionNonce") private var authSessionNonce = 0.0
    @AppStorage("psy.auth.prefillArtistName") private var prefillArtistName = ""
    @AppStorage("psy.auth.lastError") private var lastAuthError = ""

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var artistName = ""
    @State private var loading = false
    @State private var socialLoading = false
    @State private var feedback = ""
    @StateObject private var socialLoginSession = SocialLoginSessionCoordinator()

    var body: some View {
        ZStack {
            PsyTheme.heroGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer(minLength: 10)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("PsyManager")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Mesmo acesso do web, com sessao conectada e sync em tempo real no app.")
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    PsyCard {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Entrar com rede social")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Use Instagram ou Facebook via Meta, igual ao web.")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }

                            Button(action: startInstagramLogin) {
                                HStack {
                                    if socialLoading {
                                        ProgressView().tint(.white).controlSize(.small)
                                    }
                                    Text(socialLoading ? "Conectando..." : "Continuar com Instagram / Facebook")
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PsyTheme.secondary)
                            .disabled(loading || socialLoading)

                            Divider()

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Ou use email e senha")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Picker("Modo", selection: $mode) {
                                    ForEach(AuthMode.allCases) { authMode in
                                        Text(authMode.rawValue).tag(authMode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if mode == .register {
                                    TextField("Nome artístico", text: $artistName)
                                        .textInputAutocapitalization(.words)
                                        .textFieldStyle(.roundedBorder)
                                }

                                TextField("Email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                SecureField("Senha", text: $password)
                                    .textFieldStyle(.roundedBorder)

                                Button(action: submit) {
                                    HStack {
                                        if loading {
                                            ProgressView().tint(.white).controlSize(.small)
                                        }
                                        Text(loading ? "Aguarde..." : (mode == .login ? "Entrar" : "Criar conta"))
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(PsyTheme.primary)
                                .disabled(loading || socialLoading || isInvalid)
                            }

                            if !feedback.isEmpty {
                                Text(feedback)
                                    .font(.caption)
                                    .foregroundStyle(feedback.hasPrefix("✅") ? .green : .red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if !lastAuthError.isEmpty {
                                Text(lastAuthError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Text("Seu login usa o mesmo backend e validacoes do web, sem navegar para a tela inicial web.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .padding(.horizontal, 20)

                    Text("Se sua conta ja existe no web, o app usa a mesma identidade e sincroniza os dados da mesma conta.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }
        }
    }

    private var isInvalid: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .register {
            return cleanEmail.isEmpty || cleanPassword.count < 6 || artistName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
        }
        return cleanEmail.isEmpty || cleanPassword.isEmpty
    }

    private func submit() {
        loading = true
        feedback = ""
        lastAuthError = ""

        Task {
            do {
                if mode == .register {
                    try await WebAuthService.shared.register(email: email, password: password, artistName: artistName)
                    await MainActor.run {
                        prefillArtistName = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
                        feedback = "✅ Conta criada. Fazendo login..."
                    }
                }

                let user = try await WebAuthService.shared.login(email: email, password: password)
                await MainActor.run {
                    prefillArtistName = prefillArtistName.isEmpty ? user.name : prefillArtistName
                    isLoggedIn = true
                    authSessionNonce = Date().timeIntervalSince1970
                    feedback = ""
                    loading = false
                }
            } catch {
                await MainActor.run {
                    feedback = "❌ \(error.localizedDescription)"
                    loading = false
                }
            }
        }
    }

    private func startInstagramLogin() {
        feedback = ""
        lastAuthError = ""
        socialLoading = true

        Task {
            guard let loginURL = await WebAuthService.shared.makeInstagramMetaLoginURL() else {
                await MainActor.run {
                    feedback = "❌ Não foi possível iniciar o login com Instagram."
                    socialLoading = false
                }
                return
            }

            do {
                // Use ASWebAuthenticationSession for native OAuth flow
                let callbackURL = try await socialLoginSession.start(url: loginURL, callbackScheme: "psymanager")
                let user = try await WebAuthService.shared.completeMobileAuthCallback(callbackURL)
                await MainActor.run {
                    prefillArtistName = user.name
                    isLoggedIn = true
                    authSessionNonce = Date().timeIntervalSince1970
                    feedback = ""
                    lastAuthError = ""
                    socialLoading = false
                }
            } catch {
                await MainActor.run {
                    lastAuthError = error.localizedDescription
                    socialLoading = false
                }
            }
        }
    }
}

@MainActor
final class SocialLoginSessionCoordinator: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: WebAuthError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            self.session = session

            if !session.start() {
                continuation.resume(throwing: WebAuthError.serviceUnavailable)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        return window ?? ASPresentationAnchor()
    }
}
