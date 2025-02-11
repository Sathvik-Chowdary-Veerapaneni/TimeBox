// ContentView.swift

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TimeBox_Task.priorityRank, ascending: true),
            NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)
        ],
        predicate: .todayPredicate()  // from the extension in Predicates.swift
    )
    private var todayTasks: FetchedResults<TimeBox_Task>
    
    @EnvironmentObject var taskVM: TaskViewModel
    
    @State private var showingAddSheet = false
    @State private var selectedTask: TimeBox_Task? = nil
    
    @State private var showCalendar = false
    @State private var showProfileSheet = false
    @State private var showHourlySchedule = false
    
    var body: some View {
        let sortedTodayTasks = Array(todayTasks).sorted { a, b in
            let isDoneA = (a.status == "Done")
            let isDoneB = (b.status == "Done")
            if isDoneA != isDoneB { return !isDoneA }
            if a.priorityRank != b.priorityRank { return a.priorityRank < b.priorityRank }
            return a.sortIndex < b.sortIndex
        }
        return NavigationView {
            VStack(spacing: 0) {
                // TOP BAR
                HStack {
                    Button {
                        showCalendar.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .padding(.leading, 40)
                    }
                    
                    // Calendar_Integration
                    // New button for Hourly Schedule
                    Button {
                        showHourlySchedule = true
                        print("New button tapped")
                    } label: {
                        Image(systemName: "star")
                            .font(.title2)
                            .padding(.leading, 40)
                    }
                    
                    Spacer()
                    
                    Text("HOME")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        showProfileSheet.toggle()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .padding(.trailing, 40)
                    }
                }
                .padding(.vertical, 10)
                
                Divider()
                
                // Show "today" tasks from the @FetchRequest:
                List {
                    ForEach(sortedTodayTasks, id: \.objectID) { task in
                        TaskRowCompact(
                            task: task,
                            allTasks: Array(todayTasks),  // pass an Array if needed
                            tapped: { selectedTask = $0 }
                        )
                    }
                    .onDelete(perform: deleteTasks)
                    .onMove(perform: moveTasks)
                }
                .listStyle(.plain)
                
                // BOTTOM + PLUS BUTTON
                HStack {
                    Button {
                        showingAddSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .padding(.leading, 16)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .navigationBarHidden(true)
            
        }
        // SHEETS
        .sheet(isPresented: $showHourlySchedule) {
            HourlyScheduleView()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarView()
                .environment(\.managedObjectContext, viewContext)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedTask) { task in
            TaskDescriptionPopup(task: task)
                .environment(\.managedObjectContext, viewContext)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTaskView()
                .environment(\.managedObjectContext, viewContext)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Congratulations!", isPresented: $taskVM.showCongratsBanner) {
            Button("OK") {
                // Reset if desired
                taskVM.showCongratsBanner = false
            }
        } message: {
            Text(taskVM.congratsMessage)
        }
        
        .toolbar {
            EditButton()
        }
    }
    
    // MARK: - Delete & Move
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = todayTasks[index]
            viewContext.delete(task)
        }
        saveAndRefresh()
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        // If you need reordering among “todayTasks,” handle it here.
        // (But you can also rely on your TaskViewModel logic.)
        print("DEBUG: Move from \(source) to \(destination)")
        
        // Example:
        var tasksArray = Array(todayTasks)
        tasksArray.move(fromOffsets: source, toOffset: destination)
        
        // Reassign sortIndex
        for (i, t) in tasksArray.enumerated() {
            t.sortIndex = Int16(i)
        }
        saveAndRefresh()
    }
    
    private func saveAndRefresh() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error.localizedDescription)")
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(TaskViewModel(context: PersistenceController.shared.container.viewContext))
    }
}
