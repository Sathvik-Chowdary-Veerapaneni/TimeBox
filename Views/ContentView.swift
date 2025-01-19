import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Fetch all tasks, sorted by sortIndex
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)],
        animation: .default
    )
    private var tasks: FetchedResults<TimeBox_Task>
    
    @State private var showingAddSheet = false
    @State private var selectedTask: TimeBox_Task? = nil
    
    // Separate arrays:
    private var priorityTasks: [TimeBox_Task] {
        tasks.filter { $0.isInPriorityPool }
    }
    private var normalTasks: [TimeBox_Task] {
        tasks.filter { !$0.isInPriorityPool }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ---- TOP CONTAINER (can drop tasks here) ----
            TopPrioritiesContainerView(priorityTasks: priorityTasks)
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
                .padding(.bottom, 8)
            
            // ---- MAIN LIST OF NORMAL TASKS ----
            List {
                ForEach(normalTasks) { task in
                    // Each row is draggable so user can drop onto the top container
                    TaskRowCompact(task: task) { tappedTask in
                        selectedTask = tappedTask
                    }
                    .onDrag {
                        provider(for: task)
                    }
                }
                .onMove(perform: moveNormalTasks)
                .onDelete(perform: deleteNormalTasks)
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
            
            // ---- ADD NEW TASK BUTTON ----
            Button(action: {
                showingAddSheet.toggle()
            }) {
                Text("Add New Task")
                    .font(.headline)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // Sheets
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
        }
        // Edit button for reordering/deletion
        .toolbar {
            EditButton()
        }
    }
    
    // MARK: - DRAG HELPERS
    
    /// Creates an NSItemProvider that holds the Core Data objectID for dragging
    private func provider(for task: TimeBox_Task) -> NSItemProvider {
        let idString = task.objectID.uriRepresentation().absoluteString
        // Provide the string as an NSString
        return NSItemProvider(object: idString as NSString)
    }
    
    // MARK: - DROP HANDLER
    
    /// Called when user drops a normal-task row onto the top container
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        print("handleDrop triggered with \(providers.count) provider(s)")
        
        // Find a provider that can supply plain text
        guard let item = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) else {
            print("No provider for plain text")
            return false
        }
        
        // Load the item as plain text
        item.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, error in
            DispatchQueue.main.async {
                if let str = data as? String {
                    print("Dragged text is: \(str)")
                    
                    // Convert that string into a URL
                    if let url = URL(string: str) {
                        print("Converted text to URL: \(url)")
                        
                        do {
                            // Convert URL -> NSManagedObjectID
                            let objID = try self.viewContext
                                .persistentStoreCoordinator?
                                .managedObjectID(forURIRepresentation: url)
                            
                            print("Managed Object ID: \(String(describing: objID))")
                            
                            if let validID = objID,
                               let draggedTask = try? self.viewContext
                                .existingObject(with: validID) as? TimeBox_Task {
                                
                                print("Successfully fetched task titled: \(draggedTask.title ?? "Untitled")")
                                
                                // Only allow if fewer than 3 tasks in priority
                                if priorityTasks.count < 3 {
                                    draggedTask.isInPriorityPool = true
                                    self.saveContext()
                                    print("Task moved to priority container.")
                                } else {
                                    print("Top priority container is full! Task not moved.")
                                }
                            } else {
                                print("Could not fetch the draggedTask from objID.")
                            }
                            
                        } catch {
                            print("Error converting dropped item: \(error.localizedDescription)")
                        }
                        
                    } else {
                        print("Couldn't convert dragged text to a valid URL.")
                    }
                } else {
                    print("Dragged data is not a string or is nil.")
                }
            }
        }
        return true
    }
    
    // MARK: - REORDER & DELETE
    
    private func moveNormalTasks(from source: IndexSet, to destination: Int) {
        var updated = normalTasks
        updated.move(fromOffsets: source, toOffset: destination)
        for (newIndex, task) in updated.enumerated() {
            task.sortIndex = Int16(newIndex)
        }
        saveContext()
    }
    
    private func deleteNormalTasks(at offsets: IndexSet) {
        offsets.map { normalTasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    // MARK: - SAVE
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
}