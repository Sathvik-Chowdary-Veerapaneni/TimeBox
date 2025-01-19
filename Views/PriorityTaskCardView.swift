import SwiftUI
import CoreData

struct PriorityTaskCardView: View {
    @ObservedObject var task: TimeBox_Task
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack {
            Text(task.title ?? "Untitled")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.top, 4)

            // A remove button that returns it to normal list
            Button("Remove") {
                task.isInPriorityPool = false
                save()
            }
            .font(.caption2)
            .padding(.vertical, 2)
        }
        .frame(width: 120, height: 80)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error removing from top: \(error.localizedDescription)")
        }
    }
}
