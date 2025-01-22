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
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(taskVM)
        }
    }
}
