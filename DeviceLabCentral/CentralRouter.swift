//
//  CentralRouter.swift
//  DeviceLabCentral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  Router layer for the central app. A router owns navigation state and keeps
//  navigation decisions separate from Bluetooth and presentation logic.
//

import Combine
import Foundation

/// Router for central navigation.
///
/// There is only one screen today, but keeping routing explicit makes adding a
/// details, logs, or settings screen later a small, isolated change.
final class CentralRouter: ObservableObject {
    /// The current screen route. SwiftUI can react when this value changes.
    @Published var route: CentralRoute = .dashboard
}

/// Every navigation destination supported by the central target.
enum CentralRoute: Hashable {
    case dashboard
}
