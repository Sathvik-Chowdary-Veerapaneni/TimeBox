// CalendarView.swift

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CalendarView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.managedObjectContext) var viewContext
    
    @State var currentMonth = Date()
    @State var selectedDate = Date()
    @State var showBacklog = false
    
    // For normal day tasks
    @State var tasksForSelectedDate: [TimeBox_Task] = []
    @State var dailyTaskCounts: [Date: Int] = [:]
    
    // For backlog tasks
    @State var backlogTasks: [TimeBox_Task] = []
    
    //Alert for Future Tasks
    @State private var showDoneAlert = false
        
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1) TOP Month Navigation
                MonthNavigationView(
                    currentMonth: currentMonth,
                    onPrev: {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        fetchMonthlyTaskCounts(for: currentMonth)
                    },
                    onNext: {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        fetchMonthlyTaskCounts(for: currentMonth)
                    },
                    showBacklog: showBacklog
                )
                
                // 2) DAYS GRID
                let daysInMonth = makeDaysInMonth(currentMonth)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
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
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // 3) BOTTOM
                if showBacklog {
                    BacklogListView(
                        backlogTasks: $backlogTasks,
                        deleteAction: deleteBacklogTasks
                    )
                } else {
                    DayTasksListView(
                        tasksForSelectedDate: $tasksForSelectedDate,
                        selectedDate: selectedDate,
                        deleteAction: deleteTasks
                    )
                }
            }
            .navigationTitle(showBacklog ? "OverDue" : "Calendar")
            .onAppear {
                // Initialize
                currentMonth = Date()
                fetchMonthlyTaskCounts(for: currentMonth)
                
                selectedDate = Date()
                tasksForSelectedDate = fetchTasks(for: selectedDate)
            }
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
             .alert("Cannot Move Done Task",
                   isPresented: $showDoneAlert,
                   actions: {
                       Button("OK", role: .cancel) { }
                   },
                   message: {
                       Text("This task is already marked as 'Done'—please change its status first.")
                   }
            )
        }
    }
    
    // MARK: - Drop Handling
    func handleDropTask(_ objectIDString: String, day: Date) -> Bool {
        guard
            let url = URL(string: objectIDString),
            let objID = viewContext.persistentStoreCoordinator?
                .managedObjectID(forURIRepresentation: url),
            let droppedTask = try? viewContext.existingObject(with: objID) as? TimeBox_Task
        else { return false }
        
          // If it's Done, show alert & refuse the drop
        if droppedTask.status == "Done" {
            print("DEBUG: Task is 'Done' -> cannot move to a future date.")
            showDoneAlert = true
            return false
        }
        
        // Disallow dropping on the past
        let todayStart = Calendar.current.startOfDay(for: Date())
        let thisDay = Calendar.current.startOfDay(for: day)
        if thisDay < todayStart {
            print("DEBUG: Disallow drop on a past date.")
            return false
        }
        
        let oldDate = droppedTask.startTime
        
        // If old date was today, remove from Home
        if let oldDate = oldDate, Calendar.current.isDate(oldDate, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // Reschedule in Core Data
        taskVM.rescheduleTask(with: objectIDString, to: day)
        
        // If new date is today, update Home
        if Calendar.current.isDate(day, inSameDayAs: Date()) {
            taskVM.fetchTodayTasks()
        }
        
        // UI updates
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
    
    // MARK: - Deletions
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
                let key = Calendar.current.startOfDay(for: st)
                dailyTaskCounts[key] = max(0, (dailyTaskCounts[key] ?? 0) - 1)
            }
            taskVM.deleteTask(task)
        }
    }
}
