//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit

extension Paywall {
  private static var queue = EventsQueue()

	@discardableResult
  static func track(
    _ name: String,
    _ params: [String: Any] = [:],
    _ custom: [String: Any] = [:],
    handleTrigger: Bool = true
  ) -> EventData {
    // Logger.superwallDebug(string: "[Track] \(name)")

    var eventParams: [String: Any] = [:]
    var delegateParams: [String: Any] = [:]
    delegateParams["isSuperwall"] = true

		// add a special property if it's one of ours
    let isStandardEvent = EventName(rawValue: name) != nil
    eventParams["$is_standard_event"] = isStandardEvent


    // TODO: Brian, determine if you want to allow nested

    for key in params.keys {
      if let value = clean(input: params[key]) {
        let key = "$\(key)"
        eventParams[key] = value
        delegateParams[key] = value // no $ for delegate methods
      }
    }

    for key in custom.keys {
      if let value = clean(input: custom[key]) {
        if key.starts(with: "$") {
          delegateParams[key] = value // if they wanna use a dollar sign in their own events, let them
          Logger.debug(
            logLevel: .info,
            scope: .events,
            message: "Dropping Key",
            info: ["key": key, "name": name, "reason": "$ signs not allowed"],
            error: nil
          )
        } else {
          eventParams[key] = value
        }
      } else {
        Logger.debug(
          logLevel: .debug,
          scope: .events,
          message: "Dropping Key",
          info: ["key": key, "name": name, "reason": "Failed to serialize value"],
          error: nil
        )
      }
    }

    // skip calling disallowed events on their own system likely not needed
    // custom events wont work because StandardEventName and InternalEventName won't exist with their own event name
    if EventName(rawValue: name) != nil {
      Paywall.delegate?.trackAnalyticsEvent?(withName: name, params: delegateParams)
      Logger.debug(
        logLevel: .debug,
        scope: .events,
        message: "Logged Event",
        info: eventParams
      )
    }

		if let event = StandardEventName(rawValue: name),
      event == .userAttributes {
      Storage.shared.addUserAttributes(eventParams)
		}

		let eventData = EventData(
      name: name,
      parameters: JSON(eventParams),
      createdAt: Date.init(timeIntervalSinceNow: 0).isoString
    )

		queue.addEvent(event: eventData.jsonData)
		if handleTrigger {
			Paywall.shared.handleTrigger(forEvent: eventData)
		}

		return eventData
  }

  private static func clean(input: Any?) -> Any? {
    if input is NSArray {
      return nil
    } else if input is NSDictionary {
      return nil
    } else {
      if let input = input {
        let json = JSON(input)
        if json.error == nil {
          return input
        } else {
          if let date = input as? Date {
            return date.isoString
          } else if let url = input as? URL {
            return url.absoluteString
          } else {
            return nil
          }
        }
      }
    }

    return nil
  }

  private static func eventParams(
    forProduct product: SKProduct?,
    paywallInfo: PaywallInfo,
    otherParams: [String: Any]? = nil
  ) -> [String: Any] {
    var output: [String: Any] = [
      "paywall_id": paywallInfo.id,
      "paywall_identifier": paywallInfo.identifier,
      "paywall_slug": paywallInfo.slug,
      "paywall_name": paywallInfo.name,
      "paywall_url": paywallInfo.url?.absoluteString ?? "unknown",
      "presented_by_event_name": paywallInfo.presentedByEventWithName as Any,
      "presented_by_event_id": paywallInfo.presentedByEventWithId as Any,
      "presented_by_event_timestamp": paywallInfo.presentedByEventAt as Any,
      "presented_by": paywallInfo.presentedBy as Any,
      "paywall_product_ids": paywallInfo.productIds.joined(separator: ","),
      "paywall_response_load_start_time": paywallInfo.responseLoadStartTime as Any,
      "paywall_response_load_complete_time": paywallInfo.responseLoadCompleteTime as Any,
      "paywall_response_load_duration": paywallInfo.responseLoadDuration as Any,
      "paywall_webview_load_start_time": paywallInfo.webViewLoadStartTime as Any,
      "paywall_webview_load_complete_time": paywallInfo.webViewLoadCompleteTime as Any,
      "paywall_webview_load_duration": paywallInfo.webViewLoadDuration as Any,
      "paywall_products_load_start_time": paywallInfo.productsLoadStartTime as Any,
      "paywall_products_load_complete_time": paywallInfo.productsLoadCompleteTime as Any,
      "paywall_products_load_duration": paywallInfo.productsLoadDuration as Any
    ]

    var loadingVars: [String: Any] = [:]
    for key in output.keys {
      if key.contains("_load_"),
        let output = output[key] {
        loadingVars[key] = output
      }
    }

    Logger.debug(
      logLevel: .debug,
      scope: .paywallEvents,
      message: "Paywall loading timestamps",
      info: loadingVars
    )

    let levels = ["primary", "secondary", "tertiary"]

    for (id, level) in levels.enumerated() {
      let key = "\(level)_product_id"
      output[key] = ""
      if id < paywallInfo.productIds.count {
        output[key] = paywallInfo.productIds[id]
      }
    }

    if let product = product {
      output["product_id"] = product.productIdentifier
      for key in product.legacyEventData.keys {
        if let value = product.legacyEventData[key] {
          output["product_\(key.camelCaseToSnakeCase())"] = value
        }
      }
    }

    if let otherParams = otherParams {
      for key in otherParams.keys {
        if let value = otherParams[key] {
          output[key] = value
        }
      }
    }

    return output
  }

  // swiftlint:disable:next function_body_length
  static func track(
    _ event: InternalEvent,
    _ customParams: [String: Any] = [:]
  ) {
    switch event {
    case .paywallWebviewLoadStart(let paywallInfo),
      .paywallWebviewLoadFail(let paywallInfo),
      .paywallWebviewLoadComplete(let paywallInfo),
      .paywallOpen(let paywallInfo),
      .paywallClose(let paywallInfo):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: eventParams(forProduct: nil, paywallInfo: paywallInfo),
        customParams: customParams
      )
    case let .transactionFail(paywallInfo, product, message):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: eventParams(
          forProduct: product,
          paywallInfo: paywallInfo,
          otherParams: ["message": message]
        ),
        customParams: customParams
      )
    case let .transactionRestore(paywallInfo, product):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: eventParams(forProduct: product, paywallInfo: paywallInfo),
        customParams: customParams
      )
    case let .transactionStart(paywallInfo, product),
      let .transactionAbandon(paywallInfo, product),
      let .transactionComplete(paywallInfo, product),
      let .subscriptionStart(paywallInfo, product),
      let .freeTrialStart(paywallInfo, product),
      let .nonRecurringProductPurchase(paywallInfo, product):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: eventParams(forProduct: product, paywallInfo: paywallInfo),
        customParams: customParams
      )
    case let .paywallResponseLoadStart(fromEvent, eventData),
      let .paywallResponseLoadNotFound(fromEvent, eventData),
      let .paywallResponseLoadFail(fromEvent, eventData):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""],
        customParams: customParams
      )
    case let .paywallResponseLoadComplete(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadStart(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadFail(fromEvent, eventData, paywallInfo),
      let .paywallProductsLoadComplete(fromEvent, eventData, paywallInfo):
      let params = eventParams(
        forProduct: nil,
        paywallInfo: paywallInfo,
        otherParams: ["isTriggeredFromEvent": fromEvent, "eventName": eventData?.name ?? ""]
      )
      track(
        eventName: EventTypeConversion.name(for: event),
        params: params,
        customParams: customParams
      )
    case .triggerFire(let triggerInfo):
      track(
        eventName: EventTypeConversion.name(for: event),
        params: [
          "variant_id": triggerInfo.variantId as Any,
          "experiment_id": triggerInfo.experimentId as Any,
          "paywall_identifier": triggerInfo.paywallIdentifier as Any,
          "result": triggerInfo.result
        ]
      )
    default:
      track(eventName: EventTypeConversion.name(for: event))
    }
  }

  static func track(
    eventName: InternalEventName,
    params: [String: Any] = [:],
    customParams: [String: Any] = [:]
  ) {
    // force all events to have global params
    track(eventName.rawValue, params, customParams)
  }

  static func track(
    eventName: StandardEventName,
    params: [String: Any] = [:],
    customParams: [String: Any] = [:]
  ) {
    track(eventName.rawValue, params, customParams)
  }
}