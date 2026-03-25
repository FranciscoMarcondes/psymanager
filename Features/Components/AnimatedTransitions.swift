import SwiftUI

/// Smooth animated transitions between content states
/// Reduces perceived loading time with visual continuity
struct AnimatedContentTransition<Content: View>: View {
    let isLoading: Bool
    let content: () -> Content
    var spacing: CGFloat = 12
    var animationDuration: Double = 0.3
    
    var body: some View {
        if isLoading {
            SkeletonCard()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            content()
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
        }
    }
}

/// Fade transition between two states
struct FadeTransition<Content: View>: View {
    let condition: Bool
    @ViewBuilder let trueContent: () -> Content
    @ViewBuilder let falseContent: () -> Content
    var duration: Double = 0.2
    
    var body: some View {
        ZStack {
            if condition {
                trueContent()
                    .transition(.opacity)
            } else {
                falseContent()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: duration), value: condition)
    }
}

/// Slide and fade transition
struct SlideTransition<Content: View>: View {
    let isVisible: Bool
    let content: () -> Content
    var edge: Edge = .top
    var duration: Double = 0.3
    
    var body: some View {
        if isVisible {
            content()
                .transition(.move(edge: edge).combined(with: .opacity))
        }
    }
}

/// Expandable section with smooth animation
struct ExpandableSection<Header: View, Content: View>: View {
    @State private var isExpanded = false
    let header: () -> Header
    let content: () -> Content
    var animationSpeed: Double = 0.3
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: animationSpeed)) {
                    isExpanded.toggle()
                    HapticFeedbackService.selectionChanged()
                }
            }) {
                HStack {
                    header()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Progressive list loading - show items as they arrive
struct ProgressiveList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    var isLoading: Bool = false
    var skeletonCount: Int = 3
    @State private var visibleItems = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Show skeleton for items still loading
            if isLoading {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    SkeletonCard(height: 80)
                }
            }
            
            // Show loaded items with staggered animation
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index < visibleItems {
                    content(item)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .onAppear {
                            // Stagger each item appearance
                            if isLoading && index == visibleItems - 1 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        if visibleItems < items.count {
                                            visibleItems += 1
                                        }
                                    }
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: items.count) { newCount in
            // Reset visible items when list changes
            withAnimation {
                visibleItems = newCount
            }
        }
        .onAppear {
            // Start progressive loading
            visibleItems = 0
            if !isLoading {
                withAnimation {
                    visibleItems = items.count
                }
            } else {
                loadItemsProgressively()
            }
        }
    }
    
    private func loadItemsProgressively() {
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if count < items.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    visibleItems = count + 1
                }
                count += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

/// Loading bar with progress
struct LoadingProgressBar: View {
    @Binding var progress: Double
    var height: CGFloat = 4
    var animationDuration: Double = 0.3
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(PsyTheme.surfaceAlt.opacity(0.3))
                
                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                PsyTheme.primary,
                                PsyTheme.primary.opacity(0.6)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
            }
            .frame(height: height)
        }
        .frame(height: height)
        .animation(.easeInOut(duration: animationDuration), value: progress)
    }
}

/// Floating action button with scale animation
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var scale: CGFloat = 1.0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.tapAction()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(PsyTheme.primary)
                        .shadow(color: PsyTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
        .scaleEffect(isPressed ? 0.95 : scale)
        .onLongPressGesture(minimumDuration: 0.01) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
        } onPressingChanged: { pressing in
            if !pressing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}

/// Smooth sheet transition with gesture handling
struct SmoothSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: () -> Content
    var cornerRadius: CGFloat = 20
    
    var body: some View {
        if isPresented {
            ZStack {
                // Dimming background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                // Sheet content
                VStack {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    content()
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .background(PsyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.easeInOut(duration: 0.3), value: isPresented)
        }
    }
}

// MARK: - Spring Animation Presets

extension Animation {
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.15)
    static let smoothEase = Animation.easeInOut(duration: 0.3)
}
