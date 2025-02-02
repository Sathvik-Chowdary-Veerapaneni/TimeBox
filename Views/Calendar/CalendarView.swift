//
// CalendarView.swift
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CalendarView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.managedObjectContext) var viewContext

    @State private var selectedTask: TimeBox_Task? = nil
    @State private var showTaskPopup = false

    // Month navigation
    @State  var currentMonth = Date()
    @State  var selectedDate = Date()
    @State  var showBacklog = false
    
    // --- Search State ---
    @State  var showSearch = false
    @State  var searchText = ""
    @State  var searchResults: [TimeBox_Task] = []
    
    // Day-based tasks
    @State  var tasksForSelectedDate: [TimeBox_Task] = []
    @State  var backlogTasks: [TimeBox_Task] = []
    @State var dailyTaskCounts: [Date: Int] = [:]
    
    // Alert for done-task drag
    @State  var showDoneAlert = false
    
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
                       // Normal calendar mode
if tasksForSelectedDate.isEmpty {
    Text("No tasks for \(dateString(selectedDate)).")
        .foregroundColor(.secondary)
        .padding()
    Spacer()
} else {
    List {
        ForEach(tasksForSelectedDate, id: \.objectID) { task in
            HStack(spacing: 8) {
                // Task name
                Text(task.title ?? "Untitled")
                    .font(.headline)
                
                Spacer()
                
                // Show status icon if any
                if let status = task.status, !status.isEmpty {
                    switch status {
                    case "Done":
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    case "InProgress":
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                    case "Postpone":
                        Image(systemName: "hourglass")
                            .foregroundColor(.orange)
                    default:
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.gray)
                    }
                }
    
            }
            .contentShape(Rectangle()) // Ensures tap/drag works on entire row
            
            // 1) Single-tap -> open TaskDescriptionPopup
            .onTapGesture {
                selectedTask = task
                showTaskPopup = true
            }
            
            // 2) Drag & Drop (flicker-free preview)
            .onDrag(
                {
                    
                    // HapticManager.shared.playHaptic(.impactMedium)
                    

                    let taskID = task.objectID.uriRepresentation().absoluteString
                    return NSItemProvider(object: taskID as NSString)
                },
                preview: {
                    // Transparent preview
                    Color.clear.frame(width: 1, height: 1)
                }
            )
        }
        .onDelete(perform: deleteTasks)
    }
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
                        Button {
                            showBacklog.toggle()
                            if showBacklog {
                                backlogTasks = fetchBacklogTasks()
                            }
                        } label: {
                            if showBacklog {
                                Image(systemName: "calendar")
                            } else {
                                ZStack(alignment: .topTrailing) {
                                    // The base icon
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    
                                    // The badge, only if backlogTasks > 0
                                    if backlogTasks.count > 0 {
                                        Text("\(backlogTasks.count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -3)
                                    }
                                }
                            }
                        }

                        // --- BELOW is your existing search button code ---
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
            // After the main VStack, or inside .toolbar, add:
        .sheet(item: $selectedTask) { task in
        TaskDescriptionPopup(task: task)
        .environment(\.managedObjectContext, viewContext)
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
