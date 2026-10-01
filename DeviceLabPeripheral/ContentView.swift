//
//  ContentView.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  SwiftUI dashboard for the peripheral target. The screen shows advertising
//  state, subscribed centrals, current telemetry, received commands, and actions.
//

import CoreBluetooth
import SwiftUI

struct ContentView: View {
    // The view model formats values and exposes button actions.
    let viewModel: PeripheralDashboardViewModel

    // The view observes the manager so SwiftUI refreshes when BLE state changes.
    @ObservedObject var manager: PeripheralManager

    var body: some View {
        List {
            Section("Peripheral") {
                statusRow(title: "Bluetooth", value: viewModel.bluetoothStatus)
                statusRow(title: "Advertising", value: viewModel.advertisingStatus)
                statusRow(title: "Subscribers", value: viewModel.subscriberStatus)
            }

            Section("Telemetry") {
                statusRow(title: "Latest", value: viewModel.telemetrySummary)
                statusRow(title: "Last Command", value: viewModel.lastCommand)
            }

            Section("Actions") {
                Button("Start Advertising") {
                    viewModel.startAdvertising()
                }
                .disabled(manager.bluetoothState != .poweredOn || manager.isAdvertising)

                Button("Stop Advertising", role: .destructive) {
                    viewModel.stopAdvertising()
                }
                .disabled(!manager.isAdvertising)
            }

            Section("Status") {
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("DeviceLab Sensor")
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
