import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingAddSheet = false
    
    // Fetch tasks sorted by sortIndex (ascending)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    var body: some View {
        NavigationView {
            VStack {
                // Main list of tasks
                List {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                        
                            // Colorful background "card"
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                                    .padding(.vertical, 4)
                            )
                    }
                    // Enable drag-and-drop reordering
                    .onMove(perform: moveTasks)
                }
                
                // Add new task button at bottom
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
                .padding(.bottom, 8)
            }
            .navigationTitle("TimeBox")
            // Edit button to enable reorder mode
            .toolbar {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // Reorder handler for .onMove
    private func moveTasks(from source: IndexSet, to destination: Int) {
        // Convert FetchedResults to a mutable array
        var updatedTasks = tasks.map { $0 }
        
        // Move in-memory array
        updatedTasks.move(fromOffsets: source, toOffset: destination)
        
        // Update each task's sortIndex to its new position
        for (newIndex, task) in updatedTasks.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        
        // Save changes to Core Data
        do {
            try viewContext.save()
        } catch {
            print("Error saving reorder: \(error.localizedDescription)")
        }
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var title = ""
    @State private var status = "InProgress"
    @State private var priority = false
    @State private var timeAllocated = 0.0
    @State private var recurrenceDays = ""
    @State private var timestamp = Date()
    
    private let statusOptions = ["InProgress", "Done", "Postpone"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Priority", isOn: $priority)
                    
                    TextField("Time Allocated (hrs)",
                              value: $timeAllocated,
                              formatter: NumberFormatter())
                    
                    TextField("Recurrence Days", text: $recurrenceDays)
                    
                    DatePicker("Timestamp", selection: $timestamp, displayedComponents: .date)
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
        newTask.priority = priority
        newTask.timeAllocated = timeAllocated
        newTask.recurrenceDays = recurrenceDays
        newTask.timestamp = timestamp
        
        // Assign sortIndex to place new tasks at the bottom
        newTask.sortIndex = Int16((try? viewContext.count(for: TimeBox_Task.fetchRequest())) ?? 0)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving task: \(error.localizedDescription)")
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    @ObservedObject var task: TimeBox_Task
    @Environment(\.managedObjectContext) private var viewContext
    
    private let statusOptions = ["InProgress", "Done", "Postpone"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First line: title on left, status picker on right
            HStack {
                Text(task.title ?? "Untitled Task")
                    .font(.headline)

                Spacer()

                // Inline Status Picker (no label)
                Picker("", selection: Binding(
                    get: { task.status ?? "InProgress" },
                    set: { newValue in
                        task.status = newValue
                        saveChanges()
                    }
                )) {
                    ForEach(statusOptions, id: \.self) { option in
                        Text(option)
                    }
                }
                .pickerStyle(.menu)
            }

            // Second line: priority, time, date
            HStack {
                Text(task.priority ? "Priority" : "No Priority")
                    .font(.subheadline)
                Spacer()
                Text("\(task.timeAllocated, specifier: "%.1f") hrs")
                    .font(.subheadline)
                Spacer()
                if let date = task.timestamp {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func saveChanges() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving status: \(error.localizedDescription)")
        }
    }
}
