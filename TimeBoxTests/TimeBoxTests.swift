//
//  TimeBoxTests.swift
//  TimeBoxTests
//
//  Created by Wolverine on 1/6/25.
//

import XCTest
@testable import TimeBox
import CoreData

final class TimeBoxTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // In-memory Core Data store for testing
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

    func testCreateNewTask() throws {
        // Create a task
        let task = TimeBox_Task(context: context)
        task.title = "Test Task"
        task.desc = "Some description"
        task.status = ""

        try context.save()

        // Fetch tasks
        let request = TimeBox_Task.fetchRequest()
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Test Task")
        XCTAssertEqual(results.first?.desc, "Some description")
        XCTAssertEqual(results.first?.status, "")
    }
    
    func testDefaultValues() throws {
        // If you want to ensure certain defaults (e.g. timeAllocated=0)
        let task = TimeBox_Task(context: context)
        try context.save()
        XCTAssertEqual(task.timeAllocated, 0)
        XCTAssertEqual(task.prioritySymbol, nil)
        XCTAssertEqual(task.priorityRank, 3) // 3 = no priority
    }
    
    func testUpdateStatus() throws {
        let task = TimeBox_Task(context: context)
        task.status = ""
        try context.save()

        task.status = "InProgress"
        try context.save()

        let request = TimeBox_Task.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertEqual(results.first?.status, "InProgress")
    }
}
