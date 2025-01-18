//
//  TimeBox_Task+CoreDataProperties.swift
//  TimeBox
//
//  Created by YourName on Date.
//
//

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
}

extension TimeBox_Task: Identifiable {}
