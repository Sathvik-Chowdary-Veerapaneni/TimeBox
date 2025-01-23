//// DayTasksListView.swift
//import SwiftUI
//
//struct DayTasksListView: View {
//    @Binding var tasksForSelectedDate: [TimeBox_Task]
//    let selectedDate: Date
//    let deleteAction: (IndexSet) -> Void
//
//    var body: some View {
//        if tasksForSelectedDate.isEmpty {
//            Text("No tasks for \(dateString(selectedDate)).")
//                .foregroundColor(.secondary)
//                .padding()
//            Spacer()
//        } else {
//            List {
//                ForEach(tasksForSelectedDate, id: \.objectID) { task in
//                    HStack {
//                        Text(task.title ?? "Untitled")
//                            .font(.headline)
//                        Spacer()
//                    }
//                    .padding(.vertical, 6)
//                }
//                .onDelete(perform: deleteAction)
//            }
//        }
//    }
//
//    private func dateString(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//}
