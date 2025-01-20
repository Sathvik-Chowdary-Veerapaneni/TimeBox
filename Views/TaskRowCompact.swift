import SwiftUI
import CoreData

struct TaskRowCompact: View {
    @ObservedObject var task: TimeBox_Task
    let allTasks: [TimeBox_Task]
    var tapped: (TimeBox_Task) -> Void

    @Environment(\.managedObjectContext) private var viewContext
    
    // Existing hours/status arrays...
    private let hourOptions: [(value: Double, label: String, iconName: String)] = [
        (0.25, "15m", "15.circle.fill"),
        (0.5,  "30m", "30.circle.fill"),
        (1.0,  "1h",  "1.circle.fill"),
        (2.0,  "2h",  "2.circle.fill"),
        (3.0,  "3h",  "3.circle.fill")
    ]
    
    private let orderedStatuses = ["InProgress", "Done", "Postpone"]
    private let statusInfo: [String: (iconName: String, color: Color, label: String)] = [
        "InProgress": ("clock.fill", .blue, "In Progress"),
        "Done":       ("checkmark.seal.fill", .green, "Done"),
        "Postpone":   ("hourglass", .orange, "Postpone")
    ]
    
    // Priority logic
    private let priorityMap: [String: Int16] = [
        "!":  0,
        "!!": 1,
        "!!!":2,
        "":   3
    ]
    private let symbolsInOrder = ["!", "!!", "!!!"]

    var body: some View {
        HStack(spacing: 12) {
            // Title
            Text(task.title ?? "Untitled")
                .font(.headline)
            
            Spacer()
            
            // PRIORITY MENU
            Menu {
                // Offer !, !!, !!! if not used by another task
                ForEach(symbolsInOrder, id: \.self) { symbol in
                    if canUse(symbol: symbol) {
                        Button(symbol) {
                            updatePriority(to: symbol)
                        }
                    }
                }
                // Option to clear priority if set
                if !(task.prioritySymbol ?? "").isEmpty {
                    Button("Clear Priority") {
                        updatePriority(to: "")
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
            
            // HOURS MENU (unchanged)
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
            
            // STATUS MENU (unchanged)
            Menu {
                ForEach(orderedStatuses, id: \.self) { key in
                    if let info = statusInfo[key] {
                        Button {
                            task.status = key
                            saveChanges()
                        } label: {
                            Label(info.label, systemImage: info.iconName)
                                .foregroundColor(info.color)
                        }
                    }
                }
                Button("Clear Status") {
                    task.status = ""
                    saveChanges()
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
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onTapGesture {
            tapped(task)
        }
    }
}

// MARK: - Helpers
extension TaskRowCompact {
    private func canUse(symbol: String) -> Bool {
        let currentSymbol = task.prioritySymbol ?? ""
        // If this task already uses it, keep it
        if currentSymbol == symbol { return true }
        // Otherwise see if any other task is using it
        return !allTasks.contains { $0.prioritySymbol == symbol }
    }
    
    private func updatePriority(to newSymbol: String) {
        withAnimation {
            viewContext.perform { // ensure main-thread
                task.prioritySymbol = newSymbol
                task.priorityRank   = priorityMap[newSymbol] ?? 3
                saveChanges()
            }
        }
    }
    
    private func saveChanges() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving changes: \(error.localizedDescription)")
        }
    }
}
