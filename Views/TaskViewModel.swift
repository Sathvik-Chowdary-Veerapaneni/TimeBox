import SwiftUI
import CoreData

class TaskViewModel: ObservableObject {
    @Published var tasks: [TimeBox_Task] = []
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        // If you always want to show only today's tasks in this VM,
        // call fetchTodayTasks() here. Otherwise, do so in your Home view.
    }
    
    // Regular fetch (unused if you're only focusing on today's tasks).
    func fetchTasks() {
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.sortDescriptors = [
            NSSortDescriptor(key: "priorityRank", ascending: true),
            NSSortDescriptor(key: "sortIndex",    ascending: true)
        ]
        do {
            tasks = try context.fetch(request)
        } catch {
            print("Error fetching tasks: \(error.localizedDescription)")
            tasks = []
        }
    }
    
    // **TODAY** fetch: excludes status="Postpone", and tasks whose startTime is outside today's range
    func fetchTodayTasks() {
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        
        // Exclude postponed tasks, and require startTime in [today..tomorrow)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "status != %@", "Postpone"),
            NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfToday as CVarArg, endOfToday as CVarArg)
        ])
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "priorityRank", ascending: true),
            NSSortDescriptor(key: "sortIndex",    ascending: true)
        ]
        
        do {
            tasks = try context.fetch(request)
        } catch {
            print("Error fetching today’s tasks: \(error.localizedDescription)")
            tasks = []
        }
    }
    
    func saveChanges() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
    
    func setTaskStatus(_ task: TimeBox_Task, to newStatus: String) {
        withAnimation {
            task.status = newStatus
            saveChanges()
            fetchTodayTasks()  // always refresh today's list
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
    
    // Reorder tasks while keeping pinned tasks on top
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
        
        // If user tries to drag from or into pinned region, ignore
        guard
            let firstSource = source.min(),
            firstSource >= pinnedCount,
            destination >= pinnedCount
        else {
            return
        }
        
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
}
