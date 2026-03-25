import UIKit
import SwiftUI

/// Haptic feedback service for tactile user feedback
/// Signals successful actions, errors, and interactions
struct HapticFeedbackService {
    
    // MARK: - Haptic Types
    
    enum HapticType {
        case success       // Soft double pulse - for positive actions
        case warning       // Single medium pulse - for warnings
        case error         // Triple heavy pulses - for errors
        case selection     // Light pulse - for selections
        case impact        // Heavy single pulse - for important actions
        case notification  // Varies with urgency
    }
    
    // MARK: - Core Feedback
    
    static func trigger(_ type: HapticType) {
        switch type {
        case .success:
            triggerSuccess()
        case .warning:
            triggerWarning()
        case .error:
            triggerError()
        case .selection:
            triggerSelection()
        case .impact:
            triggerImpact()
        case .notification:
            triggerNotification()
        }
    }
    
    private static func triggerSuccess() {
        let pattern = UIImpactFeedbackGenerator(style: .medium)
        pattern.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let pattern2 = UIImpactFeedbackGenerator(style: .light)
            pattern2.impactOccurred()
        }
    }
    
    private static func triggerWarning() {
        let pattern = UIImpactFeedbackGenerator(style: .medium)
        pattern.impactOccurred()
    }
    
    private static func triggerError() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                let pattern = UIImpactFeedbackGenerator(style: .heavy)
                pattern.impactOccurred()
            }
        }
    }
    
    private static func triggerSelection() {
        let pattern = UISelectionFeedbackGenerator()
        pattern.selectionChanged()
    }
    
    private static func triggerImpact() {
        let pattern = UIImpactFeedbackGenerator(style: .heavy)
        pattern.impactOccurred()
    }
    
    private static func triggerNotification() {
        let pattern = UINotificationFeedbackGenerator()
        pattern.notificationOccurred(.success)
    }
    
    // MARK: - Gesture Feedback
    
    /// Feedback for button tap
    static func tapAction() {
        trigger(.selection)
    }
    
    /// Feedback for successful save/creation
    static func savedSuccessfully() {
        trigger(.success)
    }
    
    /// Feedback for deletion
    static func deletedItem() {
        trigger(.impact)
    }
    
    /// Feedback for error
    static func failedAction() {
        trigger(.error)
    }
    
    /// Feedback for warning
    static func warningOccurred() {
        trigger(.warning)
    }
    
    /// Feedback for list/swipe action
    static func selectionChanged() {
        trigger(.selection)
    }
    
    /// Sequence of haptics for multi-step action
    static func multiStepSequence(steps: Int = 3) {
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                let pattern = UIImpactFeedbackGenerator(style: .light)
                pattern.impactOccurred()
            }
        }
    }
    
    /// Long press feedback
    static func longPressDetected() {
        let pattern = UIImpactFeedbackGenerator(style: .medium)
        pattern.impactOccurred()
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Add haptic feedback on tap
    func hapticTap(_ hapticType: HapticFeedbackService.HapticType = .selection) -> some View {
        self.contentShape(Rectangle())
            .onTapGesture {
                HapticFeedbackService.trigger(hapticType)
            }
    }
    
    /// Add haptic feedback to button
    func hapticButton(_ hapticType: HapticFeedbackService.HapticType = .selection) -> some View {
        modifier(HapticButtonModifier(hapticType: hapticType))
    }
}

private struct HapticButtonModifier: ViewModifier {
    let hapticType: HapticFeedbackService.HapticType
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                HapticFeedbackService.trigger(hapticType)
            }
    }
}
