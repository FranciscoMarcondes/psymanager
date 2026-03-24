import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtistProfile.createdAt) private var profiles: [ArtistProfile]
    @AppStorage("instagramConnectedMock") private var instagramConnected = false
    @AppStorage("instagramOAuthStatus") private var instagramOAuthStatus = "idle"
    @AppStorage("artistInstagramHandle") private var artistInstagramHandle = ""
    @AppStorage("instagramOAuthErrorMessage") private var instagramOAuthErrorMessage = ""
    @AppStorage("instagramLastConnectedAt") private var instagramLastConnectedAt = ""

    var body: some View {
        Group {
            if let profile = profiles.first {
                RootTabView(profile: profile)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .task {
                        try? SampleDataSeeder.seedIfNeeded(in: modelContext)
                    }
            } else {
                OnboardingFlowView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.26), value: profiles.count)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.small ... .accessibility3)
        .onOpenURL { url in
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
}
