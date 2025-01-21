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
            .animation(.default, value: tasks.map(\.priorityRank))
            .listStyle(.plain)
            
            GeometryReader { proxy in
                List {
                    // Your list of tasks
                }
                Button {
                    showingAddSheet.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                }
                .position(x: 60, y: proxy.size.height - 100)
            }
            
            .padding(.vertical)
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
