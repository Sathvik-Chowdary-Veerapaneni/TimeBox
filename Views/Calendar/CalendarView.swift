//
// CalendarView.swift
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CalendarView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.managedObjectContext) var viewContext
    
    // Month navigation
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showBacklog = false
    
    // --- Search State ---
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var searchResults: [TimeBox_Task] = []
    
    // Day-based tasks
    @State private var tasksForSelectedDate: [TimeBox_Task] = []
    @State private var backlogTasks: [TimeBox_Task] = []
    @State var dailyTaskCounts: [Date: Int] = [:]
    
    // Alert for done-task drag
    @State private var showDoneAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) TOP BAR: search bar OR normal nav
                if showSearch {
                    HStack(spacing: 8) {
                        TextField("Search tasks...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: searchText) { newValue in
                                performSearch(newValue)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        
                        Button("Cancel") {
                            withAnimation {
                                showSearch = false
                                searchText = ""
                                searchResults = []
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Inline month nav
                    HStack {
                        Button("< Prev") {
                            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                            fetchMonthlyTaskCounts(for: currentMonth)
                        }
                        Spacer()
                        if !showBacklog {
                            Text(formatMonth(currentMonth))
                                .font(.headline)
                        } else {
                            Text("").font(.headline)
                        }
                        Spacer()
                        Button("Next >") {
                            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                            fetchMonthlyTaskCounts(for: currentMonth)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                
                // 2) DAY GRID (only if not searching or typed < 3 chars)
                if !showSearch || searchText.count < 3 {
                    let daysInMonth = makeDaysInMonth(currentMonth)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 8) {
                            ForEach(daysInMonth, id: \.self) { day in
                                let dayOnly = Calendar.current.startOfDay(for: day)
                                let count = dailyTaskCounts[dayOnly] ?? 0
                                
                                DayCellView(
                                    day: day,
                                    selectedDate: selectedDate,
                                    dayTaskCount: count,
                                    onTap: {
                                        if !showBacklog {
                                            selectedDate = day
                                            tasksForSelectedDate = fetchTasks(for: day)
                                        }
                                    },
                                    onDropTask: { objectIDString in
                                        handleDropTask(objectIDString, day: day)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 220) // fix height to avoid layout compression
                }
                
                Divider()
                
                // 3) BOTTOM: search results or normal backlog/day tasks
                if showSearch && searchText.count >= 3 {
                    // SEARCH RESULTS
                    if searchResults.isEmpty {
                        Text("No tasks matching '\(searchText)'.")
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(searchResults, id: \.objectID) { task in
                                HStack {
                                    Text(task.title ?? "Untitled")
                                        .font(.headline)
                                    Spacer()
                                    if let st = task.startTime {
                                        Text(dateString(st))
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                // Optionally .onDrag here
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    // BACKLOG or DAY TASKS
                    if showBacklog {
                        if backlogTasks.isEmpty {
                            Text("No overdue tasks!")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        } else {
                            List {
                                ForEach(backlogTasks, id: \.objectID) { task in
                                    HStack {
                                        Text(task.title ?? "Untitled")
                                        Spacer()
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                    }
                                    // Flicker-free drag
                                    .onDrag(
                                        {
                                            let taskID = task.objectID.uriRepresentation().absoluteString
                                            return NSItemProvider(object: taskID as NSString)
                                        },
                                        preview: {
                                            Color.clear.frame(width: 1, height: 1)
                                        }
                                    )
                                }
                                .onDelete(perform: deleteBacklogTasks)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    } else {
                        if tasksForSelectedDate.isEmpty {
                            Text("No tasks for \(dateString(selectedDate)).")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        } else {
                            List {
                                ForEach(tasksForSelectedDate, id: \.objectID) { task in
                                    HStack {
                                        Text(task.title ?? "Untitled")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    // Flicker-free drag
                                    .onDrag(
                                        {
                                            let taskID = task.objectID.uriRepresentation().absoluteString
                                            return NSItemProvider(object: taskID as NSString)
                                        },
                                        preview: {
                                            Color.clear.frame(width: 1, height: 1)
                                        }
                                    )
                                }
                                .onDelete(perform: deleteTasks)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(showBacklog ? "OverDue" : "Calendar")
            .onAppear {
                // Initial load
                currentMonth = Date()
                fetchMonthlyTaskCounts(for: currentMonth)
                
                selectedDate = Date()
                tasksForSelectedDate = fetchTasks(for: selectedDate)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Overdue toggle
                        Button {
                            showBacklog.toggle()
                            if showBacklog {
                                backlogTasks = fetchBacklogTasks()
                            }
                        } label: {
                            if showBacklog {
                                Image(systemName: "calendar")
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("OverDue")
                                }
                            }
                        }
                        
                        // Search toggle
                        Button {
                            withAnimation {
                                showSearch.toggle()
                                if !showSearch {
                                    searchText = ""
                                    searchResults = []
                                }
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
            // If user tries to move a Done task
            .alert("Cannot Move Done Task",
                   isPresented: $showDoneAlert,
                   actions: {
                       Button("OK", role: .cancel) { }
                   },
                   message: {
                       Text("This task is marked as 'Done'—please change its status first.")
                   }
            )
        }
    }
}

// Keep search & drop logic here

extension CalendarView {
    // “Perform search” (≥3 chars)
    func performSearch(_ text: String) {
        guard text.count >= 3 else {
            searchResults = []
            return
        }
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "(title CONTAINS[cd] %@) OR (desc CONTAINS[cd] %@)",
            text, text
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeBox_Task.startTime, ascending: true)]
        
        do {
            let fetched = try viewContext.fetch(request)
            // Sort them: today -> future -> past
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            
            let todayMatches  = fetched.filter {
                if let st = $0.startTime { return Calendar.current.isDate(st, inSameDayAs: Date()) }
                return false
            }
            let futureMatches = fetched.filter { ($0.startTime ?? Date()) >= tomorrow }
            let pastMatches   = fetched.filter { ($0.startTime ?? Date()) < today }
            
            searchResults = todayMatches + futureMatches + pastMatches
        } catch {
            print("Error searching tasks:", error)
            searchResults = []
        }
    }
    
    // “Handle drop task” (drag & drop logic)
    func handleDropTask(_ objectIDString: String, day: Date) -> Bool {
        guard
            let url = URL(string: objectIDString),
            let objID = viewContext.persistentStoreCoordinator?
                .managedObjectID(forURIRepresentation: url),
            let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
        else { return false }
        
        // Block if "Done"
        if droppedTask.status == "Done" {
            showDoneAlert = true
            return false
        }
        
        // Disallow dropping on past
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let thisDay = Calendar.current.startOfDay(for: day)
        guard thisDay >= startOfToday else {
            print("DEBUG: Disallow drop on a past date.")
            return false
        }
        
        let oldDate = droppedTask.startTime
        // If old date was "today," remove from ContentView’s “today tasks”
        if let oldDate = oldDate, Calendar.current.isDate(oldDate, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // Actually reschedule
        taskVM.rescheduleTask(with: objectIDString, to: day)
        
        // If new date is "today," add to ContentView’s “today tasks”
        if Calendar.current.isDate(day, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // UI updates in selected day tasks
        if let oldDate = oldDate,
           Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
            tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
        }
        if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
            tasksForSelectedDate.append(droppedTask)
        }
        
        // Adjust dailyTaskCounts
        if let oldDate = oldDate {
            let oldKey = Calendar.current.startOfDay(for: oldDate)
            if dailyTaskCounts[oldKey] != nil {
                dailyTaskCounts[oldKey]! = max(0, dailyTaskCounts[oldKey]! - 1)
            }
        }
        let newKey = Calendar.current.startOfDay(for: day)
        dailyTaskCounts[newKey, default: 0] += 1
        
        // If backlog is showing, remove from backlog array
        if showBacklog {
            backlogTasks.removeAll { $0.objectID == droppedTask.objectID }
        }
        
        return true
    }
    
    // “Backlog tasks” or “day tasks” deletion
    func deleteBacklogTasks(at offsets: IndexSet) {
        for idx in offsets {
            let task = backlogTasks[idx]
            backlogTasks.remove(at: idx)
            taskVM.deleteTask(task)
        }
    }
    
    func deleteTasks(at offsets: IndexSet) {
        for idx in offsets {
            let task = tasksForSelectedDate[idx]
            tasksForSelectedDate.remove(at: idx)
            
            if let st = task.startTime {
                let dayKey = Calendar.current.startOfDay(for: st)
                dailyTaskCounts[dayKey] = max(0, (dailyTaskCounts[dayKey] ?? 0) - 1)
            }
            taskVM.deleteTask(task)
        }
    }
    
    // Format a month, e.g. "January 2025"
    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    // Format a date for display
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
