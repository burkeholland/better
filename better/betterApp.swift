//
//  betterApp.swift
//  better
//
//  Created by Thomas Burke on 2/5/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct betterApp: App {
    @State private var appState = AppState()
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: FirebaseApp.app()!.options.clientID!)
        _authService = State(initialValue: AuthService())
        
        #if DEBUG
        // Auto-populate API key from environment for testing
        if KeychainService.loadAPIKey() == nil,
           let envKey = ProcessInfo.processInfo.environment["OPEN_ROUTER_KEY"],
           !envKey.isEmpty {
            _ = KeychainService.saveAPIKey(envKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(authService)
        }
    }
}
