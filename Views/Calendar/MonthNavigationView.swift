// MonthNavigationView.swift

import SwiftUI

struct MonthNavigationView: View {
    let currentMonth: Date
    let onPrev: () -> Void
    let onNext: () -> Void
    let showBacklog: Bool
    
    var body: some View {
        HStack {
            Button("< Prev") { onPrev() }
            Spacer()
            
            if !showBacklog {
                Text(DateUtils.formatMonth(currentMonth))
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
}
