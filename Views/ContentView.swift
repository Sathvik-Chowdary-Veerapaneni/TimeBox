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
    @State private var showCalendar = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // TOP BAR FOR ICONS
                HStack {
                    // Calendar icon
                    Button {
                        showCalendar.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 28))
                            .padding(.leading, 16)
                    }
                    
                    Spacer()
                    
                    // Profile icon
                    Button {
                        showProfileSheet.toggle()
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 35))
                            .padding(.trailing, 16)
                    }
                }
                .frame(height: 48)
                .padding(.top, 8)
                
                Divider() // a thin line under the icons
                
                // MAIN TASK LIST
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
                
                // BOTTOM BAR FOR PLUS BUTTON
                HStack {
                    Button {
                        showingAddSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .padding(.leading, 16)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .navigationBarHidden(true) // Hide the default navigation bar
        }
        // Show the calendar sheet
        .sheet(isPresented: $showCalendar) {
            CalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
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
        // Built-in toolbar for edit/move mode, if desired
        .toolbar {
            EditButton()
        }
    }
    
    // MARK: - Helper Methods
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach { task in
            // Also delete from Calendar if needed
            CalendarService.shared.deleteEvent(for: task, in: viewContext)
            viewContext.delete(task)
        }
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
