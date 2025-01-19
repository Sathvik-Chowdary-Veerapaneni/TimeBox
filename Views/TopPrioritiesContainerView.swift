import SwiftUI

struct TopPrioritiesContainerView: View {
    let priorityTasks: [TimeBox_Task]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.2))
                .frame(height: 100)

            if priorityTasks.isEmpty {
                // Show a horizontal arrangement: hand icon + label
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.orange.opacity(0.3))
                    
                    Text("Top 3 Priority tasks")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            } else {
                // Display a horizontal scroll of up to 3 tasks
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(priorityTasks.prefix(3)) { task in
                            PriorityTaskCardView(task: task)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        // Animate switching between empty/not-empty states
        .animation(.easeInOut, value: priorityTasks.count)
    }
}
