import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var desc = ""
    @State private var showEmptyTitleAlert = false
    
    // 1. A date-only picker (no past dates).
    @State private var selectedDay = Date()
    
    // 2. Hour is 1–12, minute in steps of 5, and AM/PM.
    @State private var selectedHour = 12
    @State private var selectedMinute = 0
    @State private var selectedMeridiem = "AM"

    private let defaultStatus = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter title...", text: $title)
                    
                    TextEditor(text: $desc)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // DAY PICKER (disable dates before today).
                Section(header: Text("Day")) {
                    DatePicker(
                        "Select Day",
                        selection: $selectedDay,
                        in: Date()...,               // Disallow any date before today
                        displayedComponents: [.date] // Just the calendar part
                    )
                }
                
                // TIME PICKERS: 1–12, 0–55 (in steps of 5), AM/PM
                Section(header: Text("Start Time")) {
                    HStack(spacing: 16) {
                        // HOUR (1–12)
                        Picker("Hour", selection: $selectedHour) {
                            ForEach(1..<13) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // MINUTES (0, 5, 10, ... 55)
                        let minuteSteps = stride(from: 0, through: 55, by: 5).map { $0 }
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(minuteSteps, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // AM/PM
                        Picker("AM/PM", selection: $selectedMeridiem) {
                            Text("AM").tag("AM")
                            Text("PM").tag("PM")
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 100) // Adjust as desired
                }
            }
            .navigationBarTitle("New Task", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addTask()
                    }
                }
            }
            // Alert if title is empty
            .alert("No Title", isPresented: $showEmptyTitleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add a title for your task.")
            }
        }
    }
    
    // Combine the selected day, 1–12 hour, 0–55 minute, AM/PM into a single Date.
    private func addTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showEmptyTitleAlert = true
            return
        }
        
        guard let finalDate = makeCombinedDate(
            day: selectedDay,
            hour12: selectedHour,
            minute: selectedMinute,
            meridiem: selectedMeridiem
        ) else {
            print("Error combining date components.")
            return
        }
        
        let newTask = TimeBox_Task(context: viewContext)
        newTask.title = title
        newTask.desc = desc
        newTask.status = defaultStatus
        newTask.sortIndex = Int16((try? viewContext.count(for: TimeBox_Task.fetchRequest())) ?? 0)
        
        // Store final date/time
        newTask.startTime = finalDate

        do {
            try viewContext.save()
            // Sync with Apple Calendar if needed
            CalendarService.shared.addEvent(for: newTask, in: viewContext)
            dismiss()
        } catch {
            print("Error saving new task: \(error.localizedDescription)")
        }
    }
    
    /// Build a Date from day + 1–12 hour + minute + AM/PM.
    private func makeCombinedDate(day: Date, hour12: Int, minute: Int, meridiem: String) -> Date? {
        // Convert 1–12 hour plus AM/PM to 24-hour format
        var hour24 = hour12 % 12 // 1–12 -> 0–11
        if meridiem == "PM" {
            hour24 += 12 // 0–11 -> 12–23 for PM
        }
        
        // Extract year, month, and day from the chosen date
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour24
        components.minute = minute
        
        return Calendar.current.date(from: components)
    }
}
