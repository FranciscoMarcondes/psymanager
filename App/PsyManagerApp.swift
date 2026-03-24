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