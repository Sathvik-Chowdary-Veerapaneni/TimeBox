import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var status = ""
    @State private var timeAllocated = 0.0
    @State private var desc = ""
    
    private let statusOptions = ["InProgress", "Done", "Postpone"]
    private let hourOptions: [(String, Double)] = [
        ("15m", 0.25), ("30m", 0.5), ("1h", 1.0), ("2h", 2.0), ("3h", 3.0)
    ]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    
                    Picker("Time", selection: $timeAllocated) {
                        ForEach(hourOptions, id: \.0) { (label, value) in
                            Text(label).tag(value)
                        }
                    }

                    Picker("Status", selection: $status) {
                        Text("None").tag("")
                        ForEach(statusOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    
                    TextEditor(text: $desc)
                        .frame(height: 80)
                        .border(Color.secondary)
                }
            }
            .navigationTitle("New Task")
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
        }
    }
    
    private func addTask() {
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.status = status
        newTask.timeAllocated = timeAllocated
        newTask.desc = desc
        newTask.resolution = nil
        newTask.isInPriorityPool = false
        
        // Place it at the bottom of normal list
        newTask.sortIndex = Int16((try? viewContext.count(for: TimeBox_Task.fetchRequest())) ?? 0)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
}
