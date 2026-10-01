//
//  CentralAppCoordinator.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  Coordinator layer for the central app. In MVVM + Coordinator, the App creates
//  the coordinator, the coordinator creates dependencies, and views focus on UI.
//

import SwiftUI

/// Composes central dependencies and renders the active route.
///
/// Production reason: dependency creation stays in one place, so screens do not
/// need to know how Bluetooth managers, routers, or view models are built.
struct CentralAppCoordinator: View {
    // `@StateObject` keeps the same router instance alive while SwiftUI redraws.
    @StateObject private var router = CentralRouter()

    // The manager is long-lived because CoreBluetooth delegate callbacks depend
    // on this object staying in memory.
    @StateObject private var manager: CentralManager

    // The view model is a lightweight formatter/action wrapper around manager.
    private let viewModel: CentralDashboardViewModel

    init() {
        let manager = CentralManager()
        _manager = StateObject(wrappedValue: manager)
        viewModel = CentralDashboardViewModel(manager: manager)
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
