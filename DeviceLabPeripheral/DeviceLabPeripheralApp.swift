//
//  DeviceLabPeripheralApp.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  App entry point for the BLE peripheral target. This target advertises a
//  custom service and exposes telemetry, command, configuration, and device info
//  characteristics to nearby central devices.
//

import SwiftUI

@main
struct DeviceLabPeripheralApp: App {
    var body: some Scene {
        WindowGroup {
            // The coordinator owns the screen dependencies for this target.
            PeripheralAppCoordinator()
        }
    }
}
