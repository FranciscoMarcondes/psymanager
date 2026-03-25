import SwiftUI

/// Reusable skeleton/placeholder animations for loading states
/// Mimics content layout while data loads
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        PsyTheme.surfaceAlt.opacity(0.5),
                        PsyTheme.surfaceAlt.opacity(0.8),
                        PsyTheme.surfaceAlt.opacity(0.5),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .if(width != nil) { view in
                view.frame(width: width)
            }
            .shimmering(isActive: true, speed: 0.6)
    }
}

/// Skeleton line - for text placeholders
struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    
    var body: some View {
        SkeletonView(width: width, height: height, cornerRadius: 6)
    }
}

/// Skeleton paragraph - multiple lines
struct SkeletonParagraph: View {
    var lineCount: Int = 3
    var spacing: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<lineCount, id: \.self) { index in
                SkeletonLine(width: index == lineCount - 1 ? 150 : nil)
            }
        }
    }
}

/// Skeleton card - for list items
struct SkeletonCard: View {
    var height: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonLine(height: 16)
            SkeletonParagraph(lineCount: 2)
            Spacer()
        }
        .padding(16)
        .frame(height: height)
        .background(PsyTheme.surfaceAlt.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Skeleton for Manager chat response
struct SkeletonChatMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonLine(width: 200)
            SkeletonLine()
            SkeletonLine(width: 240)
        }
        .padding(16)
        .background(PsyTheme.surfaceAlt.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Skeleton for event list item
struct SkeletonEventCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonLine(width: 180, height: 14)
                Spacer()
                SkeletonLine(width: 60, height: 14)
            }
            SkeletonLine(width: 200, height: 12)
            SkeletonLine(width: 150, height: 12)
        }
        .padding(16)
        .background(PsyTheme.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Skeleton for content form
struct SkeletonContentForm: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title field
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 80, height: 12)
                SkeletonLine()
            }
            
            // Content fields
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 120, height: 12)
                SkeletonParagraph(lineCount: 4)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                SkeletonLine()
                SkeletonLine()
            }
            .frame(height: 40)
        }
        .padding(16)
    }
}

// MARK: - Shimmer Modifier

extension View {
    /// Shimmer animation effect
    func shimmering(isActive: Bool, speed: CGFloat = 0.5) -> some View {
        modifier(ShimmerModifier(isActive: isActive, speed: speed))
    }
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    let speed: CGFloat
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0.6 : 1)
            .animation(
                isActive
                    ? Animation.linear(duration: 1.5 / speed)
                        .repeatForever(autoreverses: false)
                    : .default,
                value: isAnimating
            )
            .onAppear {
                if isActive {
                    isAnimating = true
                }
            }
    }
}

// MARK: - If Modifier Helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Skeleton Components")
                .font(.headline)
            
            SkeletonLine()
            SkeletonParagraph()
            SkeletonCard()
            SkeletonChatMessage()
            SkeletonEventCard()
            SkeletonContentForm()
        }
        .padding()
    }
    .background(PsyTheme.background)
}
