import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 1. Remove any @FetchRequest code from here
    // 2. Add an environmentObject ref to our TaskViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    
    // Keep your existing states
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
                    ForEach(taskVM.tasks) { task in
                        TaskRowCompact(
                            task: task,
                            allTasks: taskVM.tasks
                        ) { tappedTask in
                            selectedTask = tappedTask
                        }
                    }
                    // 3. Use taskVM for delete/move
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
    
    // MARK: - New Wrappers for TaskViewModel
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { taskVM.tasks[$0] }.forEach { task in
            taskVM.deleteTask(task)
        }
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        taskVM.moveTask(from: source, to: destination)
    }
}
