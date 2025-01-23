import Foundation
import CoreData

extension NSPredicate {
    static func todayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            // If something goes wrong, fallback
            return NSPredicate(value: true)
        }
        
        // Excluding "Postpone" status, plus requiring startTime in [today..tomorrow)
        return NSPredicate(
            format: "startTime >= %@ AND startTime < %@ AND status != %@",
            startOfToday as CVarArg, endOfToday as CVarArg, "Postpone"
        )
    }
}
