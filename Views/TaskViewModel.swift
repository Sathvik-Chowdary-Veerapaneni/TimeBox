import Foundation
import SwiftUI
import CoreData

class TaskViewModel: ObservableObject {
    @Published var tasks: [TimeBox_Task] = []
    
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchTasks() // Load tasks once at initialization
    }
    
    // MARK: - Fetching
    func fetchTasks() {
        let request: NSFetchRequest<TimeBox_Task> = TimeBox_Task.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TimeBox_Task.priorityRank, ascending: true),
            NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)
        ]
        
        do {
            tasks = try context.fetch(request)
        } catch {
            print("Error fetching tasks: \(error)")
            tasks = []
        }
    }
    
    // MARK: - Deleting
    func deleteTask(_ task: TimeBox_Task) {
        // Also remove from Apple Calendar, if integrated
        CalendarService.shared.deleteEvent(for: task, in: context)
        context.delete(task)
        saveContext()
        
        // Remove from the local array
        tasks.removeAll { $0.objectID == task.objectID }
    }
    
    // MARK: - Moving / Reordering
    func moveTask(from source: IndexSet, to destination: Int) {
        var updatedTasks = tasks
        updatedTasks.move(fromOffsets: source, toOffset: destination)
        
        for (newIndex, task) in updatedTasks.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        tasks = updatedTasks
        saveContext()
    }
    
    // MARK: - Saving
    func saveContext() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
