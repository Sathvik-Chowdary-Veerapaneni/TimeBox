// MonthNavigationView.swift
import SwiftUI

struct MonthNavigationView: View {
    @Binding var currentMonth: Date
    let fetchMonthlyTaskCounts: (Date) -> Void

    var body: some View {
        HStack {
            Button("< Prev") {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                fetchMonthlyTaskCounts(currentMonth)
            }
            Spacer()
            Text(formatMonth(currentMonth))
                .font(.headline)
            Spacer()
            Button("Next >") {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                fetchMonthlyTaskCounts(currentMonth)
            }
        }
        .padding()
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}
