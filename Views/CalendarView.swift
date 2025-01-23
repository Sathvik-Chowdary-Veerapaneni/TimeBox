//
// CalendarView.swift
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CalendarView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    // Month navigation
    @State private var currentMonth = Date()
    
    // The date the user taps
    @State private var selectedDate = Date()
    
    // Normal mode: tasks for the selected day
    @State private var tasksForSelectedDate: [TimeBox_Task] = []
    
    // Dictionary of day -> number of tasks, for the current month
    @State private var dailyTaskCounts: [Date: Int] = [:]
    
    // Toggle for showing "Backlog" vs. normal Calendar
    @State private var showBacklog = false
    
    // Overdue tasks (startTime < today, status != "Done")
    @State private var backlogTasks: [TimeBox_Task] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) MONTH NAVIGATION
                HStack {
                    Button("< Prev") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        fetchMonthlyTaskCounts(for: currentMonth)
                    }
                    Spacer()
                    
                    // Hide month text if in backlog mode
                    if !showBacklog {
                        Text(formatMonth(currentMonth))
                            .font(.headline)
                    } else {
                        Text("")
                            .font(.headline)
                    }
                    
                    Spacer()
                    Button("Next >") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        fetchMonthlyTaskCounts(for: currentMonth)
                    }
                }
                .padding()
                
                // 2) DAYS GRID
                let daysInMonth = makeDaysInMonth(currentMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth, id: \.self) { day in
                        let dayOnly = Calendar.current.startOfDay(for: day)
                        let taskCount = dailyTaskCounts[dayOnly] ?? 0
                        
                        DayCellView(
                            day: day,
                            selectedDate: selectedDate,
                            dayTaskCount: taskCount,
                            onTap: {
                                // Only fetch tasks if NOT in backlog mode
                                if !showBacklog {
                                    selectedDate = day
                                    tasksForSelectedDate = fetchTasks(for: day)
                                }
                            },
                            onDropTask: { objectIDString -> Bool in
                                // 1) Convert dropped string -> NSManagedObjectID -> TimeBox_Task
                                guard
                                    let url = URL(string: objectIDString),
                                    let objID = viewContext.persistentStoreCoordinator?
                                        .managedObjectID(forURIRepresentation: url),
                                    let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
                                else {
                                    return false
                                }
                                
                                // 2) Block if day < today
                                let todayStart = Calendar.current.startOfDay(for: Date())
                                let thisDay = Calendar.current.startOfDay(for: day)
                                guard thisDay >= todayStart else {
                                    print("DEBUG: Disallow drop on a past date.")
                                    return false
                                }
                                
                                // *** Refresh Home if old date was today ***
                                let oldDate = droppedTask.startTime
                                if let oldDate = oldDate, Calendar.current.isDate(oldDate, inSameDayAs: Date()) {
                                    // Moved away from "today" => remove from Home
                                    taskVM.fetchTodayTasks()
                                }
                                
                                // 3) Update in Core Data
                                taskVM.rescheduleTask(with: objectIDString, to: day)
                                
                                // *** Refresh Home if new date is today ***
                                if Calendar.current.isDate(day, inSameDayAs: Date()) {
                                    taskVM.fetchTodayTasks()
                                }
                                
                                // 4) UI updates
                                if showBacklog {
                                    // Remove from backlog
                                    backlogTasks.removeAll { $0.objectID == droppedTask.objectID }
                                } else {
                                    // If old date was selected, remove from tasksForSelectedDate
                                    if let oldDate = oldDate,
                                       Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
                                        tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
                                    }
                                    // If new date == selectedDate, add it
                                    if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
                                        tasksForSelectedDate.append(droppedTask)
                                    }
                                }
                                
                                // 5) Adjust dailyTaskCounts
                                if let oldDate = oldDate {
                                    let oldKey = Calendar.current.startOfDay(for: oldDate)
                                    if dailyTaskCounts[oldKey] != nil {
                                        dailyTaskCounts[oldKey]! = max(0, dailyTaskCounts[oldKey]! - 1)
                                    }
                                }
                                let newKey = Calendar.current.startOfDay(for: day)
                                dailyTaskCounts[newKey, default: 0] += 1
                                
                                return true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .animation(nil, value: dailyTaskCounts)
                
                Divider()
                
                // 3) BOTTOM: backlog or normal tasks
                if showBacklog {
                    // BACKLOG MODE
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
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                )
                                // FLICKER-FREE DRAG PREVIEW
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
                    }
                } else {
                    // NORMAL CALENDAR MODE
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
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                )
                                // FLICKER-FREE DRAG PREVIEW
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
                    }
                }
            }
            .navigationTitle(showBacklog ? "OverDue" : "Calendar")
            .onAppear {
                // Show current month, select today
                currentMonth = Date()
                fetchMonthlyTaskCounts(for: currentMonth)
                
                selectedDate = Date()
                tasksForSelectedDate = fetchTasks(for: selectedDate)
            }
            // Backlog toggle in toolbar
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Build an array of all days in the given month
    private func makeDaysInMonth(_ date: Date) -> [Date] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { return [] }
        var days: [Date] = []
        var current = interval.start
        while current < interval.end {
            days.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy" // e.g. "January 2025"
        return formatter.string(from: date)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Fetch tasks for a single day
    private func fetchTasks(for day: Date) -> [TimeBox_Task] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching tasks for day: \(error)")
            return []
        }
    }
    
    /// Fetch tasks for the entire month, and build `dailyTaskCounts`
    private func fetchMonthlyTaskCounts(for month: Date) {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            interval.start as CVarArg,
            interval.end as CVarArg
        )
        do {
            let tasks = try viewContext.fetch(request)
            var counts: [Date: Int] = [:]
            for t in tasks {
                if let st = t.startTime {
                    let dayOnly = Calendar.current.startOfDay(for: st)
                    counts[dayOnly, default: 0] += 1
                }
            }
            dailyTaskCounts = counts
        } catch {
            print("Error fetching monthly tasks: \(error)")
            dailyTaskCounts = [:]
        }
    }
    
    /// Overdue tasks: startTime < today & status != "Done"
    private func fetchBacklogTasks() -> [TimeBox_Task] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime < %@ AND status != %@",
            todayStart as CVarArg, "Done"
        )
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching backlog tasks: \(error)")
            return []
        }
    }
    
    /// Swipe-to-delete in backlog
    private func deleteBacklogTasks(at offsets: IndexSet) {
        offsets.forEach { index in
            let task = backlogTasks[index]
            backlogTasks.remove(at: index)
            taskVM.deleteTask(task)
        }
    }
    
    /// Swipe-to-delete in normal day tasks
    private func deleteTasks(at offsets: IndexSet) {
        offsets.forEach { index in
            let task = tasksForSelectedDate[index]
            tasksForSelectedDate.remove(at: index)
            
            if let st = task.startTime {
                let dayKey = Calendar.current.startOfDay(for: st)
                dailyTaskCounts[dayKey] = max(0, (dailyTaskCounts[dayKey] ?? 0) - 1)
            }
            taskVM.deleteTask(task)
        }
    }
}

// MARK: - DayCellView
struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    
    let dayTaskCount: Int
    let onTap: () -> Void
    let onDropTask: (String) -> Bool
    
    @State private var isTargeted = false
    
    // Compute highlight color to avoid nested ternary
    private var highlightColor: Color {
        if !isTargeted {
            return .clear
        } else {
            let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: Date())
            return isPast ? Color.red.opacity(0.15) : Color.green.opacity(0.15)
        }
    }
    
    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: Date())
        
        ZStack(alignment: .topTrailing) {
            Text("\(Calendar.current.component(.day, from: day))")
                .frame(width: 28, height: 28)
                .foregroundColor(isToday ? .white : .primary)
                .background(
                    Circle().fill(
                        isToday
                            ? Color.blue
                            : isSelected
                                ? Color.blue.opacity(0.2)
                                : isPast
                                    ? Color.gray.opacity(0.2)
                                    : Color.clear
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                )
                .onTapGesture { onTap() }
            
                // DRAG & DROP
                .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
                    // If day < today, disallow
                    let todayStart = Calendar.current.startOfDay(for: Date())
                    let thisDay = Calendar.current.startOfDay(for: day)
                    guard thisDay >= todayStart else {
                        print("DEBUG: Disallow drop on a past date.")
                        return false
                    }
                    
                    guard let itemProvider = providers.first else { return false }
                    itemProvider.loadObject(ofClass: String.self) { string, error in
                        if let error = error {
                            print("DEBUG: loadObject error:", error.localizedDescription)
                            return
                        }
                        guard let objectIDString = string else { return }
                        DispatchQueue.main.async {
                            let result = onDropTask(objectIDString)
                            print("DEBUG: onDropTask => \(result)")
                        }
                    }
                    return true
                }
                .background(highlightColor)
                .cornerRadius(4)
            
            if dayTaskCount > 0 {
                Text("\(dayTaskCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 9.5, y: -10)
            }
        }
    }
}
