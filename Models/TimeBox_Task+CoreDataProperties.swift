import Foundation
import CoreData

extension TimeBox_Task {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TimeBox_Task> {
        return NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
    }

    @NSManaged public var title: String?
    @NSManaged public var status: String?
    @NSManaged public var priority: Bool
    @NSManaged public var timeAllocated: Double
    @NSManaged public var recurrenceDays: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var sortIndex: Int16
    @NSManaged public var resolution: String?
    @NSManaged public var desc: String?
    @NSManaged public var prioritySymbol: String?   // "!", "!!", "!!!", or nil
    @NSManaged public var priorityRank: Int16       // 0=!, 1=!!, 2=!!!, 3=none
    @NSManaged public var eventIdentifier: String?  // Apple Calendar event ID
    @NSManaged public var startTime: Date?          // Task start time
    @NSManaged public var endTime: Date?            // Task end time
    
    // NEW postpone fields
    @NSManaged public var postponeDate: Date?       // The date/time to which the user postponed
    @NSManaged public var postponeReason: String?   // Reason for postponement
}

extension TimeBox_Task: Identifiable {}
