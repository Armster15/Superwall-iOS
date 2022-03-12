//
//  PaywallResponseLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import StoreKit
import TPInAppReceipt

struct TriggerResponseIdentifiers {
  let paywallId: String?
  let experimentId: String?
  let variantId: String?
}

enum PaywallResponseLogic {
  enum PaywallCachingOutcome {
    case cachedResult(Result<PaywallResponse, NSError>)
    case enqueCompletionBlock(
      hash: String,
      completionBlocks: [PaywallResponseCompletionBlock]
    )
    case setCompletionBlock(hash: String)
  }
  struct PaywallErrorResponse {
    let handlers: [PaywallResponseCompletionBlock]
    let error: NSError
  }
  struct ProductProcessingOutcome {
    var variables: [Variable]
    var productVariables: [ProductVariable]
    var isFreeTrialAvailable: Bool?
    var resetFreeTrialOverride: Bool
  }

  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    let locale = DeviceHelper.shared.locale
    return "\(id)_\(locale)"
  }

  // swiftlint:disable:next function_body_length
  static func handleTriggerResponse(
    withPaywallId paywallId: String?,
    fromEvent event: EventData?,
    didFetchConfig: Bool
  ) throws -> TriggerResponseIdentifiers {
    guard didFetchConfig else {
      return TriggerResponseIdentifiers(
        paywallId: paywallId,
        experimentId: nil,
        variantId: nil
      )
    }
    guard let event = event else {
      return TriggerResponseIdentifiers(
        paywallId: paywallId,
        experimentId: nil,
        variantId: nil
      )
    }

    let triggerResponse = TriggerManager.handleEvent(event)

    switch triggerResponse {
    case .presentV1:
      return TriggerResponseIdentifiers(
        paywallId: paywallId,
        experimentId: nil,
        variantId: nil
      )
    case let .presentIdentifier(experimentIdentifier, variantIdentifier, paywallIdentifier):
      let outcome = TriggerResponseIdentifiers(
        paywallId: paywallIdentifier,
        experimentId: experimentIdentifier,
        variantId: variantIdentifier
      )

      Paywall.track(
        .triggerFire(
          triggerInfo: TriggerInfo(
            result: "present",
            experimentId: experimentIdentifier,
            variantId: variantIdentifier,
            paywallIdentifier: paywallIdentifier
          )
        )
      )
      return outcome
    case let .holdout(experimentId, variantId):
      let userInfo: [String: Any] = [
        "experimentId": experimentId,
        "variantId": variantId,
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Holdout",
          value: "This user was assigned to a holdout in a trigger experiment",
          comment: "ExperimentId: \(experimentId), VariantId: \(variantId)"
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4001,
        userInfo: userInfo
      )
      Paywall.track(
        .triggerFire(
          triggerInfo:
            TriggerInfo(
              result: "holdout",
              experimentId: experimentId,
              variantId: variantId
            )
        )
      )
      throw error
    case .noRuleMatch:
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No rule match",
          value: "The user did not match any rules configured for this trigger",
          comment: ""
        )
      ]
      Paywall.track(
        .triggerFire(
          triggerInfo: TriggerInfo(result: "no_rule_match")
        )
      )
      let error = NSError(
        domain: "com.superwall",
        code: 4000,
        userInfo: userInfo
      )
      throw error
    case .unknownEvent:
      // create the error
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Disabled",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWTriggerDisabled",
        code: 404,
        userInfo: userInfo
      )
      throw error
    }
  }

  // swiftlint:disable:next function_parameter_count
  static func searchForPaywallResponse(
    forEvent event: EventData?,
    withHash hash: String,
    identifiers triggerResponseIds: TriggerResponseIdentifiers?,
    inResultsCache resultsCache: [String: Result<PaywallResponse, NSError>],
    handlersCache: [String: [PaywallResponseCompletionBlock]],
    isDebuggerLaunched: Bool
  ) -> PaywallCachingOutcome {
    // If the response for request exists, return it
    if let result = resultsCache[hash],
      !isDebuggerLaunched {
        switch result {
        case .success(let response):
          var updatedResponse = response
          updatedResponse.experimentId = triggerResponseIds?.experimentId
          updatedResponse.variantId = triggerResponseIds?.variantId
          return .cachedResult(.success(updatedResponse))
        case .failure:
          return .cachedResult(result)
        }
    }

    // if the request is in progress, enque the completion handler and return
    if let handlers = handlersCache[hash] {
      return .enqueCompletionBlock(
        hash: hash,
        completionBlocks: handlers
      )
    }

    // If there are no requests in progress, store completion block and continue
    return .setCompletionBlock(hash: hash)
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    withHash hash: String,
    handlersCache: [String: [PaywallResponseCompletionBlock]]
  ) -> PaywallErrorResponse? {
    let isFromEvent = event != nil

    if let error = error as? URLSession.NetworkError,
      error == .notFound {
      Paywall.track(
        .paywallResponseLoadNotFound(
          fromEvent: isFromEvent,
          event: event
        )
      )
    } else {
      Paywall.track(
        .paywallResponseLoadFail(
          fromEvent: isFromEvent,
          event: event
        )
      )
    }

    if let handlers = handlersCache[hash] {
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )

      return PaywallErrorResponse(
        handlers: handlers,
        error: error)
    }

    return nil
  }

  static func getVariablesAndFreeTrial(
    fromProducts products: [Product],
    productsById: [String: SKProduct],
    isFreeTrialAvailableOverride: Bool?
  ) -> ProductProcessingOutcome {
    var variables: [Variable] = []
    var productVariables: [ProductVariable] = []
    var isFreeTrialAvailable: Bool?
    var resetFreeTrialOverride = false

    for product in products {
      guard let appleProduct = productsById[product.id] else {
        continue
      }

      let eventDataVariable = Variable(
        key: product.type.rawValue,
        value: appleProduct.eventData
      )
      variables.append(eventDataVariable)

      let productVariable = ProductVariable(
        key: product.type.rawValue,
        value: appleProduct.productVariables
      )
      productVariables.append(productVariable)

      if product.type == .primary {
        isFreeTrialAvailable = appleProduct.hasFreeTrial

        if let receipt = try? InAppReceipt.localReceipt() {
          let hasPurchased = receipt.containsPurchase(ofProductIdentifier: product.id)

          if hasPurchased,
            appleProduct.hasFreeTrial {
            isFreeTrialAvailable = false
          }
        }
        // use the override if it is set
        if let freeTrialOverride = isFreeTrialAvailableOverride {
          isFreeTrialAvailable = freeTrialOverride
          resetFreeTrialOverride = true
        }
      }
    }

    return ProductProcessingOutcome(
      variables: variables,
      productVariables: productVariables,
      isFreeTrialAvailable: isFreeTrialAvailable,
      resetFreeTrialOverride: resetFreeTrialOverride
    )
  }
}