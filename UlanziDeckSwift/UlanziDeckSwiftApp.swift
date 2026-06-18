//
//  UlanziDeckSwiftApp.swift
//  UlanziDeckSwift
//
//  Created by iBobby on 2026-06-13.
//

import SwiftUI

@main
struct UlanziDeckSwiftApp: App {
    private let singleInstanceAcquired: Bool

    init() {
        singleInstanceAcquired = Self.isRunningTests || SingleInstanceGuard().acquireOrActivateExisting()
        if !singleInstanceAcquired {
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if singleInstanceAcquired {
                RootView()
            } else {
                EmptyView()
            }
        }
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
