//
//  cecyApp.swift
//  cecy
//
//  Created by Furaha Damien on 9/29/26.
//

import SwiftUI
import CoreData

@main
struct cecyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
