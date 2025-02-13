import SwiftUI
import CoreData

class TaskViewModel: ObservableObject {
    @Published var tasks: [TimeBox_Task] = []
    @Published var showCongratsBanner = false
    @Published var congratsMessage = ""
    
    // Keep context private to enforce clean architecture
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        // If you want only “today’s tasks,” you could call fetchTodayTasks() here
    }
    
    // MARK: - Fetch Methods
    
    // (A) Generic fetch
    // In TaskViewModel.swift
    func fetchTasks() {
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.sortDescriptors = [
            NSSortDescriptor(key: "priorityRank", ascending: true),
            NSSortDescriptor(key: "sortIndex",    ascending: true)
        ]
        do {
            tasks = try context.fetch(request)
            
            // NEW: move "Done" tasks to the bottom
            tasks.sort {
                let isDoneA = ($0.status == "Done")
                let isDoneB = ($1.status == "Done")
                
                // If one is Done and the other is not, Done goes last
                if isDoneA != isDoneB {
                    return !isDoneA
                }
                // Otherwise, keep priorityRank & sortIndex ordering
                if $0.priorityRank != $1.priorityRank {
                    return $0.priorityRank < $1.priorityRank
                }
                return $0.sortIndex < $1.sortIndex
            }
        } catch {
            print("Error fetching tasks: \(error.localizedDescription)")
            tasks = []
        }
    }
    
    // (B) Today-only fetch
    func fetchTodayTasks() {
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfToday as CVarArg, endOfToday as CVarArg)
        ])
        request.sortDescriptors = [
            NSSortDescriptor(key: "priorityRank", ascending: true),
            NSSortDescriptor(key: "sortIndex",    ascending: true)
        ]
        
        do {
            tasks = try context.fetch(request)
            tasks.sort {
                        let isDoneA = ($0.status == "Done")
                        let isDoneB = ($1.status == "Done")
                        
                        // If one is Done and the other isn’t, Done goes last
                        if isDoneA != isDoneB {
                            return !isDoneA
                        }
                        // Otherwise compare priorityRank, then sortIndex
                        if $0.priorityRank != $1.priorityRank {
                            return $0.priorityRank < $1.priorityRank
                        }
                        return $0.sortIndex < $1.sortIndex
                    }
        } catch {
            print("Error fetching today’s tasks: \(error.localizedDescription)")
            tasks = []
        }
    }
    
    // MARK: - Core Data Saves
    
    func saveChanges() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Task Updates
    
    func setTaskStatus(_ task: TimeBox_Task, to newStatus: String) {
        let oldStatus = task.status ?? ""
        withAnimation {
            task.status = newStatus
            
            // Record time if going InProgress
            if oldStatus != "InProgress" && newStatus == "InProgress" {
                task.inProgressStartTime = Date()
            }
            
            // If transitioning from InProgress -> Done, check elapsed time
            if oldStatus == "InProgress" && newStatus == "Done" {
                if let startTime = task.inProgressStartTime {
                    let elapsed = Date().timeIntervalSince(startTime) / 3600.0
                    if elapsed >= task.timeAllocated {
                        showCongratsBanner = true
                        congratsMessage = "Great job completing '\(task.title ?? "Untitled")'!"
                    }
                }
            }
            
            if newStatus == "Done" {
                HapticManager.successNotification()
                
            }
            
            saveChanges()
            fetchTodayTasks()
        }
    }
    
    func updatePriority(_ task: TimeBox_Task, to symbol: String) {
        let priorityMap: [String: Int16] = ["!": 0, "!!": 1, "!!!": 2, "": 3]
        let newRank = priorityMap[symbol] ?? 3
        
        withAnimation {
            task.prioritySymbol = symbol
            task.priorityRank   = newRank
            saveChanges()
            fetchTodayTasks()
        }
    }
    
    func deleteTask(_ task: TimeBox_Task) {
        context.delete(task)
        saveChanges()
        fetchTodayTasks()
    }
    
    // Reorder tasks while keeping pinned tasks (!, !!, !!!) at top
    func moveTasks(from source: IndexSet, to destination: Int) {
        var pinned = tasks.filter { $0.priorityRank < 3 }
        pinned.sort {
            if $0.priorityRank == $1.priorityRank {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.priorityRank < $1.priorityRank
        }
        
        var unpinned = tasks.filter { $0.priorityRank == 3 }
        unpinned.sort { $0.sortIndex < $1.sortIndex }
        
        let pinnedCount = pinned.count
        
        // Ignore any drag crossing pinned/unpinned boundary
        guard
            let firstSource = source.min(),
            firstSource >= pinnedCount,
            destination >= pinnedCount
        else { return }
        
        let unpinnedSource = source.map { $0 - pinnedCount }
        let unpinnedDestination = destination - pinnedCount
        
        unpinned.move(fromOffsets: IndexSet(unpinnedSource), toOffset: unpinnedDestination)
        
        let newOrder = pinned + unpinned
        for (i, task) in newOrder.enumerated() {
            task.sortIndex = Int16(i)
        }
        
        withAnimation {
            saveChanges()
            fetchTodayTasks()
        }
    }
    
    // MARK: - Reschedule for Drag & Drop in CalendarView
    // Public method that doesn't expose 'context'
    func rescheduleTask(with objectIDString: String, to newDate: Date) {
        guard let url = URL(string: objectIDString),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
        else {
            print("Invalid objectID string: \(objectIDString)")
            return
        }
        
        do {
            if let task = try context.existingObject(with: objectID) as? TimeBox_Task {
                // Keep previous hour/min if startTime was set
                if let oldDate = task.startTime {
                    var comps = Calendar.current.dateComponents([.hour, .minute], from: oldDate)
                    comps.year  = Calendar.current.component(.year,  from: newDate)
                    comps.month = Calendar.current.component(.month, from: newDate)
                    comps.day   = Calendar.current.component(.day,   from: newDate)
                    
                    if let newDateTime = Calendar.current.date(from: comps) {
                        task.startTime = newDateTime
                    } else {
                        task.startTime = Calendar.current.startOfDay(for: newDate)
                    }
                } else {
                    // If no old time, just set the new date
                    task.startTime = newDate
                }
                
                // Save
                try context.save()
            }
        } catch {
            print("Error rescheduling task: \(error.localizedDescription)")
        }
    }
}
