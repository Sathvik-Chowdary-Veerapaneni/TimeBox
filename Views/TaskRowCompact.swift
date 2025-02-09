import SwiftUI
import CoreData

struct TaskRowCompact: View {
    @ObservedObject var task: TimeBox_Task
    let allTasks: [TimeBox_Task]
    var tapped: (TimeBox_Task) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var taskVM: TaskViewModel
    
    // ...
    private let hourOptions: [(value: Double, label: String, iconName: String)] = [
        (0.25, "15m", "15.circle.fill"),
        (0.5,  "30m", "30.circle.fill"),
        (1.0,  "1h",  "1.circle.fill"),
        (2.0,  "2h",  "2.circle.fill"),
        (3.0,  "3h",  "3.circle.fill")
    ]
    private let orderedStatuses = ["InProgress", "Done", "Postpone"]
    private let statusInfo: [String: (iconName: String, color: Color, label: String)] = [
        "InProgress": ("clock.fill",     .blue,   "In Progress"),
        "Done":       ("checkmark.seal.fill", .green,  "Done"),
        "Postpone":   ("hourglass",      .orange, "Postpone")
    ]
    
    private let symbolsInOrder = ["!", "!!", "!!!"]
    
    // State for Postpone popup
    @State private var showPostponeSheet = false
    @State private var postponeDate = Date()
    @State private var postponeReason = ""
    @State private var showLimitAlert = false
    @State private var pendingInProgressTask: TimeBox_Task? = nil
    @State private var pendingDoneTask: TimeBox_Task? = nil
    @State private var showResolutionPopup = false
    @State private var showResolutionAlert = false


    var body: some View {
        HStack(spacing: 12) {
            Text(task.title ?? "Untitled")
                .font(.headline)
            
            Spacer()
            
            // PRIORITY MENU
            Menu {
                ForEach(symbolsInOrder, id: \.self) { symbol in
                    if canUse(symbol: symbol) {
                        Button(symbol) {
                            taskVM.updatePriority(task, to: symbol)
                        }
                    }
                }
                if !(task.prioritySymbol ?? "").isEmpty {
                    Button("Clear Priority") {
                        taskVM.updatePriority(task, to: "")
                    }
                }
            } label: {
                let currentSymbol = task.prioritySymbol ?? ""
                if currentSymbol.isEmpty {
                    Image(systemName: "p.circle")
                        .foregroundColor(.gray)
                } else {
                    Text(currentSymbol)
                        .foregroundColor(.orange)
                }
            }
            
            // HOURS MENU
            Menu {
                ForEach(hourOptions, id: \.value) { option in
                    Button {
                        task.timeAllocated = option.value
                        saveChanges()
                    } label: {
                        Label(option.label, systemImage: option.iconName)
                    }
                }
                Button("Clear Hours") {
                    task.timeAllocated = 0
                    saveChanges()
                }
            } label: {
                if task.timeAllocated == 0 {
                    Image(systemName: "questionmark.square")
                        .foregroundColor(.gray)
                } else if let match = hourOptions.first(where: { $0.value == task.timeAllocated }) {
                    Image(systemName: match.iconName)
                } else {
                    Image(systemName: "exclamationmark.square")
                        .foregroundColor(.red)
                }
            }
            
            // STATUS MENU
            Menu {
                Button {
                    let inProgCount = allTasks.filter { $0.status == "InProgress" }.count
                    if inProgCount >= 2 {
                        pendingInProgressTask = task
                        showLimitAlert = true
                    } else {
                        taskVM.setTaskStatus(task, to: "InProgress")
                    }
                } label: {
                    Label("In Progress", systemImage: "clock.fill")
                }
                
                Button {
                    let resolutionText = (task.resolution ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if resolutionText.isEmpty {
                        pendingDoneTask = task
                        showResolutionAlert = true
                    } else {
                        taskVM.setTaskStatus(task, to: "Done")
                    }
                } label: {
                    Label("Done", systemImage: "checkmark.seal.fill")
                }
                
                // "Postpone" -> open a sheet
                Button {
                    postponeDate = task.startTime ?? Date()
                    postponeReason = ""
                    showPostponeSheet = true
                } label: {
                    Label("Postpone", systemImage: "hourglass")
                }
                Button("Clear Status") {
                    taskVM.setTaskStatus(task, to: "")
                }
            } label: {
                let currentStatus = task.status ?? ""
                if currentStatus.isEmpty {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.gray)
                } else if let info = statusInfo[currentStatus] {
                    Image(systemName: info.iconName)
                        .foregroundColor(info.color)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        
        .alert("You Already Have Two Tasks in Progress",
               isPresented: $showLimitAlert) {
            Button("Proceed") {
                // Actually set the status if user confirms
                if let t = pendingInProgressTask {
                    taskVM.setTaskStatus(t, to: "InProgress")
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Not recommended more than 2 tasks")
        }
        
        .alert("Resolution Required", isPresented: $showResolutionAlert) {
            Button("OK") {
                showResolutionPopup = true
            }
        } message: {
            Text("Please provide a resolution before marking the task as done.")
        }

        // Existing .sheet for resolution
        .sheet(isPresented: $showResolutionPopup) {
            if let t = pendingDoneTask {
                TaskDescriptionPopup(task: t)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        // Once the popup closes, see if they filled a resolution
                        let newRes = (t.resolution ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newRes.isEmpty {
                            // Now that a resolution is there, set it to "Done"
                            taskVM.setTaskStatus(t, to: "Done")
                        }
                        pendingDoneTask = nil
                    }
            }
        }
        
        .onTapGesture {
            tapped(task)
        }
//        .sheet(isPresented: $showResolutionPopup) {
//            if let t = pendingDoneTask {
//                TaskDescriptionPopup(task: t)
//                    .environment(\.managedObjectContext, viewContext)
//                    .onDisappear {
//                        let newRes = (t.resolution ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
//                        if !newRes.isEmpty {
//                            taskVM.setTaskStatus(t, to: "Done")
//                        }
//                        pendingDoneTask = nil
//                    }
//            }
//        }
        
        // POSTPONE SHEET
        .sheet(isPresented: $showPostponeSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Postpone To")) {
                        DatePicker("Select date/time", selection: $postponeDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                    }
                    Section(header: Text("Reason")) {
                        TextField("Enter reason...", text: $postponeReason)
                    }
                }
                .navigationTitle("Postpone Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showPostponeSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            // If user picks a time still “today,” force tomorrow
                            let startOfToday = Calendar.current.startOfDay(for: Date())
                            let endOfToday   = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
                            if postponeDate < endOfToday {
                                // Force tomorrow at same hour/min
                                postponeDate = Calendar.current.date(byAdding: .day, value: 1, to: postponeDate)!
                            }
                            
                            // Mark as "Postpone"
                            task.status = "Postpone"
                            task.startTime = postponeDate
                            
                            task.postponeDate   = postponeDate
                            task.postponeReason = postponeReason
                            
                            saveChanges()
                            taskVM.fetchTodayTasks()
                            
                            showPostponeSheet = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helpers
extension TaskRowCompact {
    private func canUse(symbol: String) -> Bool {
        let currentSymbol = task.prioritySymbol ?? ""
        if currentSymbol == symbol { return true }
        return !allTasks.contains { $0.prioritySymbol == symbol }
    }
    
    private func saveChanges() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving changes: \(error.localizedDescription)")
        }
    }
}
