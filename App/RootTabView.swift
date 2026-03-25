import SwiftUI

enum RootTab: Hashable {
    case home
    case manager
    case events
    case creation
    case strategy
    case finances
    case profile
}

struct RootTabView: View {
    let profile: ArtistProfile
    @State private var selectedTab: RootTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(profile: profile) { target in
                selectedTab = target
            }
            .tag(RootTab.home)
            .tabItem {
                Label("Home", systemImage: "sparkles.rectangle.stack.fill")
            }

            ManagerView(profile: profile)
                .tag(RootTab.manager)
                .tabItem {
                    Label("Manager IA", systemImage: "brain.head.profile")
                }

            EventPipelineView()
                .tag(RootTab.events)
                .tabItem {
                    Label("Eventos", systemImage: "calendar.badge.clock")
                }

            CreationStudioView(profile: profile)
                .tag(RootTab.creation)
                .tabItem {
                    Label("Studio", systemImage: "camera.filters")
                }

            /* StrategyModuleView - Temporarily disabled, will be reenabled after build fix
            StrategyModuleView()
                .tag(RootTab.strategy)
                .tabItem {
                    Label("Estratégia", systemImage: "wand.and.sparkles")
                }
            */
            
            FinancesView()
                .tag(RootTab.finances)
                .tabItem {
                    Label("Finanças", systemImage: "chart.line.uptrend.xyaxis")
                }

            ProfileView(profile: profile)
                .tag(RootTab.profile)
                .tabItem {
                    Label("Perfil", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(PsyTheme.primary)
        .toolbarBackground(PsyTheme.surface.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .animation(.easeInOut(duration: 0.18), value: selectedTab)
    }
}
