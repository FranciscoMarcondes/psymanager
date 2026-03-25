import Charts
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let profile: ArtistProfile

    @Query(sort: \SocialInsightSnapshot.periodEnd, order: .reverse) private var snapshots: [SocialInsightSnapshot]
    @Query(sort: \Gig.date, order: .reverse) private var gigs: [Gig]
    @Query(sort: \EventLead.eventDate, order: .reverse) private var leads: [EventLead]
    @Query(sort: \PromoterContact.name) private var promoters: [PromoterContact]
    @Query(sort: \MessageTemplate.createdAt, order: .reverse) private var messageTemplates: [MessageTemplate]
    @Query(sort: \TripPlan.dateISO, order: .reverse) private var tripPlans: [TripPlan]
    @Query(sort: \SocialContentPlanItem.scheduledDate, order: .reverse) private var contentPlan: [SocialContentPlanItem]
    @Query(sort: \Expense.dateISO, order: .reverse) private var expenses: [Expense]
    @AppStorage("instagramConnectedMock") private var instagramConnectedMock = false
    @AppStorage("instagramOAuthStatus") private var instagramOAuthStatus = "idle"
    @AppStorage("instagramOAuthErrorMessage") private var instagramOAuthErrorMessage = ""
    @AppStorage("instagramInsightsBackendURL") private var backendURL = ""
    @AppStorage("artistInstagramHandle") private var artistInstagramHandle = ""
    @AppStorage("instagramLastConnectedAt") private var instagramLastConnectedAt = ""
    @AppStorage("instagramLastInsightsSyncAt") private var instagramLastInsightsSyncAt = ""
    @AppStorage("weeklyInsightAlertsEnabled") private var weeklyInsightAlertsEnabled = false
    @State private var spotifyToken = ""
    @State private var youtubeApiKey = ""
    @State private var soundCloudClientId = ""
    @State private var googleMapsApiKey = ""
    @State private var rapidApiKey = ""
    @State private var skyscannerApiKey = ""
    @State private var kiwiTequilaApiKey = ""
    @AppStorage("psy.web.baseURL") private var webSyncBaseURL = "https://web-app-eight-hazel.vercel.app"
    @AppStorage("psy.auth.isLoggedIn") private var isLoggedIn = false
    @AppStorage("psy.auth.sessionNonce") private var authSessionNonce = 0.0
    @State private var webSyncAuthHeader = ""
    @AppStorage("psy.logistics.rapidApiHost") private var rapidApiHost = "skyscanner44.p.rapidapi.com"
    @State private var showingInsightForm = false
    @State private var syncingInsights = false
    @State private var syncFeedback = ""
    @State private var isSyncingWorkspace = false
    @State private var workspaceSyncFeedback = ""
    @State private var testingPlatformConnections = false
    @State private var testingLogisticsConnections = false
    @State private var testingTemplateSyncConnection = false
    @State private var showAdvancedIntegrations = false
    @AppStorage("psy.spotify.connectionStatus") private var spotifyConnectionStatus = "Não testado"
    @AppStorage("psy.youtube.connectionStatus") private var youtubeConnectionStatus = "Não testado"
    @AppStorage("psy.soundcloud.connectionStatus") private var soundCloudConnectionStatus = "Não testado"
    @AppStorage("psy.web.templates.connectionStatus") private var templateSyncConnectionStatus = "Não testado"
    @AppStorage("psy.logistics.maps.connectionStatus") private var mapsConnectionStatus = "Não testado"
    @AppStorage("psy.logistics.flight.connectionStatus") private var flightConnectionStatus = "Não testado"
    @AppStorage("psy.spotify.connectionDetail") private var spotifyConnectionDetail = ""
    @AppStorage("psy.youtube.connectionDetail") private var youtubeConnectionDetail = ""
    @AppStorage("psy.soundcloud.connectionDetail") private var soundCloudConnectionDetail = ""
    @AppStorage("psy.web.templates.connectionDetail") private var templateSyncConnectionDetail = ""
    @AppStorage("psy.logistics.maps.connectionDetail") private var mapsConnectionDetail = ""
    @AppStorage("psy.logistics.flight.connectionDetail") private var flightConnectionDetail = ""
    @AppStorage("psy.spotify.lastCheckedAt") private var spotifyLastCheckedAtISO = ""
    @AppStorage("psy.youtube.lastCheckedAt") private var youtubeLastCheckedAtISO = ""
    @AppStorage("psy.soundcloud.lastCheckedAt") private var soundCloudLastCheckedAtISO = ""
    @AppStorage("psy.web.templates.lastCheckedAt") private var templateSyncLastCheckedAtISO = ""
    @AppStorage("psy.logistics.maps.lastCheckedAt") private var mapsLastCheckedAtISO = ""
    @AppStorage("psy.logistics.flight.lastCheckedAt") private var flightLastCheckedAtISO = ""
    @AppStorage("psy.logistics.flightProvider") private var logisticsFlightProvider = FlightProviderSelection.automatic.rawValue

    private let weeklyAlertPlanner = WeeklyInsightAlertPlanner()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(profile.stageName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("\(profile.genre) • \(profile.city), \(profile.state)")
                                .foregroundStyle(PsyTheme.textSecondary)
                            HStack(spacing: 10) {
                                PsyStatusPill(text: profile.artistStage, color: PsyTheme.primary)
                                PsyStatusPill(text: "Suporte 360°", color: PsyTheme.secondary)
                            }
                        }
                    }
                    .psyAppear()

                    accountSessionSection
                        .psyAppear(delay: 0.015)

                    webSyncHealthSection
                        .psyAppear(delay: 0.03)

                    PsyCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tom de voz")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(profile.toneOfVoice)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .psyAppear(delay: 0.06)

                    PsyCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Foco de conteúdo")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(profile.contentFocus)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .psyAppear(delay: 0.09)

                    PsyCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Identidade visual")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(profile.visualIdentity)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .psyAppear(delay: 0.12)

                    platformAPICredentialsSection
                        .psyAppear(delay: 0.15)

                    instagramInsightsSection
                        .psyAppear(delay: 0.18)
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Perfil")
            .animation(.easeInOut(duration: 0.2), value: snapshots.count)
            .animation(.easeInOut(duration: 0.2), value: instagramOAuthStatus)
            .sensoryFeedback(.success, trigger: templateSyncConnectionStatus)
            .sheet(isPresented: $showingInsightForm) {
                SocialInsightFormView { snapshot in
                    modelContext.insert(snapshot)
                    try? modelContext.save()
                }
            }
            .onAppear {
                PlatformAPISecrets.migrateLegacyUserDefaultsSecrets()
                spotifyToken = KeychainSecretStore.read(KeychainSecretStore.spotifyTokenKey) ?? ""
                youtubeApiKey = KeychainSecretStore.read(KeychainSecretStore.youtubeAPIKey) ?? ""
                soundCloudClientId = KeychainSecretStore.read(KeychainSecretStore.soundCloudClientIdKey) ?? ""
                googleMapsApiKey = KeychainSecretStore.read(KeychainSecretStore.googleMapsAPIKey) ?? ""
                rapidApiKey = KeychainSecretStore.read(KeychainSecretStore.rapidAPIKey) ?? ""
                skyscannerApiKey = KeychainSecretStore.read(KeychainSecretStore.skyscannerAPIKey) ?? ""
                kiwiTequilaApiKey = KeychainSecretStore.read(KeychainSecretStore.kiwiTequilaAPIKey) ?? ""
                webSyncAuthHeader = KeychainSecretStore.read(KeychainSecretStore.webSyncAuthHeaderKey) ?? ""
            }
            .onChange(of: spotifyToken) {
                persistSecret(spotifyToken, account: KeychainSecretStore.spotifyTokenKey)
            }
            .onChange(of: youtubeApiKey) {
                persistSecret(youtubeApiKey, account: KeychainSecretStore.youtubeAPIKey)
            }
            .onChange(of: soundCloudClientId) {
                persistSecret(soundCloudClientId, account: KeychainSecretStore.soundCloudClientIdKey)
            }
            .onChange(of: googleMapsApiKey) {
                persistSecret(googleMapsApiKey, account: KeychainSecretStore.googleMapsAPIKey)
            }
            .onChange(of: rapidApiKey) {
                persistSecret(rapidApiKey, account: KeychainSecretStore.rapidAPIKey)
            }
            .onChange(of: skyscannerApiKey) {
                persistSecret(skyscannerApiKey, account: KeychainSecretStore.skyscannerAPIKey)
            }
            .onChange(of: kiwiTequilaApiKey) {
                persistSecret(kiwiTequilaApiKey, account: KeychainSecretStore.kiwiTequilaAPIKey)
            }
            .onChange(of: webSyncAuthHeader) {
                persistSecret(webSyncAuthHeader, account: KeychainSecretStore.webSyncAuthHeaderKey)
            }
        }
    }

    private var webSyncHealthSection: some View {
        PsyCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Saúde da sincronização web")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    PsyStatusPill(
                        text: webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "URL pendente" : "URL configurada",
                        color: webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green
                    )
                    PsyStatusPill(
                        text: webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sessão pendente" : "Sessão ativa",
                        color: webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green
                    )
                    PsyStatusPill(
                        text: "Templates: \(templateSyncConnectionStatus)",
                        color: statusColor(for: templateSyncConnectionStatus)
                    )
                }

                Text(lastCheckedText(from: templateSyncLastCheckedAtISO))
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)

                if !templateSyncConnectionDetail.isEmpty {
                    Text(templateSyncConnectionDetail)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Text("Use \"Testar conexão de templates\" abaixo para validar URL/autorização e salvar diagnóstico.")
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)

                Divider()

                // Workspace sync button
                Button(action: syncWorkspace) {
                    HStack {
                        if isSyncingWorkspace { ProgressView().tint(.white).controlSize(.small) }
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(isSyncingWorkspace ? "Sincronizando..." : "Sincronizar tudo (App ↔ Web)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PsyTheme.primary)
                .disabled(isSyncingWorkspace || webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !workspaceSyncFeedback.isEmpty {
                    Text(workspaceSyncFeedback)
                        .font(.caption)
                        .foregroundStyle(workspaceSyncFeedback.starts(with: "✅") ? .green : .red)
                }

                if webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Faça login para habilitar sincronização completa com sua conta web.")
                        .font(.caption2)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
            }
        }
    }

    private var accountSessionSection: some View {
        PsyCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Conta conectada")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(PlatformAPISecrets.authUserName ?? profile.stageName)
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.textSecondary)
                        Text(PlatformAPISecrets.authUserEmail ?? "Email não disponível")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    Spacer()
                    Button("Sair") {
                        logoutFromApp()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }

    private var instagramInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Instagram", title: "Insights e crescimento")

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(connectionTitle)
                            .foregroundStyle(.white)
                        Spacer()
                        Button(instagramConnectedMock ? "Desconectar" : connectButtonTitle) {
                            handleConnectionButton()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)
                        .accessibilityLabel(instagramConnectedMock ? "Desconectar Instagram" : "Conectar Instagram")
                        .accessibilityHint("Abre ou encerra a sessão de integração do Instagram")
                    }

                    HStack(spacing: 8) {
                        PsyStatusPill(text: connectionPillText, color: connectionPillColor)
                        PsyStatusPill(text: backendConfigured ? "Backend pronto" : "Backend pendente", color: backendConfigured ? PsyTheme.secondary : .orange)
                        PsyStatusPill(text: handleConfigured ? "Handle ok" : "Handle pendente", color: handleConfigured ? PsyTheme.primary : .orange)
                    }

                    if let lastConnectedDescription {
                        Text(lastConnectedDescription)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }

                    if let lastSyncDescription {
                        Text(lastSyncDescription)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }

                    if !instagramOAuthErrorMessage.isEmpty {
                        Text(instagramOAuthErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Handle artístico (sem @)", text: $artistInstagramHandle)
                        .textFieldStyle(.roundedBorder)

                    TextField("URL do backend de insights", text: $backendURL)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Sincronizar insights") {
                            syncFromBackend()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.secondary)
                        .disabled(backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || artistInstagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || syncingInsights)
                        .accessibilityHint("Busca novos insights no backend configurado")

                        if syncingInsights {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView()
                                    .tint(PsyTheme.primary)
                                PsySkeletonLine(width: 120)
                            }
                        }
                    }

                    if !syncFeedback.isEmpty {
                        Text(syncFeedback)
                            .font(.caption)
                            .foregroundStyle(syncFeedbackHasError ? .red : PsyTheme.primary)
                    }

                    Toggle("Alertas semanais de crescimento", isOn: $weeklyInsightAlertsEnabled)
                        .tint(PsyTheme.primary)
                        .onChange(of: weeklyInsightAlertsEnabled) {
                            configureWeeklyAlerts(enabled: weeklyInsightAlertsEnabled)
                        }

                    Text(InstagramConnectionGuide.note)
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)

                    ForEach(InstagramConnectionGuide.requirements, id: \.self) { requirement in
                        Text("• \(requirement)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Snapshots de performance")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Adicionar") {
                            showingInsightForm = true
                        }
                        .buttonStyle(.bordered)
                    }

                    if snapshots.isEmpty {
                        Text("Sem snapshots ainda. Adicione dados da semana/mês para receber recomendações automáticas.")
                            .foregroundStyle(PsyTheme.textSecondary)
                    } else {
                        Chart {
                            ForEach(Array(snapshots.prefix(6).reversed()), id: \.persistentModelID) { item in
                                LineMark(
                                    x: .value("Período", item.periodLabel),
                                    y: .value("Seguidores", item.followersEnd)
                                )
                                .foregroundStyle(PsyTheme.primary)

                                BarMark(
                                    x: .value("Período", item.periodLabel),
                                    y: .value("Alcance", item.reach)
                                )
                                .foregroundStyle(PsyTheme.secondary.opacity(0.35))
                            }
                        }
                        .frame(height: 180)
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recomendações automáticas")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(InstagramInsightsAdvisor.recommendations(from: snapshots)) { recommendation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(recommendation.title) [\(recommendation.priority)]")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text(recommendation.detail)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Plano da próxima semana")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(InstagramInsightsAdvisor.weeklyActions(from: snapshots), id: \.self) { action in
                        Text("• \(action)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var platformAPICredentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Integrations", title: "Credenciais de APIs")

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Configure para habilitar coleta real de Spotify, YouTube e SoundCloud.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAdvancedIntegrations.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showAdvancedIntegrations ? "Ocultar configurações avançadas" : "Mostrar configurações avançadas")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: showAdvancedIntegrations ? "chevron.up" : "chevron.down")
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if !showAdvancedIntegrations {
                        Text("Visão limpa ativa: credenciais e testes avançados estão minimizados.")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }

                    if showAdvancedIntegrations {
                        SecureField("Spotify Bearer Token", text: $spotifyToken)
                            .textFieldStyle(.roundedBorder)

                    SecureField("YouTube API Key", text: $youtubeApiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("SoundCloud Client ID", text: $soundCloudClientId)
                        .textFieldStyle(.roundedBorder)

                    Divider()

                    Text("Logística e passagens")
                        .font(.headline)
                        .foregroundStyle(.white)

                    SecureField("Google Maps API Key (opcional)", text: $googleMapsApiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Kiwi/Tequila API Key (free tier)", text: $kiwiTequilaApiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("RapidAPI Key", text: $rapidApiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Skyscanner API Key (opcional)", text: $skyscannerApiKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("RapidAPI Host", text: $rapidApiHost)
                        .textFieldStyle(.roundedBorder)

                    Divider()

                    Text("Sync web-app")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Base URL do web (ex: https://web-app-eight-hazel.vercel.app)", text: $webSyncBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Token de sessão (automático via login)", text: $webSyncAuthHeader)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    HStack(spacing: 8) {
                        PsyStatusPill(
                            text: webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Web URL pendente" : "Web URL ok",
                            color: webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green
                        )
                        PsyStatusPill(
                            text: webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Login pendente" : "Sessão autenticada",
                            color: webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .green
                        )
                    }

                    Button {
                        Task { await testTemplateSyncConnection() }
                    } label: {
                        if testingTemplateSyncConnection {
                            ProgressView()
                        } else {
                            Text("Testar conexão de templates")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.secondary)
                    .disabled(testingTemplateSyncConnection || webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Picker("Provedor de voo", selection: $logisticsFlightProvider) {
                        ForEach(FlightProviderSelection.allCases) { provider in
                            Text(provider.label).tag(provider.rawValue)
                        }
                    }

                    TextField("Instagram Handle", text: Binding(
                        get: { profile.instagramHandle },
                        set: {
                            profile.instagramHandle = $0
                            try? modelContext.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    TextField("Spotify Artist Handle", text: Binding(
                        get: { profile.spotifyHandle },
                        set: {
                            profile.spotifyHandle = $0
                            try? modelContext.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    TextField("SoundCloud Handle", text: Binding(
                        get: { profile.soundCloudHandle },
                        set: {
                            profile.soundCloudHandle = $0
                            try? modelContext.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    TextField("YouTube Handle", text: Binding(
                        get: { profile.youTubeHandle },
                        set: {
                            profile.youTubeHandle = $0
                            try? modelContext.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        PsyStatusPill(text: spotifyToken.isEmpty ? "Spotify: mock" : "Spotify: live", color: spotifyToken.isEmpty ? .orange : .green)
                        PsyStatusPill(text: youtubeApiKey.isEmpty ? "YouTube: mock" : "YouTube: live", color: youtubeApiKey.isEmpty ? .orange : .green)
                        PsyStatusPill(text: soundCloudClientId.isEmpty ? "SoundCloud: mock" : "SoundCloud: live", color: soundCloudClientId.isEmpty ? .orange : .green)
                    }

                    HStack(spacing: 8) {
                        PsyStatusPill(text: googleMapsApiKey.isEmpty ? "Maps: mock" : "Maps: live", color: googleMapsApiKey.isEmpty ? .orange : .green)
                        PsyStatusPill(
                            text: (kiwiTequilaApiKey.isEmpty && rapidApiKey.isEmpty) ? "Voos: mock" : "Voos: live",
                            color: (kiwiTequilaApiKey.isEmpty && rapidApiKey.isEmpty) ? .orange : .green
                        )
                    }

                    HStack(spacing: 8) {
                        PsyStatusPill(text: "Maps: \(mapsConnectionStatus)", color: statusColor(for: mapsConnectionStatus))
                        PsyStatusPill(text: "Voos: \(flightConnectionStatus)", color: statusColor(for: flightConnectionStatus))
                    }

                    HStack(spacing: 8) {
                        PsyStatusPill(text: "Spotify: \(spotifyConnectionStatus)", color: statusColor(for: spotifyConnectionStatus))
                        PsyStatusPill(text: "YouTube: \(youtubeConnectionStatus)", color: statusColor(for: youtubeConnectionStatus))
                        PsyStatusPill(text: "SoundCloud: \(soundCloudConnectionStatus)", color: statusColor(for: soundCloudConnectionStatus))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spotify: \(lastCheckedText(from: spotifyLastCheckedAtISO))")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !spotifyConnectionDetail.isEmpty {
                            Text("Detalhe Spotify: \(spotifyConnectionDetail)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        Text("YouTube: \(lastCheckedText(from: youtubeLastCheckedAtISO))")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !youtubeConnectionDetail.isEmpty {
                            Text("Detalhe YouTube: \(youtubeConnectionDetail)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        Text("SoundCloud: \(lastCheckedText(from: soundCloudLastCheckedAtISO))")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !soundCloudConnectionDetail.isEmpty {
                            Text("Detalhe SoundCloud: \(soundCloudConnectionDetail)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        Text("Maps: \(lastCheckedText(from: mapsLastCheckedAtISO))")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !mapsConnectionDetail.isEmpty {
                            Text("Detalhe Maps: \(mapsConnectionDetail)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        Text("Voos: \(lastCheckedText(from: flightLastCheckedAtISO))")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !flightConnectionDetail.isEmpty {
                            Text("Detalhe voos: \(flightConnectionDetail)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        Task { await testPlatformConnections() }
                    } label: {
                        if testingPlatformConnections {
                            ProgressView()
                        } else {
                            Text("Testar conexões")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.primary)
                    .disabled(testingPlatformConnections)

                    Button {
                        Task { await testLogisticsConnections() }
                    } label: {
                        if testingLogisticsConnections {
                            ProgressView()
                        } else {
                            Text("Testar APIs de logística")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.secondary)
                    .disabled(testingLogisticsConnections)

                        Text("Rotas usam OSRM grátis por padrão. Voos priorizam Kiwi/Tequila (free tier) e usam RapidAPI como fallback opcional. Credenciais sensíveis ficam no Keychain.")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var backendConfigured: Bool {
        !backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var handleConfigured: Bool {
        !artistInstagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var connectionTitle: String {
        if instagramConnectedMock {
            return "Instagram conectado"
        }
        if instagramOAuthStatus == "starting" {
            return "Conexão com Instagram em andamento"
        }
        return "Instagram ainda não conectado"
    }

    private var connectButtonTitle: String {
        instagramOAuthStatus == "starting" ? "Aguardando retorno" : "Conectar"
    }

    private var connectionPillText: String {
        switch instagramOAuthStatus {
        case "success":
            return "OAuth conectado"
        case "starting":
            return "OAuth iniciado"
        case "idle":
            return instagramConnectedMock ? "Sessão ativa" : "Desconectado"
        default:
            return "OAuth \(instagramOAuthStatus)"
        }
    }

    private var connectionPillColor: Color {
        switch instagramOAuthStatus {
        case "success":
            return .green
        case "starting":
            return .orange
        case "idle":
            return instagramConnectedMock ? PsyTheme.primary : .gray
        default:
            return .red
        }
    }

    private var lastConnectedDescription: String? {
        guard let date = isoDate(from: instagramLastConnectedAt) else { return nil }
        return "Última autenticação: \(relativeFormatter.localizedString(for: date, relativeTo: .now))"
    }

    private var lastSyncDescription: String? {
        guard let date = isoDate(from: instagramLastInsightsSyncAt) else { return nil }
        return "Última sincronização: \(relativeFormatter.localizedString(for: date, relativeTo: .now))"
    }

    private var syncFeedbackHasError: Bool {
        let lowered = syncFeedback.lowercased()
        return lowered.contains("não foi possível") || lowered.contains("falha") || lowered.contains("erro")
    }

    private func handleConnectionButton() {
        if instagramConnectedMock {
            instagramConnectedMock = false
            instagramOAuthStatus = "idle"
            instagramOAuthErrorMessage = ""
            instagramLastConnectedAt = ""
            return
        }

        guard let url = InstagramOAuthCoordinator.startURL(baseURL: backendURL, artistHandle: artistInstagramHandle) else {
            syncFeedback = "Preencha o backend e o handle artístico para iniciar a conexão."
            return
        }
        instagramOAuthStatus = "starting"
        instagramOAuthErrorMessage = ""
        syncFeedback = "Abrindo autenticação do Instagram..."
        openURL(url)
    }

    private func syncFromBackend() {
        syncingInsights = true
        syncFeedback = ""

        Task {
            do {
                let snapshots = try await InstagramInsightsBridge.sync(baseURL: backendURL, artistHandle: artistInstagramHandle)
                let formatter = ISO8601DateFormatter()
                var inserted = 0

                for item in snapshots {
                    guard let start = formatter.date(from: item.periodStartISO),
                          let end = formatter.date(from: item.periodEndISO)
                    else { continue }

                    modelContext.insert(SocialInsightSnapshot(
                        periodLabel: item.periodLabel,
                        periodStart: start,
                        periodEnd: end,
                        followersStart: item.followersStart,
                        followersEnd: item.followersEnd,
                        reach: item.reach,
                        impressions: item.impressions,
                        profileVisits: item.profileVisits,
                        reelViews: item.reelViews,
                        postsPublished: item.postsPublished,
                        source: "instagram-api"
                    ))
                    inserted += 1
                }

                try? modelContext.save()
                syncFeedback = inserted > 0 ? "\(inserted) insight(s) sincronizado(s) do backend." : "Nenhum insight novo encontrado."
                instagramLastInsightsSyncAt = ISO8601DateFormatter().string(from: .now)
                instagramOAuthErrorMessage = ""
                if weeklyInsightAlertsEnabled {
                    configureWeeklyAlerts(enabled: true)
                }
            } catch {
                syncFeedback = "Não foi possível sincronizar agora. Verifique URL e backend."
                instagramOAuthErrorMessage = error.localizedDescription
            }
            syncingInsights = false
        }
    }

    private func configureWeeklyAlerts(enabled: Bool) {
        Task {
            if enabled {
                let recommendation = InstagramInsightsAdvisor.recommendations(from: snapshots).first?.detail ?? "Revise seus insights da semana e ajuste a estratégia de conteúdo."
                try? await weeklyAlertPlanner.scheduleWeeklySummaryNotification(recommendation: recommendation)
            } else {
                weeklyAlertPlanner.removeWeeklySummaryNotification()
            }
        }
    }

    @MainActor
    private func testPlatformConnections() async {
        guard !testingPlatformConnections else { return }
        testingPlatformConnections = true
        defer { testingPlatformConnections = false }

        let handleSource = artistInstagramHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawHandle = handleSource.isEmpty ? profile.stageName : handleSource
        let handle = rawHandle.lowercased().replacingOccurrences(of: " ", with: "")

        let spotifyResult = await SpotifyAdapter().fetchInsights(handle: handle)
        spotifyConnectionStatus = mapStatus(isLive: spotifyResult.isLive, hasCredential: !spotifyToken.isEmpty)
        spotifyConnectionDetail = spotifyResult.isLive ? "" : (spotifyResult.errorDetail ?? "")
        spotifyLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())

        let youtubeResult = await YouTubeAdapter().fetchInsights(handle: handle)
        youtubeConnectionStatus = mapStatus(isLive: youtubeResult.isLive, hasCredential: !youtubeApiKey.isEmpty)
        youtubeConnectionDetail = youtubeResult.isLive ? "" : (youtubeResult.errorDetail ?? "")
        youtubeLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())

        let soundCloudResult = await SoundCloudAdapter().fetchInsights(handle: handle)
        soundCloudConnectionStatus = mapStatus(isLive: soundCloudResult.isLive, hasCredential: !soundCloudClientId.isEmpty)
        soundCloudConnectionDetail = soundCloudResult.isLive ? "" : (soundCloudResult.errorDetail ?? "")
        soundCloudLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())
    }

    @MainActor
    private func testLogisticsConnections() async {
        guard !testingLogisticsConnections else { return }
        testingLogisticsConnections = true
        defer { testingLogisticsConnections = false }

        let mapsResult = await RealTimeLogisticsResolver.testMapsConnection()
        mapsConnectionStatus = mapsResult.label
        mapsConnectionDetail = mapsResult.detail
        mapsLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())

        let flightResult = await RealTimeLogisticsResolver.testFlightConnection()
        flightConnectionStatus = flightResult.label
        flightConnectionDetail = flightResult.detail
        flightLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())
    }

    @MainActor
    private func testTemplateSyncConnection() async {
        guard !testingTemplateSyncConnection else { return }
        testingTemplateSyncConnection = true
        defer { testingTemplateSyncConnection = false }

        templateSyncLastCheckedAtISO = ISO8601DateFormatter().string(from: Date())

        guard let baseURL = URL(string: webSyncBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            syncFeedback = "URL do web inválida para sync de templates."
            templateSyncConnectionStatus = "Falhou"
            templateSyncConnectionDetail = "URL inválida"
            return
        }

        let header = webSyncAuthHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = baseURL.appendingPathComponent("api/templates")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !header.isEmpty {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                syncFeedback = "Falha no sync de templates. Verifique base URL e autenticação."
                                templateSyncConnectionStatus = "Falhou"
                                templateSyncConnectionDetail = "Status HTTP inválido"
                return
            }

            let templatesCount: Int = {
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let templates = json["templates"] as? [[String: Any]] else {
                    return 0
                }
                return templates.count
            }()

            syncFeedback = "Sync templates OK. Endpoint respondeu com \(templatesCount) template(s)."
            templateSyncConnectionStatus = "Conectado"
            templateSyncConnectionDetail = ""
        } catch {
            syncFeedback = "Falha no sync de templates. Verifique base URL e autenticação."
            templateSyncConnectionStatus = "Falhou"
            templateSyncConnectionDetail = error.localizedDescription
        }
    }

    private func mapStatus(isLive: Bool, hasCredential: Bool) -> String {
        if isLive { return "Conectado" }
        return hasCredential ? "Falhou" : "Sem chave"
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Conectado":
            return .green
        case "Falhou":
            return .red
        case "Sem chave":
            return .orange
        default:
            return .gray
        }
    }

    private func lastCheckedText(from isoValue: String) -> String {
        let date = ISO8601DateFormatter().date(from: isoValue)
        guard let date else { return "Último teste: nunca" }
        return "Último teste: \(relativeFormatter.localizedString(for: date, relativeTo: .now))"
    }

    private func isoDate(from rawValue: String) -> Date? {
        guard !rawValue.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: rawValue)
    }

    private func persistSecret(_ value: String, account: String) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeychainSecretStore.delete(account)
        } else {
            KeychainSecretStore.write(value, account: account)
        }
    }

    private func logoutFromApp() {
        Task { @MainActor in
            await WebAuthService.shared.logout()
            isLoggedIn = false
            authSessionNonce = Date().timeIntervalSince1970
        }
    }

    private func syncWorkspace() {
        isSyncingWorkspace = true
        workspaceSyncFeedback = ""

        Task {
            let syncService = MobileSyncService()

            let learnedFactsRaw = UserDefaults.standard.string(forKey: "manager.learnedFacts.store") ?? ""
            let learnedFacts = learnedFactsRaw
                .components(separatedBy: "|||")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let pushPayload = await MainActor.run {
                MobileSyncService.buildPayload(
                    gigs: gigs,
                    leads: leads,
                    promoters: promoters,
                    templates: messageTemplates,
                    tripPlans: tripPlans,
                    contentPlan: contentPlan,
                    expenses: expenses,
                    learnedFacts: learnedFacts,
                    profile: profile
                )
            }

            do {
                try await syncService.pushWorkspace(payload: pushPayload)

                let remote = try await syncService.pullWorkspace()
                let mergedFacts = await MainActor.run {
                    MobileSyncService.mergeWorkspace(
                        remote: remote,
                        localGigs: gigs,
                        localLeads: leads,
                        localPromoters: promoters,
                        localTemplates: messageTemplates,
                        localTripPlans: tripPlans,
                        localContentPlan: contentPlan,
                        localExpenses: expenses,
                        context: modelContext
                    )
                }

                if !mergedFacts.isEmpty {
                    UserDefaults.standard.set(mergedFacts.joined(separator: "|||"), forKey: "manager.learnedFacts.store")
                }

                workspaceSyncFeedback = "✅ Sincronização bidirecional concluída com sucesso."
            } catch {
                workspaceSyncFeedback = "❌ \(error.localizedDescription)"
            }

            isSyncingWorkspace = false
        }
    }

    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }
}

private struct SocialInsightFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var periodLabel = "Semana atual"
    @State private var followersStart = "1200"
    @State private var followersEnd = "1248"
    @State private var reach = "6800"
    @State private var impressions = "11000"
    @State private var profileVisits = "530"
    @State private var reelViews = "4200"
    @State private var postsPublished = "4"
    @State private var periodStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .now
    @State private var periodEnd = Date()

    let onSave: (SocialInsightSnapshot) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Rótulo", text: $periodLabel)
                DatePicker("Início", selection: $periodStart, displayedComponents: [.date])
                DatePicker("Fim", selection: $periodEnd, displayedComponents: [.date])
                TextField("Seguidores início", text: $followersStart)
                    .keyboardType(.numberPad)
                TextField("Seguidores fim", text: $followersEnd)
                    .keyboardType(.numberPad)
                TextField("Reach", text: $reach)
                    .keyboardType(.numberPad)
                TextField("Impressions", text: $impressions)
                    .keyboardType(.numberPad)
                TextField("Visitas perfil", text: $profileVisits)
                    .keyboardType(.numberPad)
                TextField("Views de reels", text: $reelViews)
                    .keyboardType(.numberPad)
                TextField("Posts publicados", text: $postsPublished)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Novo insight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(SocialInsightSnapshot(
                            periodLabel: periodLabel,
                            periodStart: periodStart,
                            periodEnd: periodEnd,
                            followersStart: Int(followersStart) ?? 0,
                            followersEnd: Int(followersEnd) ?? 0,
                            reach: Int(reach) ?? 0,
                            impressions: Int(impressions) ?? 0,
                            profileVisits: Int(profileVisits) ?? 0,
                            reelViews: Int(reelViews) ?? 0,
                            postsPublished: Int(postsPublished) ?? 0
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}
