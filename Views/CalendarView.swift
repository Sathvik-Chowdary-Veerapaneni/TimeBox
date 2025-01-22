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
                        // Optionally reset selected date & tasks, if you want
                    }
                    Spacer()
                    Text(formatMonth(currentMonth))
                        .font(.headline)
                    Spacer()
                    Button("Next >") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
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
                                // Update the selected date & fetch tasks
                                selectedDate = day
                                tasksForSelectedDate = fetchTasks(for: day)
                            },
                            onDropTask: { objectIDString in
                                // When a task is dragged onto this day
                                taskVM.rescheduleTask(with: objectIDString, to: day)
                                // If user dropped onto the selected date, refresh the bottom list
                                if Calendar.current.isDate(day, inSameDayAs: selectedDate) {
                                    tasksForSelectedDate = fetchTasks(for: day)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                // No fixed height; it expands based on screen size, pinned at top
                
                Divider()
                
                // 3) SCROLLABLE TASKS BELOW
                // This list doesn't move the calendar; only the tasks area scrolls
                if tasksForSelectedDate.isEmpty {
                    Text("No tasks for \(dateString(selectedDate)).")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(tasksForSelectedDate, id: \.objectID) { task in
                                // A simple row showing the task, draggable
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
                                .onDrag {
                                    // So user can drag from the list onto a day
                                    let objectIDString = task.objectID.uriRepresentation().absoluteString
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
    
    // Basic fetch for tasks that have .startTime == selected day
    // If you want postponed tasks counted here, add that logic
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
        // You could also OR this with postponeDate if needed.
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
}

// MARK: - DayCellView
/// Renders a single day as a circle with a thin outline, and onDrop to reschedule tasks.
struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    
    // Callback if user taps this day
    let onTap: () -> Void
    // Callback if user drops a task onto this day
    let onDropTask: (String) -> Void
    
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
            // Provide a thin outline for the day cell
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
            )
            // Accept dropped tasks
            .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
                guard let itemProvider = providers.first else { return false }
                itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    guard let objectIDString = item as? String else { return }
                    DispatchQueue.main.async {
                        onDropTask(objectIDString)
                    }
                }
                return true
            }
            .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
    }
}
