//
//  PeripheralAppCoordinator.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  Coordinator layer for the peripheral app. It creates dependencies once and
//  passes them into the current SwiftUI screen.
//

import SwiftUI

/// Composes peripheral dependencies and chooses the active screen.
///
/// Production reason: views should not create infrastructure objects directly.
/// The coordinator keeps object lifetimes predictable and routing extensible.
struct PeripheralAppCoordinator: View {
    @StateObject private var router = PeripheralRouter()

    // CoreBluetooth delegates must stay alive, so the manager is a StateObject.
    @StateObject private var manager: PeripheralManager

    // The view model formats manager data for display.
    private let viewModel: PeripheralDashboardViewModel

    init() {
        let manager = PeripheralManager()
        _manager = StateObject(wrappedValue: manager)
        viewModel = PeripheralDashboardViewModel(manager: manager)
    }

    var body: some View {
        NavigationStack {
            switch router.route {
            case .dashboard:
                ContentView(viewModel: viewModel, manager: manager)
            }
        }
        .environmentObject(router)
    }
}
