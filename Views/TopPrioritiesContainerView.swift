import SwiftUI

struct TopPrioritiesContainerView: View {
    let priorityTasks: [TimeBox_Task]  // Passed in from ContentView

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.2))
                .frame(height: 100)

            if priorityTasks.isEmpty {
                // Show a big icon (or any visual) when there's nothing in top priority
                Image(systemName: "hand.draw")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.orange.opacity(0.3))
            } else {
                // If we have priority tasks, show them in a scrollable horizontal row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(priorityTasks) { task in
                            // Display each top-priority task as a small “card” or however you like
                            PriorityTaskCardView(task: task)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        // Animate the appearance/disappearance of the icon when empty vs. filled
        .animation(.easeInOut, value: priorityTasks.count)
    }
}
