import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Fetch tasks by priority rank first, then sortIndex
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TimeBox_Task.priorityRank, ascending: true),
            NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)
        ],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    @State private var showingAddSheet = false
    @State private var selectedTask: TimeBox_Task? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Main list of tasks (already sorted by priority -> sortIndex)
            List {
                ForEach(tasks) { task in
                    TaskRowCompact(
                        task: task,
                        allTasks: Array(tasks), // pass entire array for priority checks
                        tapped: { tappedTask in
                            selectedTask = tappedTask
                        }
                    )
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)
            }
            .listStyle(.plain)

            // Add new task
            Button("Add New Task") {
                showingAddSheet.toggle()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(item: $selectedTask) { task in
            // The same popup you already have for editing descriptions/resolutions
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            // The same AddTaskView you already have
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        .toolbar {
            EditButton() // allows swipe-to-delete, reordering
        }
    }
    
    // Delete tasks
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    // Let the user reorder tasks that share the same priority rank
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var updated = Array(tasks)
        updated.move(fromOffsets: source, toOffset: destination)
        
        // Reassign sortIndex in the new order
        for (newIndex, t) in updated.enumerated() {
            t.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error.localizedDescription)")
        }
    }
}
