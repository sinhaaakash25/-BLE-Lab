//
//  CentralManager.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  CoreBluetooth implementation for the central app. The central is the device
//  that scans, connects, discovers services, subscribes to notifications, and
//  writes commands to a peripheral.
//

import Combine
import CoreBluetooth
import Foundation

/// Lightweight UI model for one discovered BLE peripheral.
///
/// `CBPeripheral` is kept private inside the manager so SwiftUI does not depend
/// directly on CoreBluetooth reference objects.
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
}

/// CoreBluetooth owner for the central target.
///
/// SOLID note: this class has a single responsibility: BLE central behavior. It
/// publishes state for the UI, but it does not build views or format UI strings.
final class CentralManager: NSObject, ObservableObject {
    // MARK: - Published UI State

    /// Current hardware/permission state reported by CoreBluetooth.
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    /// True while `CBCentralManager` is scanning for peripherals.
    @Published private(set) var isScanning = false

    /// Devices matching `BLEUUIDs.deviceLabService` that have been discovered.
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []

    /// Non-nil when the central is connected to a peripheral.
    @Published private(set) var connectedDeviceName: String?

    /// Latest telemetry decoded from the peripheral's telemetry characteristic.
    @Published private(set) var telemetry: DeviceLabTelemetry?

    /// Device metadata decoded from the peripheral's device-info characteristic.
    @Published private(set) var deviceInfo: DeviceLabPeripheralInfo?

    /// Short status text for progress, errors, and user feedback.
    @Published private(set) var statusMessage = "Preparing Bluetooth"

    // MARK: - Private BLE State

    private var centralManager: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var telemetryCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    private var configurationCharacteristic: CBCharacteristic?
    private var deviceInfoCharacteristic: CBCharacteristic?

    override init() {
        super.init()

        // Passing `self` as delegate means CoreBluetooth will call the extension
        // methods below when Bluetooth state, scanning, and connection events occur.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Actions

    /// Starts scanning for peripherals advertising the DeviceLab service UUID.
    func startScanning() {
        guard bluetoothState == .poweredOn else {
            statusMessage = "Bluetooth must be powered on before scanning"
            return
        }

        discoveredDevices.removeAll()
        peripheralsByID.removeAll()

        centralManager.scanForPeripherals(
            withServices: [BLEUUIDs.deviceLabService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
        statusMessage = "Scanning for DeviceLab sensors"
    }

    /// Stops the scan to save battery and reduce duplicate UI updates.
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Scan stopped"
    }

    /// Connects to a device selected by the user.
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = peripheralsByID[device.id] else {
            statusMessage = "Device is no longer available"
            return
        }

        stopScanning()
        statusMessage = "Connecting to \(device.name)"
        centralManager.connect(peripheral)
    }

    /// Disconnects from the current peripheral, if one is connected.
    func disconnect() {
        guard let connectedPeripheral else { return }

        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    /// Writes a command into the peripheral's command characteristic.
    func send(_ command: DeviceLabCommand) {
        guard let connectedPeripheral,
              let commandCharacteristic else {
            statusMessage = "Connect before sending commands"
            return
        }

        // Prefer `.withResponse` when supported so the app receives write success
        // or failure in `didWriteValueFor`.
        let writeType: CBCharacteristicWriteType = commandCharacteristic.properties.contains(.write)
            ? .withResponse
            : .withoutResponse
        connectedPeripheral.writeValue(command.data, for: commandCharacteristic, type: writeType)
        statusMessage = "Sent command: \(command.title)"
    }

    /// Writes a simple text configuration payload to the peripheral.
    func updateReportingInterval(seconds: Int) {
        guard let connectedPeripheral,
              let configurationCharacteristic else {
            statusMessage = "Configuration characteristic is unavailable"
            return
        }

        let payload = Data("interval=\(seconds)s".utf8)
        connectedPeripheral.writeValue(payload, for: configurationCharacteristic, type: .withResponse)
        statusMessage = "Requested \(seconds)s reporting interval"
    }

    // MARK: - Private Helpers

    /// Clears all connection-specific state when the peripheral disconnects.
    private func resetConnectionState() {
        connectedDeviceName = nil
        connectedPeripheral = nil
        telemetryCharacteristic = nil
        commandCharacteristic = nil
        configurationCharacteristic = nil
        deviceInfoCharacteristic = nil
        telemetry = nil
        deviceInfo = nil
    }

    /// Adds a new discovered device or updates an existing row with a fresher RSSI.
    private func upsertDiscoveredDevice(_ peripheral: CBPeripheral, rssi: NSNumber) {
        let displayName = peripheral.name ?? "DeviceLab Sensor"
        let device = DiscoveredDevice(id: peripheral.identifier, name: displayName, rssi: rssi.intValue)

        peripheralsByID[peripheral.identifier] = peripheral

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }

        // Stronger signal appears first, which makes the nearest device easiest to tap.
        discoveredDevices.sort { first, second in
            first.rssi > second.rssi
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension CentralManager: CBCentralManagerDelegate {
    /// First callback CoreBluetooth sends. All scanning must wait until powered on.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            startScanning()
        case .poweredOff:
            isScanning = false
            resetConnectionState()
            statusMessage = "Bluetooth is powered off"
        case .unauthorized:
            statusMessage = "Bluetooth permission is required"
        case .unsupported:
            statusMessage = "Bluetooth LE central mode is unsupported"
        case .resetting:
            statusMessage = "Bluetooth is resetting"
        case .unknown:
            statusMessage = "Bluetooth state is unknown"
        @unknown default:
            statusMessage = "Bluetooth entered a new unknown state"
        }
    }

    /// Called each time the scan finds a matching advertising peripheral.
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        upsertDiscoveredDevice(peripheral, rssi: RSSI)
    }

    /// Called after a successful connection. Service discovery starts here.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? "DeviceLab Sensor"
        peripheral.delegate = self
        peripheral.discoverServices([BLEUUIDs.deviceLabService])
        statusMessage = "Connected to \(connectedDeviceName ?? "sensor")"
    }

    /// Called when CoreBluetooth cannot establish the connection.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
    }

    /// Called when the connection ends. The app resets state and resumes scanning.
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Disconnected"
        resetConnectionState()
        statusMessage = message
        startScanning()
    }
}

// MARK: - CBPeripheralDelegate

extension CentralManager: CBPeripheralDelegate {
    /// Called after `discoverServices`. Next step is discovering characteristics.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            statusMessage = "Service discovery failed: \(error.localizedDescription)"
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == BLEUUIDs.deviceLabService }) else {
            statusMessage = "DeviceLab service was not found"
            return
        }

        peripheral.discoverCharacteristics(
            [BLEUUIDs.telemetry, BLEUUIDs.command, BLEUUIDs.configuration, BLEUUIDs.deviceInfo],
            for: service
        )
    }

    /// Called after characteristic discovery. The central stores handles it needs.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            statusMessage = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }

        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case BLEUUIDs.telemetry:
                telemetryCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case BLEUUIDs.command:
                commandCharacteristic = characteristic
            case BLEUUIDs.configuration:
                configurationCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            case BLEUUIDs.deviceInfo:
                deviceInfoCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }

        statusMessage = "DeviceLab characteristics ready"
    }

    /// Called for both normal reads and notification updates.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            statusMessage = "Read failed: \(error.localizedDescription)"
            return
        }

        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BLEUUIDs.telemetry:
            telemetry = DeviceLabTelemetry.decode(from: data)
            statusMessage = telemetry == nil ? "Telemetry payload could not be decoded" : "Telemetry updated"
        case BLEUUIDs.deviceInfo:
            deviceInfo = DeviceLabPeripheralInfo.decode(from: data)
        case BLEUUIDs.configuration:
            statusMessage = String(data: data, encoding: .utf8) ?? "Configuration updated"
        default:
            break
        }
    }

    /// Called when a `.withResponse` write completes.
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            statusMessage = "Write failed: \(error.localizedDescription)"
            return
        }

        statusMessage = "Write confirmed"
    }
}
