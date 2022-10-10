//
//  EventHandler.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable line_length

import UIKit
import WebKit

protocol WebEventHandlerDelegate: AnyObject {
  var eventData: EventData? { get }
  var paywall: Paywall { get set }
  var paywallInfo: PaywallInfo { get }
  var webView: SWWebView { get }
  var loadingState: PaywallLoadingState { get set }
  var isPresentedViewController: Bool { get }

  func eventDidOccur(_ paywallPresentationResult: PaywallPresentationResult)
  func openDeepLink(_ url: URL)
  func presentSafariInApp(_ url: URL)
  func presentSafariExternal(_ url: URL)
}

@MainActor
final class WebEventHandler: WebEventDelegate {
  weak var delegate: WebEventHandlerDelegate?
  let queue = DispatchQueue(label: "templating")

  init(delegate: WebEventHandlerDelegate?) {
    self.delegate = delegate
  }

  func handleEvent(_ event: PaywallEvent) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Handle Event",
      info: ["event": event],
      error: nil
    )

    guard let paywall = delegate?.paywall else {
      return
    }

    switch event {
    case .templateParamsAndUserAttributes:
      templateParams(from: paywall)
    case .onReady(let paywalljsVersion):
      delegate?.paywall.paywalljsVersion = paywalljsVersion
      didLoadWebView(from: paywall)
    case .close:
      hapticFeedback()
      delegate?.eventDidOccur(.closed)
    case .openUrl(let url):
      openUrl(url)
    case .openUrlInSafari(let url):
      openUrlInSafari(url)
    case .openDeepLink(let url):
      openDeepLink(url)
    case .restore:
      restorePurchases()
    case .purchase(productId: let id):
      purchaseProduct(withId: id)
    case .custom(data: let customEvent):
      handleCustomEvent(customEvent)
    }
  }

  private func templateParams(from paywall: Paywall) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      let params = paywall.getBase64EventsString(
        params: self.delegate?.eventData?.parameters
      )

      let scriptSrc = """
      window.paywall.accept64('\(params)');
    """

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Posting Message",
        info: ["message": scriptSrc],
        error: nil
      )

      DispatchQueue.main.async {
        self.delegate?.webView.evaluateJavaScript(scriptSrc) { _, error in
          if let error = error {
            Logger.debug(
              logLevel: .error,
              scope: .paywallViewController,
              message: "Error Evaluating JS",
              info: ["message": scriptSrc],
              error: error
            )
          }
        }
      }
    }
  }

  private func didLoadWebView(from paywall: Paywall) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      if let paywallInfo = self.delegate?.paywallInfo {
        if paywall.webViewLoadCompleteTime == nil {
          self.delegate?.paywall.webViewLoadCompleteTime = Date()
        }

        let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
          state: .complete,
          paywallInfo: paywallInfo
        )
        Superwall.track(trackedEvent)

        SessionEventsManager.shared.triggerSession.trackWebviewLoad(
          forPaywallId: paywallInfo.id,
          state: .end
        )
      }

      let params = paywall.getBase64EventsString(
      params: self.delegate?.eventData?.parameters
    )
      let jsEvent = paywall.paywalljsEvent
      let scriptSrc = """
        window.paywall.accept64('\(params)');
        window.paywall.accept64('\(jsEvent)');
      """

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Posting Message",
        info: ["message": scriptSrc],
        error: nil
      )

      DispatchQueue.main.async {
        self.delegate?.webView.evaluateJavaScript(scriptSrc) { _, error in
          if let error = error {
            Logger.debug(
              logLevel: .error,
              scope: .paywallViewController,
              message: "Error Evaluating JS",
              info: ["message": scriptSrc],
              error: error
            )
          }
          self.delegate?.loadingState = .ready
        }

        // block selection
        let selectionString = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none} .w-webflow-badge { display: none !important; }'; "
        + "var head = document.head || document.getElementsByTagName('head')[0]; "
        + "var style = document.createElement('style'); style.type = 'text/css'; "
        + "style.appendChild(document.createTextNode(css)); head.appendChild(style); "

        let selectionScript = WKUserScript(
          source: selectionString,
          injectionTime: .atDocumentEnd,
          forMainFrameOnly: true
        )
        self.delegate?.webView.configuration.userContentController.addUserScript(selectionScript)

        let preventSelection = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none}'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);"
        self.delegate?.webView.evaluateJavaScript(preventSelection)

        let preventZoom: String = "var meta = document.createElement('meta');" + "meta.name = 'viewport';" + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
        self.delegate?.webView.evaluateJavaScript(preventZoom)
      }
    }
  }

  private func openUrl(_ url: URL) {
    detectHiddenPaywallEvent(
      "openUrl",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.eventDidOccur(.openedURL(url: url))
    delegate?.presentSafariInApp(url)
  }

  private func openUrlInSafari(_ url: URL) {
    detectHiddenPaywallEvent(
      "openUrlInSafari",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.eventDidOccur(.openedUrlInSafari(url))
    delegate?.presentSafariExternal(url)
  }

  private func openDeepLink(_ url: URL) {
    detectHiddenPaywallEvent(
      "openDeepLink",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.openDeepLink(url)
  }

  private func restorePurchases() {
    detectHiddenPaywallEvent("restore")
    hapticFeedback()
    delegate?.eventDidOccur(.initiateRestore)
  }

  private func purchaseProduct(withId id: String) {
    detectHiddenPaywallEvent("purchase")
    hapticFeedback()
    delegate?.eventDidOccur(.initiatePurchase(productId: id))
  }

  private func handleCustomEvent(_ customEvent: String) {
    detectHiddenPaywallEvent(
      "custom",
      userInfo: ["custom_event": customEvent]
    )
    delegate?.eventDidOccur(.custom(string: customEvent))
  }

  private func detectHiddenPaywallEvent(
    _ eventName: String,
    userInfo: [String: Any]? = nil
  ) {
    guard delegate?.isPresentedViewController == false else {
      return
    }
    let paywallDebugDescription = Superwall.shared.paywallViewController.debugDescription
    var info: [String: Any] = [
      "self": self,
      "Superwall.shared.paywallViewController": paywallDebugDescription,
      "event": eventName
    ]
    if let userInfo = userInfo {
      info = info.merging(userInfo)
    }
    Logger.debug(
      logLevel: .error,
      scope: .paywallViewController,
      message: "Received Event on Hidden Superwall",
      info: info
    )
  }

  private func hapticFeedback() {
    guard Superwall.options.paywalls.isHapticFeedbackEnabled else {
      return
    }
    if Superwall.options.isGameControllerEnabled {
      return
    }
    UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
  }
}
