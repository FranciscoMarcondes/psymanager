import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtistProfile.createdAt) private var profiles: [ArtistProfile]
    @AppStorage("psy.auth.isLoggedIn") private var isLoggedIn = false
    @AppStorage("psy.auth.sessionNonce") private var authSessionNonce = 0.0
    @AppStorage("psy.auth.prefillArtistName") private var prefillArtistName = ""
    @AppStorage("psy.auth.lastError") private var lastAuthError = ""
    @AppStorage("seedDemoDataEnabled") private var seedDemoDataEnabled = false
    @AppStorage("instagramConnectedMock") private var instagramConnected = false
    @AppStorage("instagramOAuthStatus") private var instagramOAuthStatus = "idle"
    @AppStorage("artistInstagramHandle") private var artistInstagramHandle = ""
    @AppStorage("instagramOAuthErrorMessage") private var instagramOAuthErrorMessage = ""
    @AppStorage("instagramLastConnectedAt") private var instagramLastConnectedAt = ""

    var body: some View {
        Group {
            if !isLoggedIn {
                MobileLoginView()
                    .transition(.opacity.combined(with: .scale(scale: 1.01)))
            } else {
                if let profile = profiles.first {
                    RootTabView(profile: profile)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .task(id: authSessionNonce) {
                            if seedDemoDataEnabled {
                                try? SampleDataSeeder.seedIfNeeded(in: modelContext)
                            }

                            await pullWorkspaceIfConfigured()
                        }
                } else {
                    OnboardingFlowView()
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.26), value: profiles.count)
        .preferredColorScheme(.dark)
        .onAppear {
            let hasToken = !(PlatformAPISecrets.webSyncAuthHeader?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasUser = !(PlatformAPISecrets.authUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasToken || !hasUser {
                isLoggedIn = false
            }
        }
        .dynamicTypeSize(.small ... .accessibility3)
        .onOpenURL { url in
            if WebAuthService.shared.canHandleMobileAuthCallback(url) {
                Task { @MainActor in
                    do {
                        let user = try await WebAuthService.shared.completeMobileAuthCallback(url)
                        prefillArtistName = user.name
                        lastAuthError = ""
                        isLoggedIn = true
                        authSessionNonce = Date().timeIntervalSince1970
                    } catch {
                        isLoggedIn = false
                        lastAuthError = error.localizedDescription
                    }
                }
                return
            }

            guard let payload = InstagramOAuthCoordinator.parseCallback(url) else { return }
            let status = payload.status ?? "unknown"
            instagramOAuthStatus = status
            if payload.status == "success" {
                instagramConnected = true
                instagramOAuthErrorMessage = ""
                instagramLastConnectedAt = ISO8601DateFormatter().string(from: .now)
            } else {
                instagramConnected = false
                instagramOAuthErrorMessage = payload.errorDescription ?? "Falha ao autenticar com o Instagram."
            }
            if let handle = payload.handle, !handle.isEmpty {
                artistInstagramHandle = handle
            }
        }
    }

    @MainActor
    private func pullWorkspaceIfConfigured() async {
        let token = PlatformAPISecrets.webSyncAuthHeader?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else { return }

        let syncService = MobileSyncService()
        guard let remote = try? await syncService.pullWorkspace() else { return }

        let localGigs = (try? modelContext.fetch(FetchDescriptor<Gig>())) ?? []
        let localLeads = (try? modelContext.fetch(FetchDescriptor<EventLead>())) ?? []
        let localPromoters = (try? modelContext.fetch(FetchDescriptor<PromoterContact>())) ?? []
        let localTemplates = (try? modelContext.fetch(FetchDescriptor<MessageTemplate>())) ?? []
        let localTrips = (try? modelContext.fetch(FetchDescriptor<TripPlan>())) ?? []
        let localContent = (try? modelContext.fetch(FetchDescriptor<SocialContentPlanItem>())) ?? []
        let localExpenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []

        let facts = MobileSyncService.mergeWorkspace(
            remote: remote,
            localGigs: localGigs,
            localLeads: localLeads,
            localPromoters: localPromoters,
            localTemplates: localTemplates,
            localTripPlans: localTrips,
            localContentPlan: localContent,
            localExpenses: localExpenses,
            context: modelContext
        )

        if !facts.isEmpty {
            UserDefaults.standard.set(facts.joined(separator: "|||"), forKey: "manager.learnedFacts.store")
        }
    }
}
