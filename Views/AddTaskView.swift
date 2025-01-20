import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var desc = ""
    
    // Default status for new tasks
    private let defaultStatus = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                TextField("Enter title...", text: $title)
                    .font(.custom("Helvetica", size: 16))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                TextEditor(text: $desc)
                    .font(.custom("Helvetica", size: 16))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            .padding(.horizontal, -4) // tighten the border
                    )
                    .padding(.horizontal, 8)

                // Remove the Spacer() to avoid extra space
            }
            .padding(.top, 12)
            .navigationBarTitle("New Task", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("Helvetica", size: 16))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addTask()
                    }
                    .font(.custom("Helvetica", size: 16))
                }
            }
        }
        // Smaller fraction for more compact sheet
        .presentationDetents([.fraction(0.3)])
    }
    
    private func addTask() {
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.desc = desc
        newTask.status = defaultStatus

        // Place new task at bottom of the list
        newTask.sortIndex = Int16((try? viewContext.count(for: TimeBox_Task.fetchRequest())) ?? 0)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
}
