import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var taskVM: TaskViewModel
    
    @State private var title = ""
    @State private var desc = ""
    @State private var showEmptyTitleAlert = false
    
    // Only a date picker, no time
    @State private var selectedDay = Date()
    
    private let defaultStatus = ""
    
    var body: some View {
        NavigationView {
            Form {
                // TITLE & DESCRIPTION
                Section {
                    TextField("Enter title...", text: $title)
                    
                    TextEditor(text: $desc)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // ONLY PICK A DAY
                Section(header: Text("Day")) {
                    DatePicker(
                        "Select Day",
                        selection: $selectedDay,
                        in: Date()...,      // or remove if past is allowed
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationBarTitle("New Task", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addTask()
                    }
                }
            }
            .alert("No Title", isPresented: $showEmptyTitleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add a title for your task.")
            }
        }
    }
    
    // MARK: - Add Task
    private func addTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showEmptyTitleAlert = true
            return
        }
        
        // Convert user-chosen date to local midnight
        var calendar = Calendar.current
        calendar.timeZone = .current
        let midnightDate = calendar.startOfDay(for: selectedDay)
        
        // 1) Create the new task
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.desc  = desc
        newTask.status = defaultStatus
        
        // Store only local midnight in startTime
        newTask.startTime = midnightDate
        
        // 2) If it’s unassigned by default, set priorityRank = 3
        newTask.priorityRank   = 3
        newTask.prioritySymbol = ""
        
        do {
            // 3) Fetch all tasks where priorityRank == 3
            let fetch = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
            fetch.predicate = NSPredicate(format: "priorityRank == 3")
            
            let unpinnedTasks = try viewContext.fetch(fetch)
            // 4) The highest sortIndex among unpinned tasks
            let maxIndex = unpinnedTasks.map { $0.sortIndex }.max() ?? 0
            
            // 5) Place new task at the end
            newTask.sortIndex = maxIndex + 1
            
            // 6) Save and refresh
            try viewContext.save()
            CalendarService.shared.addEvent(for: newTask, in: viewContext)
            taskVM.fetchTasks()
            
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
}
