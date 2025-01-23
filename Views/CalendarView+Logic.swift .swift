// CalendarView+Logic.swift

import SwiftUI
import CoreData

extension CalendarView {
    
    // Build an array of days in the given month
    func makeDaysInMonth(_ date: Date) -> [Date] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { return [] }
        var days: [Date] = []
        var current = interval.start
        while current < interval.end {
            days.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }
    
    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    func fetchTasks(for day: Date) -> [TimeBox_Task] {
        var localCalendar = Calendar.current
        localCalendar.timeZone = .current
        
        let startOfDay = localCalendar.startOfDay(for: day)
        guard let endOfDay = localCalendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        do {
            return try viewContext.fetch(request)
        } catch {
            print("DEBUG: Error fetching tasks for day:", error)
            return []
        }
    }
    
    func fetchMonthlyTaskCounts(for month: Date) {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            interval.start as CVarArg,
            interval.end as CVarArg
        )
        do {
            let tasks = try viewContext.fetch(request)
            var counts: [Date: Int] = [:]
            for t in tasks {
                if let st = t.startTime {
                    let dayOnly = Calendar.current.startOfDay(for: st)
                    counts[dayOnly, default: 0] += 1
                }
            }
            dailyTaskCounts = counts
        } catch {
            print("DEBUG: Error fetching monthly tasks:", error)
            dailyTaskCounts = [:]
        }
    }
    
    func fetchBacklogTasks() -> [TimeBox_Task] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime < %@ AND status != %@",
            todayStart as CVarArg, "Done"
        )
        do {
            return try viewContext.fetch(request)
        } catch {
            print("DEBUG: Error fetching backlog tasks:", error)
            return []
        }
    }
}
