import SwiftUI

@main
struct TimeBoxApp: App {
    let persistenceController = PersistenceController.shared
    
    // Create the TaskViewModel once, passing the Core Data context
    @StateObject private var taskVM: TaskViewModel
    
    init() {
        let context = persistenceController.container.viewContext
        _taskVM = StateObject(wrappedValue: TaskViewModel(context: context))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 1. Still provide the context, if needed
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // 2. Provide the TaskViewModel to the entire SwiftUI hierarchy
                .environmentObject(taskVM)
        }
    }
}
