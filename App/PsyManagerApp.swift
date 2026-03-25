import SwiftData
import SwiftUI

@main
struct PsyManagerApp: App {
    init() {
        PlatformAPISecrets.migrateLegacyUserDefaultsSecrets()
        if UserDefaults.standard.string(forKey: "psy.web.baseURL") == nil {
            UserDefaults.standard.set("https://web-app-eight-hazel.vercel.app", forKey: "psy.web.baseURL")
        }

        #if DEBUG
        let sanityFailures = CareerInsightAggregator.runDebugSanityChecks()
        if !sanityFailures.isEmpty {
            assertionFailure("CareerInsightAggregator sanity checks failed: \(sanityFailures.joined(separator: " | "))")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    // Handle deep links from other sources if needed
                    if WebAuthService.shared.canHandleMobileAuthCallback(url) {
                        Task {
                            do {
                                let user = try await WebAuthService.shared.completeMobileAuthCallback(url)
                                await MainActor.run {
                                    UserDefaults.standard.set(true, forKey: "psy.auth.isLoggedIn")
                                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "psy.auth.sessionNonce")
                                }
                                print("[DeepLink] OAuth completed: \(user.email)")
                            } catch {
                                print("[DeepLink] OAuth failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
        }
        .modelContainer(for: [
            ArtistProfile.self,
            ManagerChatMessage.self,
            MessageTemplate.self,
            SocialInsightSnapshot.self,
            SocialContentPlanItem.self,
            SocialContentAnalytics.self,
            PlatformInsight.self,
            ArtistCareerSnapshot.self,
            EventLead.self,
            PromoterContact.self,
            Negotiation.self,
            Gig.self,
            CareerTask.self,
            Expense.self,
            RadarEvent.self,
            TripPlan.self,
            Conversation.self,
        ])
    }
}