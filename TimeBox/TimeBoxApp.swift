//
//  TimeBoxApp.swift
//  TimeBox
//
//  Created by Wolverine on 1/6/25.
//

import SwiftUI

@main
struct TimeBoxApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
