// TaskListViews.swift

import SwiftUI

struct BacklogListView: View {
    @Binding var backlogTasks: [TimeBox_Task]
    let deleteAction: (IndexSet) -> Void
    
    var body: some View {
        if backlogTasks.isEmpty {
            Text("No overdue tasks!")
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        } else {
            List {
                ForEach(backlogTasks, id: \.objectID) { task in
                    HStack {
                        Text(task.title ?? "Untitled")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                    )
                    .onDrag({
                        let taskID = task.objectID.uriRepresentation().absoluteString
                        return NSItemProvider(object: taskID as NSString)
                    }, preview: {
                        Color.clear.frame(width: 1, height: 1)
                    })
                }
                .onDelete(perform: deleteAction)
            }
        }
    }
}

struct DayTasksListView: View {
    @Binding var tasksForSelectedDate: [TimeBox_Task]
    let selectedDate: Date
    let deleteAction: (IndexSet) -> Void
    
    var body: some View {
        if tasksForSelectedDate.isEmpty {
            Text("No tasks for \(dateString(selectedDate)).")
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        } else {
            List {
                ForEach(tasksForSelectedDate, id: \.objectID) { task in
                    HStack {
                        Text(task.title ?? "Untitled")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                    )
                    .onDrag({
                        let taskID = task.objectID.uriRepresentation().absoluteString
                        return NSItemProvider(object: taskID as NSString)
                    }, preview: {
                        Color.clear.frame(width: 1, height: 1)
                    })
                }
                .onDelete(perform: deleteAction)
            }
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
