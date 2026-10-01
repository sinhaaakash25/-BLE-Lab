//
//  DeviceLabCentralApp.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  App entry point for the BLE central target. This target scans for the
//  peripheral app, connects to it, reads data, subscribes to telemetry, and
//  sends commands.
//

import SwiftUI

@main
struct DeviceLabCentralApp: App {
    var body: some Scene {
        WindowGroup {
            // The coordinator creates dependencies and decides which screen to show.
            CentralAppCoordinator()
        }
    }
}
