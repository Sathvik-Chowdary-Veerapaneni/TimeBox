import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    @State private var showingAddSheet = false
    @State private var selectedTask: TimeBox_Task? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(normalTasks) { task in
                    TaskRowCompact(task: task) { tappedTask in
                        selectedTask = tappedTask
                    }
                    .onDrag {
                        provider(for: task)
                    }
                }
                .onDelete(perform: deleteNormalTasks)
            }
            .listStyle(.plain)

            Button("Add New Task") {
                showingAddSheet.toggle()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onDrop(of: [UTType.text], delegate: NormalTasksDropDelegate(viewContext: viewContext))
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        .toolbar {
            EditButton()
        }
    }
    
    // Return all tasks (no more priority filtering)
    private var normalTasks: [TimeBox_Task] {
        return tasks.map { $0 }
    }
    
    // MARK: - Basic Ops
    private func deleteNormalTasks(at offsets: IndexSet) {
        offsets.map { normalTasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func moveNormalTasks(from source: IndexSet, to destination: Int) {
        // If built-in reordering is desired
        var updated = normalTasks
        updated.move(fromOffsets: source, toOffset: destination)
        for (newIndex, task) in updated.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}

// MARK: - Normal Tasks Drop Delegate
struct NormalTasksDropDelegate: DropDelegate {
    let viewContext: NSManagedObjectContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [UTType.text]).first else {
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
            guard
                let data = data as? Data,
                let urlString = String(data: data, encoding: .utf8),
                let url = URL(string: urlString),
                let coordinator = viewContext.persistentStoreCoordinator,
                let objID = coordinator.managedObjectID(forURIRepresentation: url)
            else { return }
            
            viewContext.perform {
                if let draggedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task {
                    // Currently no special logic—just save.
                    try? viewContext.save()
                }
            }
        }
        return true
    }
}

// MARK: - Helper for .onDrag
private func provider(for task: TimeBox_Task) -> NSItemProvider {
    let idString = task.objectID.uriRepresentation().absoluteString
    return NSItemProvider(object: idString as NSString)
}
