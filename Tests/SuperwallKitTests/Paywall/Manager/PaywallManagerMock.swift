//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

final class PaywallManagerMock: PaywallManager {
  var getPaywallError: Error?
  var getPaywallVc: PaywallViewController?

  override func getPaywallViewController(
    from request: PaywallRequest,
    isPreloading: Bool,
    delegate: PaywallViewControllerDelegateAdapter?
  ) async throws -> PaywallViewController {
    if let getPaywallError = getPaywallError {
      throw getPaywallError
    } else {
      return getPaywallVc!
    }
  }
}
