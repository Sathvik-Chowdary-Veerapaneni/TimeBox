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
    
    // NEW: A dictionary that holds the number of tasks for each "startOfDay" in the current month
    @State private var dailyTaskCounts: [Date: Int] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) MONTH NAVIGATION at top
                HStack {
                    Button("< Prev") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        print("DEBUG: Moved to previous month:", currentMonth)
                        
                        // NEW: Re-fetch counts for the new currentMonth
                        fetchMonthlyTaskCounts(for: currentMonth)
                    }
                    Spacer()
                    Text(formatMonth(currentMonth))
                        .font(.headline)
                    Spacer()
                    Button("Next >") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        print("DEBUG: Moved to next month:", currentMonth)
                        
                        // NEW: Re-fetch counts for the new currentMonth
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
                            // NEW: Pass the count to the DayCellView
                            dayTaskCount: taskCount,
                            onTap: {
                                // When user taps a day, fetch tasks for that day
                                selectedDate = day
                                tasksForSelectedDate = fetchTasks(for: day)
                                print("DEBUG: Tapped day:", day,
                                      "Fetched tasks for:", dateString(day),
                                      "Count:", tasksForSelectedDate.count)
                            },
                            onDropTask: { objectIDString -> Bool in
                                // Drag-and-drop logic here...
                                print("DEBUG: onDropTask triggered with objectID:", objectIDString)
                                
                                // 1) Convert dropped text to an NSManagedObjectID
                                guard
                                    let url = URL(string: objectIDString),
                                    let objID = viewContext.persistentStoreCoordinator?
                                        .managedObjectID(forURIRepresentation: url),
                                    let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
                                else {
                                    print("DEBUG: Failed to convert objectIDString -> NSManagedObjectID -> TimeBox_Task")
                                    return false
                                }
                                
                                // 2) Capture old date
                                let oldDate = droppedTask.startTime
                                print("DEBUG: Found droppedTask with oldDate =", String(describing: oldDate))
                                
                                // 3) Update in Core Data & Calendar
                                taskVM.rescheduleTask(with: objectIDString, to: day)
                                
                                // 4) UI: remove from old date if old date is currently selected
                                if let oldDate = oldDate,
                                   Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
                                    print("DEBUG: Removing droppedTask from tasksForSelectedDate (was on old date).")
                                    tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
                                }
                                
                                // 5) UI: if the new date is selected, show the moved task
                                if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
                                    tasksForSelectedDate.append(droppedTask)
                                }
                                
                                // NEW: Decrement the old date's count, increment the new date's count
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
                .animation(nil, value: dailyTaskCounts) // or tasksForSelectedDate
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // 3) SCROLLABLE TASKS BELOW
                if tasksForSelectedDate.isEmpty {
                    Text("No tasks for \(dateString(selectedDate)).")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(tasksForSelectedDate, id: \.objectID) { task in
                                HStack {
                                    Text(task.title ?? "Untitled")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                )
                                // Provide objectID as plain text for .onDrop
                                .onDrag(
                                    {
                                        // Provide the item to drag
                                        let objectIDString = task.objectID.uriRepresentation().absoluteString
                                        let provider = NSItemProvider(object: objectIDString as NSString)
                                        return provider
                                    },
                                    preview: {
                                        // Provide a minimal or custom view. Here, an invisible 1×1 shape.
                                        Color.clear
                                            .frame(width: 1, height: 1)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Calendar")
            .onAppear {
                // NEW: When CalendarView first appears, fetch monthly counts
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
        formatter.dateFormat = "LLLL yyyy" // e.g. "January 2025"
        return formatter.string(from: date)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Fetch tasks for the currently selected day
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
    
    // NEW: Fetch all tasks in the month once, then group them by "startOfDay"
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
            self.dailyTaskCounts = counts
            print("DEBUG: fetchMonthlyTaskCounts -> dictionary updated for", formatMonth(month))
        } catch {
            print("Error fetching monthly tasks: \(error)")
            dailyTaskCounts = [:]
        }
    }
}

// MARK: - DayCellView
struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    
    // NEW: We pass the day's task count here
    let dayTaskCount: Int
    
    let onTap: () -> Void
    let onDropTask: (String) -> Bool
    
    @State private var isTargeted = false
    
    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        
        ZStack(alignment: .topTrailing) {
            // The base day text
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
                .onTapGesture {
                    onTap()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                )
                // onDrop for tasks
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
                // Slight highlight while dragging
                .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
            
            // NEW: Red badge if there's a nonzero count
            if dayTaskCount > 0 {
                Text("\(dayTaskCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red)
                    .clipShape(Circle())
                    // Adjust offset so it sits nicely at top-right
                    .offset(x: 9.5, y: -10)
            }
        }
    }
}

#if DEBUG
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create an in-memory Core Data context for preview
        let context = PersistenceController(inMemory: true).container.viewContext
        
        // 2) Create a mock TaskViewModel with that context
        let mockTaskVM = TaskViewModel(context: context)
        
        // 3) (Optional) Insert some mock tasks to see them in the calendar
        let sampleTask = TimeBox_Task(context: context)
        sampleTask.title = "Preview Task"
        sampleTask.startTime = Date()
        try? context.save()
        
        // 4) Return the CalendarView with environment objects
        return CalendarView()
            .environment(\.managedObjectContext, context)
            .environmentObject(mockTaskVM)
    }
}
#endif
