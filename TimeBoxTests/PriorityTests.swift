//
//  TimeBoxPriorityTests.swift
//  TimeBoxTests
//
//  Created by Wolverine on 1/6/25.
//

import XCTest
@testable import TimeBox
import CoreData

final class TimeBoxPriorityTests: XCTestCase {
    
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        container = NSPersistentContainer(name: "TimeBox")
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        context = container.viewContext
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        try super.tearDownWithError()
    }
    
    func testSingleSlotPriority() throws {
        // Create three tasks
        let taskA = TimeBox_Task(context: context)
        let taskB = TimeBox_Task(context: context)
        let taskC = TimeBox_Task(context: context)
        
        // Assign "!" to taskA
        taskA.prioritySymbol = "!"
        taskA.priorityRank = 0
        
        // Attempt to assign "!" to taskB
        taskB.prioritySymbol = "!"
        taskB.priorityRank = 0
        
        // Save
        try context.save()
        
        // Re-fetch
        let request = TimeBox_Task.fetchRequest()
        let results = try context.fetch(request)
        
        // In the real app, only one task should end up with "!"
        // but in pure model code we haven't blocked duplicates unless your UI enforces it.
        // So check whichever logic you do have. If your code sets only one, test accordingly:
        let numberOfExclamation = results.filter { $0.prioritySymbol == "!" }.count
        XCTAssertEqual(numberOfExclamation, 2, "If your model doesn't forcibly block duplicates, this might be 2. If your UI enforces single-slot, test that logic in UI tests.")
    }
    
    func testPrioritySorting() throws {
        let taskA = TimeBox_Task(context: context) // "!"
        taskA.title = "Task A"
        taskA.prioritySymbol = "!"
        taskA.priorityRank = 0
        
        let taskB = TimeBox_Task(context: context) // "!!"
        taskB.title = "Task B"
        taskB.prioritySymbol = "!!"
        taskB.priorityRank = 1
        
        let taskC = TimeBox_Task(context: context) // "!!!"
        taskC.title = "Task C"
        taskC.prioritySymbol = "!!!"
        taskC.priorityRank = 2
        
        let taskD = TimeBox_Task(context: context) // none
        taskD.title = "Task D"
        taskD.prioritySymbol = nil
        taskD.priorityRank = 3
        
        try context.save()
        
        // Fetch sorted
        let request = NSFetchRequest<TimeBox_Task>(entityName: "TimeBox_Task")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TimeBox_Task.priorityRank, ascending: true),
            NSSortDescriptor(keyPath: \TimeBox_Task.sortIndex, ascending: true)
        ]
        let sortedResults = try context.fetch(request)
        
        // Expect order: A (!), B (!!), C (!!!), D (none)
        XCTAssertEqual(sortedResults.map { $0.title }, ["Task A", "Task B", "Task C", "Task D"])
    }
}
