//
//  PeripheralDashboardViewModel.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  View-model layer for the peripheral dashboard. It keeps SwiftUI free from
//  CoreBluetooth formatting details and forwards user actions to the manager.
//

import CoreBluetooth
import Foundation

/// Presentation model for the peripheral dashboard.
///
/// Basic MVVM rule used here: the view model prepares text for the view, while
/// `PeripheralManager` owns the real BLE peripheral behavior.
final class PeripheralDashboardViewModel {
    private let manager: PeripheralManager

    init(manager: PeripheralManager) {
        self.manager = manager
    }

    /// Text shown for the current Bluetooth power/permission state.
    var bluetoothStatus: String {
        description(for: manager.bluetoothState)
    }

    /// Text shown for advertising state.
    var advertisingStatus: String {
        manager.isAdvertising ? "Advertising" : "Not Advertising"
    }

    /// Text shown for central devices subscribed to telemetry notifications.
    var subscriberStatus: String {
        manager.subscribedCentralCount == 1
            ? "1 subscribed central"
            : "\(manager.subscribedCentralCount) subscribed centrals"
    }

    /// Compact summary of the most recent telemetry payload.
    var telemetrySummary: String {
        "#\(manager.latestTelemetry.sequence) | \(manager.latestTelemetry.batteryLevel)% | \(String(format: "%.1f", manager.latestTelemetry.temperatureCelsius)) C | \(manager.latestTelemetry.uptimeSeconds)s"
    }

    /// Last command received from the central app.
    var lastCommand: String {
        manager.lastCommand
    }

    /// Latest human-readable status from the Bluetooth layer.
    var statusMessage: String {
        manager.statusMessage
    }

    // MARK: - User Actions

    func startAdvertising() {
        manager.start()
    }

    func stopAdvertising() {
        manager.stopAdvertising()
    }

    /// Maps CoreBluetooth enum cases into copy that makes sense to app users.
    private func description(for state: CBManagerState) -> String {
        switch state {
        case .poweredOn:
            return "Bluetooth Ready"
        case .poweredOff:
            return "Bluetooth Off"
        case .unauthorized:
            return "Permission Required"
        case .unsupported:
            return "Unsupported"
        case .resetting:
            return "Resetting"
        case .unknown:
            return "Preparing Bluetooth"
        @unknown default:
            return "Unknown Bluetooth State"
        }
    }
}
