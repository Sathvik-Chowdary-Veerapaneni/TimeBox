//
// CalendarView+Logic.swift
//

import SwiftUI
import CoreData

extension CalendarView {
    
    /// Build an array of days in the given month
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
    
    /// Fetch tasks for a single day
    func fetchTasks(for day: Date) -> [TimeBox_Task] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching tasks for day: \(error)")
            return []
        }
    }
    
    /// Fetch tasks for the entire month, and build `dailyTaskCounts`
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
            print("Error fetching monthly tasks: \(error)")
            dailyTaskCounts = [:]
        }
    }
    
    /// Overdue tasks: startTime < today & status != "Done"
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
            print("Error fetching backlog tasks: \(error)")
            return []
        }
    }

    // “Perform search” (≥3 chars)
    func performSearch(_ text: String) {
        guard text.count >= 3 else {
            searchResults = []
            return
        }
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "(title CONTAINS[cd] %@) OR (desc CONTAINS[cd] %@)",
            text, text
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeBox_Task.startTime, ascending: true)]
        
        do {
            let fetched = try viewContext.fetch(request)
            // Sort them: today -> future -> past
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            
            let todayMatches  = fetched.filter {
                if let st = $0.startTime { return Calendar.current.isDate(st, inSameDayAs: Date()) }
                return false
            }
            let futureMatches = fetched.filter { ($0.startTime ?? Date()) >= tomorrow }
            let pastMatches   = fetched.filter { ($0.startTime ?? Date()) < today }
            
            searchResults = todayMatches + futureMatches + pastMatches
        } catch {
            print("Error searching tasks:", error)
            searchResults = []
        }
    }
    
    // “Handle drop task” (drag & drop logic)
    func handleDropTask(_ objectIDString: String, day: Date) -> Bool {
        guard
            let url = URL(string: objectIDString),
            let objID = viewContext.persistentStoreCoordinator?
                .managedObjectID(forURIRepresentation: url),
            let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
        else { return false }
        
        // Block if "Done"
        if droppedTask.status == "Done" {
            showDoneAlert = true
            return false
        }
        
        // Disallow dropping on past
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let thisDay = Calendar.current.startOfDay(for: day)
        guard thisDay >= startOfToday else {
            print("DEBUG: Disallow drop on a past date.")
            return false
        }
        
        let oldDate = droppedTask.startTime
        // If old date was "today," remove from ContentView’s “today tasks”
        if let oldDate = oldDate, Calendar.current.isDate(oldDate, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // Actually reschedule
        taskVM.rescheduleTask(with: objectIDString, to: day)
        
        // If new date is "today," add to ContentView’s “today tasks”
        if Calendar.current.isDate(day, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // UI updates in selected day tasks
        if let oldDate = oldDate,
           Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
            tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
        }
        if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
            tasksForSelectedDate.append(droppedTask)
        }
        
        // Adjust dailyTaskCounts
        if let oldDate = oldDate {
            let oldKey = Calendar.current.startOfDay(for: oldDate)
            if dailyTaskCounts[oldKey] != nil {
                dailyTaskCounts[oldKey]! = max(0, dailyTaskCounts[oldKey]! - 1)
            }
        }
        let newKey = Calendar.current.startOfDay(for: day)
        dailyTaskCounts[newKey, default: 0] += 1
        
        // If backlog is showing, remove from backlog array
        if showBacklog {
            backlogTasks.removeAll { $0.objectID == droppedTask.objectID }
        }
        
        return true
    }
    
    // “Backlog tasks” or “day tasks” deletion
    func deleteBacklogTasks(at offsets: IndexSet) {
        for idx in offsets {
            let task = backlogTasks[idx]
            backlogTasks.remove(at: idx)
            taskVM.deleteTask(task)
        }
    }
    
    // Delete Tasks
    func deleteTasks(at offsets: IndexSet) {
        for idx in offsets {
            let task = tasksForSelectedDate[idx]
            tasksForSelectedDate.remove(at: idx)
            
            if let st = task.startTime {
                let dayKey = Calendar.current.startOfDay(for: st)
                dailyTaskCounts[dayKey] = max(0, (dailyTaskCounts[dayKey] ?? 0) - 1)
            }
            taskVM.deleteTask(task)
        }
    }
    
    // Format a month, e.g. "January 2025"
    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    // Format a date for display
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}


