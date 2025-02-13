import Foundation
import CoreData

extension NSPredicate {
    static func todayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return NSPredicate(value: true)
        }

        return NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfToday as CVarArg, endOfToday as CVarArg
        )
    }
}
