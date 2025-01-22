import SwiftUI
import CoreData

class TaskViewModel: ObservableObject {
    @Published var tasks: [TimeBox_Task] = []
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchTasks()
    }
    
    // Instead of a single NSSortDescriptor, we manually build pinned vs. unpinned
    func fetchTasks() {
        do {
            let all = try context.fetch(NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task"))
            
            // Separate pinned vs. unpinned
            var pinned = all.filter { $0.priorityRank < 3 }
            var unpinned = all.filter { $0.priorityRank == 3 }
            
            // Sort pinned by (priorityRank ASC, then sortIndex ASC)
            pinned.sort {
                if $0.priorityRank == $1.priorityRank {
                    return $0.sortIndex < $1.sortIndex
                }
                return $0.priorityRank < $1.priorityRank
            }
            
            // Sort unpinned by sortIndex
            unpinned.sort { $0.sortIndex < $1.sortIndex }
            
            // Combine: pinned on top, unpinned below
            tasks = pinned + unpinned
            
        } catch {
            print("Error fetching tasks: \(error.localizedDescription)")
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
    
    func deleteTask(_ task: TimeBox_Task) {
        context.delete(task)
        saveChanges()
        fetchTasks()
    }
    
    // Called by TaskRowCompact when user changes a task's priority symbol
    func updatePriority(_ task: TimeBox_Task, to symbol: String) {
        let priorityMap: [String: Int16] = ["!": 0, "!!": 1, "!!!": 2, "": 3]
        let newRank = priorityMap[symbol] ?? 3
        
        withAnimation {
            task.prioritySymbol = symbol
            task.priorityRank   = newRank
            saveChanges()
            fetchTasks()
        }
    }
    
    // Reordering logic for the unpinned region only
    func moveTasks(from source: IndexSet, to destination: Int) {
        // Rebuild pinned + unpinned from the current tasks array
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
        
        // If user drags from or to pinned region, ignore
        guard
            let firstSource = source.min(),
            firstSource >= pinnedCount,
            destination >= pinnedCount
        else {
            return
        }
        
        // Adjust offsets for unpinned sub-array
        let unpinnedSource = source.map { $0 - pinnedCount }
        let unpinnedDestination = destination - pinnedCount
        
        unpinned.move(fromOffsets: IndexSet(unpinnedSource), toOffset: unpinnedDestination)
        
        // Merge pinned + newly reordered unpinned
        let newOrder = pinned + unpinned
        
        // Update sortIndex
        for (i, task) in newOrder.enumerated() {
            task.sortIndex = Int16(i)
        }
        
        withAnimation {
            saveChanges()
            fetchTasks()
        }
    }
}
