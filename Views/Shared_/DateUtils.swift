import Foundation

enum DateUtils {
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static func formatMonth(_ date: Date) -> String {
        return monthFormatter.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        return mediumDateFormatter.string(from: date)
    }
}
