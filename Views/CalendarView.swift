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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) MONTH NAVIGATION at top
                HStack {
                    Button("< Prev") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        
                        // DEBUG:
                        print("DEBUG: Moved to previous month:", currentMonth)
                    }
                    Spacer()
                    Text(formatMonth(currentMonth))
                        .font(.headline)
                    Spacer()
                    Button("Next >") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        
                        // DEBUG:
                        print("DEBUG: Moved to next month:", currentMonth)
                    }
                }
                .padding()
                
                // 2) DAYS GRID pinned at top
                let days = makeDaysInMonth(currentMonth)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        DayCellView(
                            day: day,
                            selectedDate: selectedDate,
                            onTap: {
                                // When user taps a day, fetch tasks for that day
                                selectedDate = day
                                tasksForSelectedDate = fetchTasks(for: day)
                                
                                // DEBUG:
                                print("DEBUG: Tapped day:", day,
                                      "Fetched tasks for:", dateString(day),
                                      "Count:", tasksForSelectedDate.count)
                            },
                            // Must return Bool to match .onDrop's signature
                            onDropTask: { objectIDString -> Bool in
                                // DEBUG:
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
                                
                                // 2) Capture old date before changing it
                                let oldDate = droppedTask.startTime
                                print("DEBUG: Found droppedTask with oldDate =", String(describing: oldDate))
                                
                                // 3) Update in Core Data & Calendar
                                taskVM.rescheduleTask(with: objectIDString, to: day)
                                
                                // 4) UI update: remove from old date if old date is currently selected
                                if let oldDate = oldDate,
                                   Calendar.current.isDate(oldDate, inSameDayAs: selectedDate) {
                                    print("DEBUG: Removing droppedTask from tasksForSelectedDate (was on old date).")
                                    tasksForSelectedDate.removeAll { $0.objectID == droppedTask.objectID }
                                } else {
                                    print("DEBUG: Old date not currently selected, no removal needed.")
                                }
                                
                                // 5) UI update: if the new date is selected, show the moved task
                                if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
                                    print("DEBUG: New date == selectedDate, appending to tasksForSelectedDate.")
                                    tasksForSelectedDate.append(droppedTask)
                                } else {
                                    print("DEBUG: New date != selectedDate, not appending to tasksForSelectedDate.")
                                }
                                
                                // DEBUG: Confirm the final count
                                print("DEBUG: tasksForSelectedDate count after drop =", tasksForSelectedDate.count)
                                return true
                            }
                        )
                    }
                }
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
                                .onDrag {
                                    let objectIDString = task.objectID.uriRepresentation().absoluteString
                                    print("DEBUG: onDrag started for:", objectIDString)
                                    return NSItemProvider(object: objectIDString as NSString)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Calendar")
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
    
    // Fetch tasks for a single day based on .startTime
    private func fetchTasks(for day: Date) -> [TimeBox_Task] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        
        // If you want to exclude postponed tasks from daily fetches, you might add it here:
        // request.predicate = NSPredicate(
        //     format: "startTime >= %@ AND startTime < %@ AND status != %@",
        //     startOfDay as CVarArg, endOfDay as CVarArg, "Postpone"
        // )
        
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
}

// MARK: - DayCellView
/// Single day cell with optional highlight if `day` is "today" or "selected".
struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    
    let onTap: () -> Void
    let onDropTask: (String) -> Bool // Must return Bool to match .onDrop's signature
    
    @State private var isTargeted = false
    
    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        
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
    }
}
