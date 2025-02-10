import SwiftUI
import CoreData

struct TaskDescriptionPopup: View {
    @ObservedObject var task: TimeBox_Task
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // <<< ADDED: track old values to detect newlines in description & resolution
    @State private var oldDesc = ""
    @State private var oldResolution = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task")) {
                    Text(task.title ?? "Untitled")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: Binding(
                        get: { task.desc ?? "" },
                        set: { newValue in
                            task.desc = newValue.appendingDashIfNeeded(previous: task.desc ?? "")
                        }
                    )
                )
                    .frame(minHeight: 80)
                }
                
                Section(header: Text("Resolution")) {
                    TextEditor(text: Binding(
                        get: { task.resolution ?? "" },
                        set: { newValue in
                            if newValue.count > (task.resolution ?? "").count,
                               newValue.hasSuffix("\n") {
                                task.resolution = newValue + "- "
                            } else {
                                task.resolution = newValue
                            }
                        }
                    ))
                    .frame(minHeight: 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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


#if DEBUG
struct TaskDescriptionPopup_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create an in-memory context for preview
        let context = PersistenceController(inMemory: true).container.viewContext
        
        // 2) Insert a sample task
        let previewTask = TimeBox_Task(context: context)
        previewTask.title = "Preview Task"
        previewTask.desc = "Sample description"
        previewTask.resolution = "Sample resolution"
        
        // 3) Show the popup with this sample
        return TaskDescriptionPopup(task: previewTask)
            .environment(\.managedObjectContext, context)
            .preferredColorScheme(.light) // or .dark if you want to test both
    }
}
#endif
