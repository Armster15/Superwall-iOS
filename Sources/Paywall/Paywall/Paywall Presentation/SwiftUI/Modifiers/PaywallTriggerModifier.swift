//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
struct PaywallTriggerModifier: ViewModifier {
  @Binding var shouldPresent: Bool
  @State private var manuallySetShouldPresent = false
  var event: String?
  var params: [String: Any]?
  var onPresent: ((PaywallInfo?) -> Void)?
  var onDismiss: ((PaywallDismissalResult) -> Void)?
  var onFail: ((NSError) -> Void)?

  func body(content: Content) -> some View {
    content
      .valueChanged(
        value: shouldPresent,
        onChange: updatePresentation
      )
  }

  private func updatePresentation(_ shouldPresent: Bool) {
    // TODO: What happens when they try to trigger but it doesn't like it
    if shouldPresent {
      var eventData: EventData?

      if let name = event {
        eventData = Paywall.track(name, [:], params ?? [:], handleTrigger: false)
      }

      Paywall.internallyPresent(
        fromEvent: eventData,
        onPresent: onPresent,
        onDismiss: { result in
          self.manuallySetShouldPresent = true
          self.shouldPresent = false
          onDismiss?(result)
        },
        onFail: { error in
          self.manuallySetShouldPresent = true
          self.shouldPresent = false
          onFail?(error)
        }
      )
    } else {
      // This prevents Paywall.dismiss() being called twice when manually setting shouldPresent.
      if manuallySetShouldPresent {
        manuallySetShouldPresent = false
        return
      }
      Paywall.dismiss()
    }
  }
}
