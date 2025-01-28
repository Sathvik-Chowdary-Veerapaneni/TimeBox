import Foundation
import EventKit
import CoreData

class CalendarService {
    static let shared = CalendarService()
    
    private var eventStore = EKEventStore()
    private var calendarIdentifierKey = "TimeBoxCalendarIdentifier"
    
    private init() {}
    
    // 1. Request permission if not already granted
    func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
    
    // 2. Get or create the "TimeBox" calendar
    func getTimeBoxCalendar() -> EKCalendar? {
        if let savedID = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let savedCalendar = eventStore.calendar(withIdentifier: savedID) {
            return savedCalendar
        } else {
            return createTimeBoxCalendar()
        }
    }
    
    private func createTimeBoxCalendar() -> EKCalendar? {
        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "TimeBox"
        
        // Pick the first local source or default source
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else {
            return nil
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            UserDefaults.standard.setValue(newCalendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return newCalendar
        } catch {
            print("Error creating TimeBox calendar: \(error)")
            return nil
        }
    }
    
    // 3. Add event for a new TimeBox_Task
    func addEvent(for task: TimeBox_Task, in context: NSManagedObjectContext) -> String? {
        guard let calendar = getTimeBoxCalendar() else { return nil }
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        
        // Title & Times
        event.title = task.title ?? "Untitled"
        
        // Use startTime & endTime or fallback to 'timestamp' + timeAllocated
        let start = task.startTime ?? Date()
        let end   = task.endTime ?? start.addingTimeInterval(task.timeAllocated * 3600)
        event.startDate = start
        event.endDate   = end
        
        do {
            try eventStore.save(event, span: .thisEvent)
            task.eventIdentifier = event.eventIdentifier
            
            // Persist the updated task
            try context.save()
            return event.eventIdentifier
        } catch {
            print("Error adding event to calendar: \(error)")
            return nil
        }
    }
    
    // 4. Update the matching event when a task changes
    func updateEvent(for task: TimeBox_Task, in context: NSManagedObjectContext) -> Bool {
        guard let eventID = task.eventIdentifier,
              let event = eventStore.event(withIdentifier: eventID)
        else {
            // If no event found, you might choose to create a new one or just fail
            return false
        }
        
        event.title = task.title ?? "Untitled"
        let start = task.startTime ?? Date()
        let end   = task.endTime ?? start.addingTimeInterval(task.timeAllocated * 3600)
        event.startDate = start
        event.endDate   = end
        
        do {
            try eventStore.save(event, span: .thisEvent)
            // Save changes in Core Data if needed
            try context.save()
            return true
        } catch {
            print("Error updating calendar event: \(error)")
            return false
        }
    }
    
    // 5. Delete event when a task is removed
    func deleteEvent(for task: TimeBox_Task, in context: NSManagedObjectContext) -> Bool {
        guard let eventID = task.eventIdentifier,
              let event = eventStore.event(withIdentifier: eventID)
        else {
            return false
        }
        do {
            try eventStore.remove(event, span: .thisEvent)
            task.eventIdentifier = nil
            try context.save()
            return true
         } catch {
            print("Error deleting event: \(error)")
            return false
        }
    }
}
