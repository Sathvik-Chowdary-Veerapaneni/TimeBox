// MonthNavigationView.swift

import SwiftUI

struct MonthNavigationView: View {
    let currentMonth: Date
    let onPrev: () -> Void
    let onNext: () -> Void
    
    // Whether we're in backlog mode (to possibly hide month text)
    let showBacklog: Bool
    
    var body: some View {
        HStack {
            Button("< Prev") { onPrev() }
            Spacer()
            
            if !showBacklog {
                Text(formatMonth(currentMonth))
                    .font(.headline)
            } else {
                Text("")  // hide text if backlog
                    .font(.headline)
            }
            
            Spacer()
            Button("Next >") { onNext() }
        }
        .padding()
    }
    
    // Local helper for formatting the month
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}
