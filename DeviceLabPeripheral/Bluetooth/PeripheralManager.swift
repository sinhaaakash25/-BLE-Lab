//
//  PeripheralManager.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  CoreBluetooth implementation for the peripheral app. The peripheral is the
//  device that advertises a service and responds when a central reads, writes,
//  or subscribes to characteristics.
//

import Combine
import CoreBluetooth
import Foundation

/// CoreBluetooth service owner for the peripheral target.
///
/// SOLID note: this class has a single responsibility: BLE peripheral behavior.
/// It does not build SwiftUI views and does not decide presentation copy beyond
/// short status messages needed by the UI.
final class PeripheralManager: NSObject, ObservableObject {
    // MARK: - Published UI State

    /// Current hardware/permission state reported by CoreBluetooth.
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    /// True after CoreBluetooth confirms advertising started successfully.
    @Published private(set) var isAdvertising = false

    /// Number of centrals currently subscribed to telemetry notifications.
    @Published private(set) var subscribedCentralCount = 0

    /// Latest telemetry value. The central can read or subscribe to this value.
    @Published private(set) var latestTelemetry = DeviceLabTelemetry(
        sequence: 0,
        batteryLevel: 96,
        temperatureCelsius: 22.4,
        uptimeSeconds: 0,
        lastCommand: "None"
    )

    /// Last command written by the central app.
    @Published private(set) var lastCommand = "None"

    /// Short status text for progress, errors, and user feedback.
    @Published private(set) var statusMessage = "Preparing Bluetooth"

    // MARK: - Private BLE State

    private let peripheralName = "DeviceLab-Sensor"
    private let deviceInfo = DeviceLabPeripheralInfo(
        name: "DeviceLab Sensor",
        firmwareVersion: "1.0.0",
        manufacturer: "DeviceLab"
    )

    private var peripheralManager: CBPeripheralManager!
    private var telemetryCharacteristic: CBMutableCharacteristic?
    private var commandCharacteristic: CBMutableCharacteristic?
    private var configurationCharacteristic: CBMutableCharacteristic?
    private var deviceInfoCharacteristic: CBMutableCharacteristic?
    private var telemetryTimer: Timer?
    private var uptimeSeconds = 0

    override init() {
        super.init()

        // Passing `self` as delegate means CoreBluetooth will call the extension
        // methods below for power, advertising, read, write, and subscribe events.
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    deinit {
        telemetryTimer?.invalidate()
        peripheralManager?.stopAdvertising()
    }

    // MARK: - Public Actions

    /// Allows the UI to retry advertising after Bluetooth has been toggled.
    func start() {
        guard bluetoothState == .poweredOn else {
            statusMessage = "Bluetooth must be powered on before advertising"
            return
        }

        if telemetryCharacteristic == nil {
            configureService()
        } else {
            startAdvertising()
        }
    }

    /// Stops advertising manually. Existing connections/subscriptions are managed by iOS.
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        statusMessage = "Advertising stopped"
    }

    // MARK: - Service Setup

    /// Creates the custom GATT service and its characteristics.
    ///
    /// Basic BLE idea: central devices discover the service first, then discover
    /// the characteristics inside it. Each characteristic declares what operations
    /// are allowed, such as read, write, or notify.
    private func configureService() {
        let telemetry = CBMutableCharacteristic(
            type: BLEUUIDs.telemetry,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        let command = CBMutableCharacteristic(
            type: BLEUUIDs.command,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let configuration = CBMutableCharacteristic(
            type: BLEUUIDs.configuration,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        let deviceInfo = CBMutableCharacteristic(
            type: BLEUUIDs.deviceInfo,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: BLEUUIDs.deviceLabService, primary: true)
        service.characteristics = [telemetry, command, configuration, deviceInfo]

        telemetryCharacteristic = telemetry
        commandCharacteristic = command
        configurationCharacteristic = configuration
        deviceInfoCharacteristic = deviceInfo

        peripheralManager.removeAllServices()
        peripheralManager.add(service)
        statusMessage = "Registering BLE service"
    }

    /// Starts advertising so nearby centrals can discover this service.
    private func startAdvertising() {
        guard !peripheralManager.isAdvertising else { return }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: peripheralName,
            CBAdvertisementDataServiceUUIDsKey: [BLEUUIDs.deviceLabService]
        ]

        peripheralManager.startAdvertising(advertisementData)
        statusMessage = "Starting advertising"
    }

    // MARK: - Telemetry

    /// Starts a timer only while at least one central is subscribed.
    private func startTelemetryUpdates() {
        guard telemetryTimer == nil else { return }

        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.publishTelemetryTick()
        }
        publishTelemetryTick()
    }

    /// Stops telemetry generation when there are no subscribers.
    private func stopTelemetryUpdatesIfNeeded() {
        guard subscribedCentralCount == 0 else { return }

        telemetryTimer?.invalidate()
        telemetryTimer = nil
    }

    /// Creates a new telemetry sample and notifies subscribed centrals.
    private func publishTelemetryTick() {
        uptimeSeconds += 2

        latestTelemetry = DeviceLabTelemetry(
            sequence: latestTelemetry.sequence + 1,
            batteryLevel: max(0, latestTelemetry.batteryLevel - (latestTelemetry.sequence % 12 == 0 ? 1 : 0)),
            temperatureCelsius: 22.0 + Double(latestTelemetry.sequence % 9) * 0.2,
            uptimeSeconds: uptimeSeconds,
            lastCommand: lastCommand
        )

        guard let telemetryData = latestTelemetry.encoded,
              let telemetryCharacteristic else {
            return
        }

        peripheralManager.updateValue(
            telemetryData,
            for: telemetryCharacteristic,
            onSubscribedCentrals: nil
        )
    }

    // MARK: - Write Handling

    /// Handles commands written by the central to the command characteristic.
    private func handleCommand(_ request: CBATTRequest) {
        guard let data = request.value,
              let commandText = String(data: data, encoding: .utf8) else {
            peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
            return
        }

        lastCommand = commandText
        statusMessage = "Received command: \(commandText)"

        if commandText == DeviceLabCommand.resetCounter.rawValue {
            uptimeSeconds = 0
            latestTelemetry = DeviceLabTelemetry(
                sequence: 0,
                batteryLevel: latestTelemetry.batteryLevel,
                temperatureCelsius: latestTelemetry.temperatureCelsius,
                uptimeSeconds: 0,
                lastCommand: commandText
            )
        }

        peripheralManager.respond(to: request, withResult: .success)
        publishTelemetryTick()
    }

    /// Handles simple text configuration written by the central.
    private func handleConfiguration(_ request: CBATTRequest) {
        guard let data = request.value,
              let configuration = String(data: data, encoding: .utf8),
              !configuration.isEmpty else {
            peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
            return
        }

        statusMessage = "Updated configuration: \(configuration)"
        peripheralManager.respond(to: request, withResult: .success)
    }

    /// Shared helper for read responses so error handling stays consistent.
    private func respond(to request: CBATTRequest, with data: Data?) {
        guard let data else {
            peripheralManager.respond(to: request, withResult: .unlikelyError)
            return
        }

        request.value = data
        peripheralManager.respond(to: request, withResult: .success)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension PeripheralManager: CBPeripheralManagerDelegate {
    /// First callback CoreBluetooth sends. Advertising must wait until powered on.
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        bluetoothState = peripheral.state

        switch peripheral.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            configureService()
        case .poweredOff:
            isAdvertising = false
            subscribedCentralCount = 0
            telemetryTimer?.invalidate()
            telemetryTimer = nil
            statusMessage = "Bluetooth is powered off"
        case .unauthorized:
            statusMessage = "Bluetooth permission is required"
        case .unsupported:
            statusMessage = "Bluetooth LE peripheral mode is unsupported"
        case .resetting:
            statusMessage = "Bluetooth is resetting"
        case .unknown:
            statusMessage = "Bluetooth state is unknown"
        @unknown default:
            statusMessage = "Bluetooth entered a new unknown state"
        }
    }

    /// Called after the GATT service has been registered with CoreBluetooth.
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            statusMessage = "Service registration failed: \(error.localizedDescription)"
            return
        }

        statusMessage = "Service registered"
        startAdvertising()
    }

    /// Called after advertising starts or fails.
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            isAdvertising = false
            statusMessage = "Advertising failed: \(error.localizedDescription)"
            return
        }

        isAdvertising = true
        statusMessage = "Advertising as \(peripheralName)"
    }

    /// Called when a central reads one of this peripheral's characteristics.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
        case BLEUUIDs.telemetry:
            respond(to: request, with: latestTelemetry.encoded)
        case BLEUUIDs.deviceInfo:
            respond(to: request, with: deviceInfo.encoded)
        case BLEUUIDs.configuration:
            respond(to: request, with: Data("interval=2s".utf8))
        default:
            peripheralManager.respond(to: request, withResult: .requestNotSupported)
        }
    }

    /// Called when a central writes one or more characteristic values.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            switch request.characteristic.uuid {
            case BLEUUIDs.command:
                handleCommand(request)
            case BLEUUIDs.configuration:
                handleConfiguration(request)
            default:
                peripheralManager.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }

    /// Called when a central subscribes to telemetry notifications.
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == BLEUUIDs.telemetry else { return }

        subscribedCentralCount += 1
        statusMessage = "Central subscribed to telemetry"
        startTelemetryUpdates()
    }

    /// Called when a central unsubscribes from telemetry notifications.
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == BLEUUIDs.telemetry else { return }

        subscribedCentralCount = max(0, subscribedCentralCount - 1)
        statusMessage = "Central unsubscribed from telemetry"
        stopTelemetryUpdatesIfNeeded()
    }
}
