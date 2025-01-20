import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Sort by priorityRank first (so !, !!, !!! are top 3), then by sortIndex.
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
            List {
                ForEach(tasks) { task in
                    TaskRowCompact(
                        task: task,
                        allTasks: Array(tasks)
                    ) { tappedTask in
                        selectedTask = tappedTask
                    }
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)
            }
            // The key: re-animate if priorityRank changes
            .animation(.default, value: tasks.map(\.priorityRank))
            .listStyle(.plain)

            // Add New Task button
            Button("Add New Task") {
                showingAddSheet.toggle()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        // Sheets for adding/editing tasks
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        .toolbar {
            EditButton() // swipe-to-delete and reordering
        }
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var updated = Array(tasks)
        updated.move(fromOffsets: source, toOffset: destination)
        
        // Reassign sortIndex in new order
        for (newIndex, t) in updated.enumerated() {
            t.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}
