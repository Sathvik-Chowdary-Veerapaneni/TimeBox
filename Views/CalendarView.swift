import SwiftUI
import CoreData

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var currentMonth = Date() // used to track which month is displayed
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                // Month navigation
                HStack {
                    Button("< Prev") {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
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
                
                // Days grid
                let days = makeDaysInMonth(currentMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                    ForEach(days, id: \.self) { day in
                        Text("\(Calendar.current.component(.day, from: day))")
                            .foregroundColor(day < Date().startOfDay ? .gray : .primary)
                            .padding(8)
                            .onTapGesture {
                                if day >= Date().startOfDay {
                                    selectedDate = day
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                // Tasks for selected day
                TaskListForDayView(date: selectedDate)
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func makeDaysInMonth(_ date: Date) -> [Date] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: date) else { return [] }
        
        var days: [Date] = []
        var current = monthInterval.start
        while current < monthInterval.end {
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
}

fileprivate extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

// A subview that shows tasks for a given day
struct TaskListForDayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var date: Date
    
    @FetchRequest var tasks: FetchedResults<TimeBox_Task>
    
    init(date: Date) {
        _tasks = FetchRequest<TimeBox_Task>(
            sortDescriptors: [],
            predicate: NSPredicate(
                format: "startTime >= %@ AND startTime < %@",
                date.startOfDay as CVarArg,
                Calendar.current.date(byAdding: .day, value: 1, to: date.startOfDay)! as CVarArg
            )
        )
        self.date = date
    }
    
    var body: some View {
        List {
            ForEach(tasks) { task in
                Text(task.title ?? "Untitled")
            }
        }
    }
}
