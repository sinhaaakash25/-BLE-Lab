//
//  CentralDashboardViewModel.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  View-model layer for the central dashboard. It converts raw Bluetooth state
//  into display text and exposes user actions as simple methods.
//

import CoreBluetooth
import Foundation

/// Presentation model for the central dashboard.
///
/// Basic MVVM rule used here: the view model formats values and forwards user
/// intent; the `CentralManager` performs the actual CoreBluetooth work.
final class CentralDashboardViewModel {
    private let manager: CentralManager

    init(manager: CentralManager) {
        self.manager = manager
    }

    /// Text shown for the current Bluetooth power/permission state.
    var bluetoothStatus: String {
        description(for: manager.bluetoothState)
    }

    /// Shows the connected peripheral name, or a safe empty-state message.
    var connectionStatus: String {
        manager.connectedDeviceName ?? "Not Connected"
    }

    /// Shows whether the central is actively scanning.
    var scanStatus: String {
        manager.isScanning ? "Scanning" : "Idle"
    }

    /// Converts the latest telemetry model into one compact UI line.
    var telemetrySummary: String {
        guard let telemetry = manager.telemetry else {
            return "No telemetry yet"
        }

        return "#\(telemetry.sequence) | \(telemetry.batteryLevel)% | \(String(format: "%.1f", telemetry.temperatureCelsius)) C | \(telemetry.uptimeSeconds)s | \(telemetry.lastCommand)"
    }

    /// Converts the decoded peripheral info into one compact UI line.
    var deviceInfoSummary: String {
        guard let deviceInfo = manager.deviceInfo else {
            return "No device info yet"
        }

        return "\(deviceInfo.name) | FW \(deviceInfo.firmwareVersion) | \(deviceInfo.manufacturer)"
    }

    /// Latest human-readable status from the Bluetooth layer.
    var statusMessage: String {
        manager.statusMessage
    }

    // MARK: - User Actions

    func startScanning() {
        manager.startScanning()
    }

    func stopScanning() {
        manager.stopScanning()
    }

    func connect(to device: DiscoveredDevice) {
        manager.connect(to: device)
    }

    func disconnect() {
        manager.disconnect()
    }

    func send(_ command: DeviceLabCommand) {
        manager.send(command)
    }

    func updateReportingInterval(seconds: Int) {
        manager.updateReportingInterval(seconds: seconds)
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
