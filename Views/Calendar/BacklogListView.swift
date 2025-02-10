// BacklogListView.swift
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
                    // DRAG
                    .onDrag {
                        let taskID = task.uriString
                        return NSItemProvider(object: taskID as NSString)
                    }
                }
                .onDelete(perform: deleteAction)
            }
        }
    }
}
