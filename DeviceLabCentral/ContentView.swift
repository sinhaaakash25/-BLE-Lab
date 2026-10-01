//
//  ContentView.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  SwiftUI dashboard for the central target. The screen shows Bluetooth state,
//  nearby peripherals, live telemetry, command buttons, and connection actions.
//

import CoreBluetooth
import SwiftUI

struct ContentView: View {
    // The view model formats values and exposes user actions.
    let viewModel: CentralDashboardViewModel

    // The view observes the manager so SwiftUI refreshes whenever BLE state changes.
    @ObservedObject var manager: CentralManager

    var body: some View {
        List {
            Section("Central") {
                statusRow(title: "Bluetooth", value: viewModel.bluetoothStatus)
                statusRow(title: "Scan", value: viewModel.scanStatus)
                statusRow(title: "Connection", value: viewModel.connectionStatus)
            }

            Section("Discovered Devices") {
                if manager.discoveredDevices.isEmpty {
                    Text("No DeviceLab sensors found")
                        .foregroundStyle(.secondary)
                } else {
                    // Each row represents one peripheral discovered during scanning.
                    ForEach(manager.discoveredDevices) { device in
                        Button {
                            viewModel.connect(to: device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.id.uuidString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Telemetry") {
                statusRow(title: "Latest", value: viewModel.telemetrySummary)
                statusRow(title: "Device", value: viewModel.deviceInfoSummary)
            }

            Section("Commands") {
                // Buttons come from the shared command enum, keeping UI and BLE aligned.
                ForEach(DeviceLabCommand.allCases) { command in
                    Button(command.title) {
                        viewModel.send(command)
                    }
                    .disabled(manager.connectedDeviceName == nil)
                }

                // Placeholder for a production interval control. The manager already
                // exposes the write method, so this can become interactive later.
                Stepper("Reporting: 2 seconds", value: .constant(2))
                    .disabled(true)
            }

            Section("Actions") {
                Button(manager.isScanning ? "Stop Scan" : "Start Scan") {
                    manager.isScanning ? viewModel.stopScanning() : viewModel.startScanning()
                }
                .disabled(manager.bluetoothState != .poweredOn)

                Button("Disconnect", role: .destructive) {
                    viewModel.disconnect()
                }
                .disabled(manager.connectedDeviceName == nil)
            }

            Section("Status") {
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("DeviceLab Central")
    }

    /// Small reusable row for label/value status information.
    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
