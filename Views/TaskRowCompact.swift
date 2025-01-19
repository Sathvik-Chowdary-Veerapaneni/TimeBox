import SwiftUI
import CoreData

struct TaskRowCompact: View {
    @ObservedObject var task: TimeBox_Task
    var tapped: (TimeBox_Task) -> Void

    @Environment(\.managedObjectContext) private var viewContext

    // Hours info
    private let hourOptions: [(value: Double, label: String, iconName: String)] = [
        (0.25, "15m", "15.circle.fill"),
        (0.5,  "30m", "30.circle.fill"),
        (1.0,  "1h",  "1.circle.fill"),
        (2.0,  "2h",  "2.circle.fill"),
        (3.0,  "3h",  "3.circle.fill")
    ]
    
    // Ordered statuses to keep them in a fixed order
    private let orderedStatuses = ["InProgress", "Done", "Postpone"]
    
    // Status info: icon, color, label
    private let statusInfo: [String: (iconName: String, color: Color, label: String)] = [
        "InProgress": ("clock.fill", .blue,    "In Progress"),
        "Done":       ("checkmark.seal.fill", .green,  "Done"),
        "Postpone":   ("hourglass",           .orange, "Postpone")
    ]
    
    var body: some View {
        HStack(spacing: 12) {
            // Title
            Text(task.title ?? "Untitled")
                .font(.headline)
            
            Spacer()
            
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
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "exclamationmark.square")
                        .foregroundColor(.red)
                }
            }
            
            // STATUS ICON MENU
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
                let currentKey = task.status ?? ""
                if currentKey.isEmpty {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.gray)
                } else if let info = statusInfo[currentKey] {
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
        .contentShape(Rectangle())
        .onTapGesture {
            tapped(task)
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
