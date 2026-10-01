//
//  PeripheralRouter.swift
//  DeviceLabPeripheral
//
//  Author: Aakash Sinha
//  Created: 30/09/26
//
//  Router layer for the peripheral app. Keeping navigation state here makes the
//  app easier to grow without mixing routing into views or Bluetooth logic.
//

import Combine
import Foundation

/// Router for peripheral navigation.
///
/// There is only one screen today, but the same pattern supports future screens
/// such as logs, device settings, or advertising diagnostics.
final class PeripheralRouter: ObservableObject {
    /// The active screen in the peripheral target.
    @Published var route: PeripheralRoute = .dashboard
}

/// Every navigation destination supported by the peripheral target.
enum PeripheralRoute: Hashable {
    case dashboard
}
