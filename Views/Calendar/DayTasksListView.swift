// DayTasksListView.swift
import SwiftUI

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
                    // DRAG
                    .onDrag(
                        {
                            let taskID = task.objectID.uriRepresentation().absoluteString
                            return NSItemProvider(object: taskID as NSString)
                        },
                        preview: {
                            // This creates a tiny transparent preview to avoid flicker
                            Color.clear.frame(width: 1, height: 1)
                        }
                    )
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
