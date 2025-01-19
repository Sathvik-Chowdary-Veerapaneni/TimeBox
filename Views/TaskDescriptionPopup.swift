import SwiftUI
import CoreData

struct TaskDescriptionPopup: View {
    @ObservedObject var task: TimeBox_Task
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Description")) {
                    TextEditor(text: Binding(
                        get: { task.desc ?? "" },
                        set: { newValue in
                            task.desc = newValue
                        }
                    ))
                    .frame(minHeight: 80)
                }
                Section(header: Text("Resolution")) {
                    TextEditor(text: Binding(
                        get: { task.resolution ?? "" },
                        set: { newValue in
                            task.resolution = newValue
                        }
                    ))
                    .frame(minHeight: 80)
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDetails()
                    }
                }
            }
        }
    }
    
    private func saveDetails() {
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving details: \(error)")
        }
    }
}
