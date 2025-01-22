import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingAddSheet = false
    @State private var selectedTask: TimeBox_Task? = nil
    
    @State private var showCalendar = false
    @State private var showProfileSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // TOP BAR with Calendar & Profile icons
                HStack {
                    Button {
                        showCalendar.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .padding(.leading, 40)
                    }
                    
                    Spacer()
                    
                    Text("HOME")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        showProfileSheet.toggle()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .padding(.trailing, 40)
                    }
                }
                .padding(.vertical, 10)
                
                Divider()
                
                // MAIN TASK LIST
                List {
                    ForEach(taskVM.tasks, id: \.objectID) { task in
                        TaskRowCompact(
                            task: task,
                            allTasks: taskVM.tasks,
                            tapped: { tappedTask in
                                selectedTask = tappedTask
                            }
                        )
                    }
                    .onDelete(perform: deleteTasks)
                    .onMove(perform: moveTasks)
                }
                .listStyle(.plain)
                
                // BOTTOM + BUTTON
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
            .navigationBarHidden(true)
        }
        // SHEETS for Calendar, Profile, AddTask, and Task details
        .sheet(isPresented: $showCalendar) {
            CalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        // EDIT button for reordering/deleting
        .toolbar {
            EditButton()
        }
        // Fetch the latest tasks on appear
        .onAppear {
            taskVM.fetchTasks()
        }
    }
    
    // MARK: - Delete & Move
    
    private func deleteTasks(at offsets: IndexSet) {
        offsets.forEach { index in
            let task = taskVM.tasks[index]
            taskVM.deleteTask(task)
        }
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        taskVM.moveTasks(from: source, to: destination)
    }
}
