import SwiftUI

enum PsyTheme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let surfaceAlt = Color(red: 0.13, green: 0.14, blue: 0.19)
    static let primary = Color(red: 0.35, green: 0.82, blue: 0.74)
    static let secondary = Color(red: 0.49, green: 0.64, blue: 0.98)
    static let accent = Color(red: 0.86, green: 0.39, blue: 0.70)
    static let warning = Color(red: 1.0, green: 0.71, blue: 0.16)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.78)

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.15, blue: 0.21), Color(red: 0.08, green: 0.09, blue: 0.14)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [surface, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct PsyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PsyTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

struct PsySectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(PsyTheme.primary)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(PsyTheme.textPrimary)
        }
    }
}

struct PsyStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// Hero card — gradient background, stronger visual presence
struct PsyHeroCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PsyTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PsyTheme.primary.opacity(0.18), lineWidth: 1)
            )
    }
}

// Chat bubble — user right/blue, manager left/teal
struct PsyChatBubble: View {
    let role: String
    let text: String

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 56) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "Você" : "Manager IA")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isUser ? PsyTheme.secondary : PsyTheme.primary)
                    .padding(.horizontal, 4)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? PsyTheme.secondary.opacity(0.18) : PsyTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isUser ? PsyTheme.secondary.opacity(0.3) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            }
            if !isUser { Spacer(minLength: 56) }
        }
    }
}

// Reusable subtle entrance animation for cards and sections.
struct PsyAppearModifier: ViewModifier {
    let delay: Double
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 8)
            .onAppear {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86).delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    func psyAppear(delay: Double = 0) -> some View {
        modifier(PsyAppearModifier(delay: delay))
    }
}

struct PsySkeletonLine: View {
    let width: CGFloat?

    init(width: CGFloat? = nil) {
        self.width = width
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: 12)
            .redacted(reason: .placeholder)
    }
}

struct PsyEmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        PsyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
        }
    }
}
