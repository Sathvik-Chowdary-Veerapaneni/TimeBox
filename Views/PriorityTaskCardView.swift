import SwiftUI
import CoreData

/// A small card that represents a top-priority task in the container.
struct PriorityTaskCardView: View {
    @ObservedObject var task: TimeBox_Task
    
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack {
            Text(task.title ?? "Untitled")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.top, 4)
            
            // Button to remove from top priority
            Button("Remove") {
                task.isInPriorityPool = false
                saveContext()
            }
            .font(.caption2)
            .padding(.vertical, 2)
        }
        .frame(width: 120, height: 80)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving changes: \(error.localizedDescription)")
        }
    }
}
