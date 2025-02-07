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
    
    // <<< ADDED: track the old desc to detect newlines
    @State private var oldDesc = ""
    
    var body: some View {
        NavigationView {
            Form {
                // TITLE & DESCRIPTION
                Section {
                    TextField("Enter title...", text: $title)
                    
                    TextEditor(text: $desc)
                        .frame(height: 80)
                        // <<< ADDED: Detect newline at the end
                        .onChange(of: desc) { newValue in
                            if newValue.count > oldDesc.count,      // typed something new
                               newValue.hasSuffix("\n") {           // ends with newline
                                desc += "- "                        // append dash+space
                            }
                            oldDesc = desc
                        }
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
                        in: Date()...,    // remove if you allow past
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
        var calendar = Calendar.current
        calendar.timeZone = .current
        let midnightDate = calendar.startOfDay(for: selectedDay)
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.desc  = desc
        newTask.status = defaultStatus
        newTask.startTime = midnightDate
        newTask.priorityRank   = 3
        newTask.prioritySymbol = ""
        
        do {
            let fetch = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
            fetch.predicate = NSPredicate(format: "priorityRank == 3")
            let unpinnedTasks = try viewContext.fetch(fetch)
            let maxIndex = unpinnedTasks.map { $0.sortIndex }.max() ?? 0
            newTask.sortIndex = maxIndex + 1
            try viewContext.save()
            CalendarService.shared.addEvent(for: newTask, in: viewContext)
            taskVM.fetchTasks()
            
            HapticManager.successNotification()
            
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
}
