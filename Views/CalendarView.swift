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
    
    // The date the user has selected by tapping a day
    @State private var selectedDate = Date()
    
    // The tasks we show in the bottom list
    @State private var tasksForSelectedDate: [TimeBox_Task] = []
    
    // A dictionary that holds the number of tasks for each "startOfDay" in the current month
    @State private var dailyTaskCounts: [Date: Int] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) MONTH NAVIGATION at top
                HStack {
                    Button("< Prev") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        print("DEBUG: Moved to previous month:", currentMonth)
                        fetchMonthlyTaskCounts(for: currentMonth)
                    }
                    Spacer()
                    Text(formatMonth(currentMonth))
                        .font(.headline)
                    Spacer()
                    Button("Next >") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        print("DEBUG: Moved to next month:", currentMonth)
                        fetchMonthlyTaskCounts(for: currentMonth)
                    }
                }
                .padding()
                
                // 2) DAYS GRID pinned at top
                let days = makeDaysInMonth(currentMonth)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let dayOnly = Calendar.current.startOfDay(for: day)
                        let taskCount = dailyTaskCounts[dayOnly] ?? 0
                        
                        DayCellView(
                            day: day,
                            selectedDate: selectedDate,
                            dayTaskCount: taskCount,
                            onTap: {
                                selectedDate = day
                                tasksForSelectedDate = fetchTasks(for: day)
                                print("DEBUG: Tapped day:", day,
                                      "Fetched tasks for:", dateString(day),
                                      "Count:", tasksForSelectedDate.count)
                            },
                            onDropTask: { objectIDString -> Bool in
                                print("DEBUG: onDropTask triggered with objectID:", objectIDString)
                                
                                guard
                                    let url = URL(string: objectIDString),
                                    let objID = viewContext.persistentStoreCoordinator?
                                        .managedObjectID(forURIRepresentation: url),
                                    let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
                                else {
                                    print("DEBUG: Failed to convert objectIDString -> NSManagedObjectID -> TimeBox_Task")
                                    return false
                                }
                                
                                let oldDate = droppedTask.startTime
                                print("DEBUG: Found droppedTask with oldDate =", String(describing: oldDate))
                                
                                // 3) Update the model (Core Data + Calendar)
                                taskVM.rescheduleTask(with: objectIDString, to: day)
                                
                                // Remove from old date if it is currently selected
                                if let oldDate = oldDate,
                                   Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
                                    tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
                                }
                                // Add to the new date if it is selected
                                if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
                                    tasksForSelectedDate.append(droppedTask)
                                }
                                
                                // Decrement old date's count, increment new date's count
                                if let oldDate = oldDate {
                                    let oldKey = Calendar.current.startOfDay(for: oldDate)
                                    if dailyTaskCounts[oldKey] != nil {
                                        dailyTaskCounts[oldKey]! = max(0, dailyTaskCounts[oldKey]! - 1)
                                    }
                                }
                                let newKey = Calendar.current.startOfDay(for: day)
                                dailyTaskCounts[newKey, default: 0] += 1
                                
                                print("DEBUG: tasksForSelectedDate count after drop =", tasksForSelectedDate.count)
                                return true
                            }
                        )
                    }
                }
                .animation(nil, value: dailyTaskCounts)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // 3) TASKS BELOW -- CHANGED: Use a List with onDelete
                if tasksForSelectedDate.isEmpty {
                    Text("No tasks for \(dateString(selectedDate)).")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    // NEW: A List for tasks, just like "Home"
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
                            .onDrag(
                                {
                                    let objectIDString = task.objectID.uriRepresentation().absoluteString
                                    let provider = NSItemProvider(object: objectIDString as NSString)
                                    return provider
                                },
                                preview: {
                                    Color.clear.frame(width: 1, height: 1)
                                }
                            )
                        }
                        .onDelete(perform: deleteTasks) // <— NEW
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Calendar")
            .onAppear {
                fetchMonthlyTaskCounts(for: currentMonth)
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func fetchTasks(for day: Date) -> [TimeBox_Task] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        do {
            let fetched = try viewContext.fetch(request)
            print("DEBUG: fetchTasks(for:) got \(fetched.count) items for day:", dateString(day))
            return fetched
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
    
    // Fetch all tasks in the month once, then group them by "startOfDay"
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
            print("DEBUG: fetchMonthlyTaskCounts -> dictionary updated for", formatMonth(month))
        } catch {
            print("Error fetching monthly tasks: \(error)")
            dailyTaskCounts = [:]
        }
    }
    
    // NEW: Delete tasks from "tasksForSelectedDate" + Core Data + decrement the badge count
    private func deleteTasks(at offsets: IndexSet) {
        offsets.forEach { index in
            let task = tasksForSelectedDate[index]
            
            // 1) Remove it from the local array
            tasksForSelectedDate.remove(at: index)
            
            // 2) Decrement dailyTaskCounts so the badge updates
            if let st = task.startTime {
                let dayKey = Calendar.current.startOfDay(for: st)
                if dailyTaskCounts[dayKey] != nil {
                    dailyTaskCounts[dayKey]! = max(0, dailyTaskCounts[dayKey]! - 1)
                }
            }
            
            // 3) Use TaskViewModel to remove from Core Data
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
    
    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        
        ZStack(alignment: .topTrailing) {
            // Day number
            Text("\(Calendar.current.component(.day, from: day))")
                .frame(width: 28, height: 28)
                .foregroundColor(isToday ? .white : .primary)
                .background(
                    Circle().fill(
                        isToday
                            ? Color.blue
                            : (isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    )
                )
                .onTapGesture { onTap() }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                )
                .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
                    guard let itemProvider = providers.first else { return false }
                    itemProvider.loadObject(ofClass: String.self) { string, error in
                        if let error = error {
                            print("DEBUG: loadObject error:", error.localizedDescription)
                            return
                        }
                        guard let objectIDString = string else {
                            print("DEBUG: Could not cast item to String.")
                            return
                        }
                        DispatchQueue.main.async {
                            let result = onDropTask(objectIDString)
                            print("DEBUG: onDropTask closure returned:", result)
                        }
                    }
                    return true
                }
                .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
            
            // Red badge for # of tasks
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
