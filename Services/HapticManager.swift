// HapticManager.swift

import UIKit

struct HapticManager {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func successNotification() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warningNotification() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
