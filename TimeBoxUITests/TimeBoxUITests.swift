//
//  TimeBoxUITests.swift
//  TimeBoxUITests
//
//  Created by Wolverine on 1/6/25.
//

import XCTest

final class TimeBoxUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAddNewTaskFlow() throws {
        // 1. Tap "Add New Task" button
        app.buttons["Add New Task"].tap()
        
        // 2. Enter a title in the text field
        let titleField = app.textFields["Enter title..."]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("UITest Demo Task")
        
        // 3. Enter some description if needed
        let descEditor = app.textViews.firstMatch
        descEditor.tap()
        descEditor.typeText("This is a test created by UI automation.\n")
        
        // 4. Tap "Save"
        app.buttons["Save"].tap()
        
        // 5. Verify new task appears in the list
        let newTaskCell = app.staticTexts["UITest Demo Task"]
        XCTAssertTrue(newTaskCell.waitForExistence(timeout: 5),
                      "New task should appear in the main list.")
    }
}
