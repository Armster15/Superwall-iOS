//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

/// A request to get a paywall.
struct PaywallRequest {
  struct Overrides {
    /// The products to substitute into the response.
    var products: PaywallProducts?

    /// Whether to override the displaying of a free trial.
    var isFreeTrial: Bool?
  }

  /// The event data
  var eventData: EventData?

  /// The identifiers for the paywall and experiment.
  let responseIdentifiers: ResponseIdentifiers

  /// Overrides within the paywall.
  var overrides = Overrides()

  struct Injections {
    unowned let sessionEventsManager: SessionEventsManager
    unowned let storeKitManager: StoreKitManager
    unowned let configManager: ConfigManager
    unowned let network: Network
    unowned let debugManager: DebugManager
  }
  let injections: Injections

  /// The request publisher that fires just once.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
