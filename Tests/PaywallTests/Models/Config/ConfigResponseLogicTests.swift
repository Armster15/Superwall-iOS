//
//  ConfigResponseLogicTests.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

class ConfigResponseLogicTests: XCTestCase {
  func testGetPaywallIds_v2Trigger_treatments() {
    let paywallId = "abc"
    let treatment = VariantTreatment.stub()
      .setting(\.paywallIdentifier, to: paywallId)
    let rule = TriggerRule.stub()
      .setting(\.variant, to: .treatment(treatment))
    let trigger = Trigger.stub()
      .setting(\.rules, to: [rule])

    let triggers = Set([trigger])

    let outcome = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)

    XCTAssertTrue(outcome.contains(paywallId))
  }

  func testGetPaywallIds_v2Trigger_holdouts() {
    let holdout = VariantHoldout.stub()
      .setting(\.variantId, to: "xyz")
    let rule = TriggerRule.stub()
      .setting(\.variant, to: .holdout(holdout))
    let trigger = Trigger.stub()
      .setting(\.rules, to: [rule])

    let triggers = Set([trigger])

    let outcome = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)

    XCTAssertTrue(outcome.isEmpty)
  }
}
