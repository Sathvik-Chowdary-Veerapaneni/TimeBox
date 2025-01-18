import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Tracks which task was tapped (for the mini pop-up)
    @State private var selectedTask: TimeBox_Task? = nil
    
    // Fetch all tasks, sorted by sortIndex
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    @State private var showingAddSheet = false
    
    // Filter top priority tasks
    private var priorityTasks: [TimeBox_Task] {
        tasks.filter { $0.isInPriorityPool }
    }
    // Filter normal tasks
    private var normalTasks: [TimeBox_Task] {
        tasks.filter { !$0.isInPriorityPool }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1) Top Priorities container
            TopPrioritiesContainerView(priorityTasks: priorityTasks)
                .padding(.bottom, 8)
            
            // 2) Main list of normal tasks
            List {
                ForEach(normalTasks) { task in
                    HStack {
                        TaskRowCompact(task: task) { tappedTask in
                            selectedTask = tappedTask
                        }
                        Spacer()
                        // Move to top priority button
                        if priorityTasks.count < 3 {
                            Button("Add to Top") {
                                moveTaskToPriority(task)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .onMove(perform: moveTasks)
                .onDelete(perform: deleteTasks)
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
            
            // 3) "Add New Task" button
            Button(action: {
                showingAddSheet.toggle()
            }) {
                Text("Add New Task")
                    .font(.headline)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // Sheets
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        .toolbar {
            EditButton()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Move a task to top priority if there's room (< 3 tasks).
    private func moveTaskToPriority(_ task: TimeBox_Task) {
        if priorityTasks.count < 3 {
            task.isInPriorityPool = true
            saveContext()
        } else {
            print("Top priorities are full!")
        }
    }
    
    /// Reorder main-list tasks
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var updated = normalTasks
        updated.move(fromOffsets: source, toOffset: destination)
        
        for (newIndex, task) in updated.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { normalTasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}
