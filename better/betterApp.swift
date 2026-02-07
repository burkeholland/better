//
//  betterApp.swift
//  better
//
//  Created by Thomas Burke on 2/5/26.
//

import SwiftUI
import FirebaseCore

@main
struct betterApp: App {
    @State private var appState = AppState()
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(authService)
        }
    }
}
