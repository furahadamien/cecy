//
//  cecyApp.swift
//  cecy
//
//  Created by Furaha Damien on 9/29/26.
//

import SwiftUI

@main
struct cecyApp: App {
    @State private var session = TrackerSession.live()

    var body: some Scene {
        WindowGroup {
            TrackerRootView(session: session)
        }
    }
}
