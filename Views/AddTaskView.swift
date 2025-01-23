import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var taskVM: TaskViewModel
    
    @State private var title = ""
    @State private var desc = ""
    @State private var showEmptyTitleAlert = false
    
    @State private var selectedDay = Date()
    @State private var selectedHour = 12
    @State private var selectedMinute = 0
    @State private var selectedMeridiem = "AM"
    
    private let defaultStatus = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter title...", text: $title)
                    
                    TextEditor(text: $desc)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Section(header: Text("Day")) {
                    DatePicker(
                        "Select Day",
                        selection: $selectedDay,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                }
                
                Section(header: Text("Start Time")) {
                    HStack(spacing: 16) {
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(1..<13) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        let minuteSteps = stride(from: 0, through: 55, by: 5).map { $0 }
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(minuteSteps, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("AM/PM", selection: $selectedMeridiem) {
                            Text("AM").tag("AM")
                            Text("PM").tag("PM")
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 100)
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
    
    private func addTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showEmptyTitleAlert = true
            return
        }
        
        guard let finalDate = makeCombinedDate(
            day: selectedDay,
            hour12: selectedHour,
            minute: selectedMinute,
            meridiem: selectedMeridiem
        ) else {
            return
        }

        // 1) Create the new task
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.desc  = desc
        newTask.status = defaultStatus
        newTask.startTime = finalDate
        
        // 2) If it’s unassigned by default, set priorityRank = 3
        //    Then find the current max sortIndex among other unpinned tasks
        newTask.priorityRank = 3
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
            
            // 6) Save the context, update Calendar, then refresh TaskViewModel
            try viewContext.save()
            CalendarService.shared.addEvent(for: newTask, in: viewContext)
            taskVM.fetchTasks()
            
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
    
    private func makeCombinedDate(day: Date, hour12: Int, minute: Int, meridiem: String) -> Date? {
        var hour24 = hour12 % 12
        if meridiem == "PM" { hour24 += 12 }
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour24
        components.minute = minute
        
        return Calendar.current.date(from: components)
    }
}
