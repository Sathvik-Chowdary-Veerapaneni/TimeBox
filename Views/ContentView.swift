import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Tracks whether the sheet is presented
    @State private var showingAddSheet = false
    
    // Fetch existing tasks from Core Data
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TimeBox_Task.timestamp, ascending: false)],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    var body: some View {
        NavigationView {
            VStack {
                // List tasks on top
                List {
                    ForEach(tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title ?? "Untitled Task")
                                .font(.headline)
                            
                            Text("Status: \(task.status ?? "N/A")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Priority: \(task.priority ? "Yes" : "No")")
                                Spacer()
                                Text("Time: \(task.timeAllocated, specifier: "%.1f") hrs")
                            }
                            .font(.footnote)
                            
                            if let date = task.timestamp {
                                Text(date, style: .date)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Button at bottom to open a sheet
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
        }
        // Sheet with smaller form for creating a task
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

// MARK: - Add Task View (Simple Form)

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Minimal form fields
    @State private var title = ""
    @State private var status = ""
    @State private var priority = false
    @State private var timeAllocated = 0.0
    @State private var recurrenceDays = ""
    @State private var timestamp = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Status", text: $status)
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
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving task: \(error.localizedDescription)")
        }
    }
}
