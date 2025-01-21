import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
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
    @State private var showProfileSheet = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main list of tasks
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
            .listStyle(.plain)
            
            // Profile button pinned top-right
            VStack {
                Button {
                    showProfileSheet.toggle()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40))
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
            }
        }
        .overlay(
            // Plus button pinned bottom-left
            VStack {
                Spacer()
                HStack {
                    Button {
                        showingAddSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        )
        // Sheet for tapped tasks
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        // Sheet to add a new task
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        // Sheet for profile settings
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
        .toolbar {
            EditButton()
        }
    }
    
    // MARK: - Helper Methods
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        var updated = Array(tasks)
        updated.move(fromOffsets: source, toOffset: destination)
        
        for (newIndex, task) in updated.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
