import SwiftUI
import CoreData

class TaskViewModel: ObservableObject {
    @Published var tasks: [TimeBox_Task] = []
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchTasks()
    }
    
    func fetchTasks() {
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        let sort = NSSortDescriptor(key: "sortIndex", ascending: true)
        request.sortDescriptors = [sort]
        do {
            tasks = try context.fetch(request)
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
    
    // 1) New function to support reordering tasks
    func moveTasks(from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        
        // Update sortIndex for the new order
        for (index, item) in reordered.enumerated() {
            item.sortIndex = Int16(index)
        }
        
        // Save to Core Data & refresh
        saveChanges()
        fetchTasks()
    }
}
