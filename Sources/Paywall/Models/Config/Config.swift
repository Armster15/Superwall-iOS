//
//  Config.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Config: Decodable {
  var triggers: Set<Trigger>
  var paywallResponses: [PaywallResponse]
  var logLevel: Int
  var postback: PostbackRequest
  var locales: Set<String>
  var appSessionTimeout: Milliseconds
  var featureFlags: FeatureFlags
  var preloadingDisabled: PreloadingDisabled

  enum CodingKeys: String, CodingKey {
    case triggers = "triggerOptions"
    case paywallResponses
    case logLevel
    case postback
    case localization
    case appSessionTimeout = "appSessionTimeoutMs"
    case featureFlags = "toggles"
    case preloadingDisabled = "disablePreload"
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    triggers = try values.decode(Set<Trigger>.self, forKey: .triggers)
    paywallResponses = try values.decode([PaywallResponse].self, forKey: .paywallResponses)
    logLevel = try values.decode(Int.self, forKey: .logLevel)
    postback = try values.decode(PostbackRequest.self, forKey: .postback)
    appSessionTimeout = try values.decode(Milliseconds.self, forKey: .appSessionTimeout)
    featureFlags = try FeatureFlags(from: decoder)
    preloadingDisabled = try values.decode(PreloadingDisabled.self, forKey: .preloadingDisabled)

    let localization = try values.decode(LocalizationConfig.self, forKey: .localization)
    locales = Set(localization.locales.map { $0.locale })
  }

  init(
    triggers: Set<Trigger>,
    paywallResponses: [PaywallResponse],
    logLevel: Int,
    postback: PostbackRequest,
    locales: Set<String>,
    appSessionTimeout: Milliseconds,
    featureFlags: FeatureFlags,
    preloadingDisabled: PreloadingDisabled
  ) {
    self.triggers = triggers
    self.paywallResponses = paywallResponses
    self.logLevel = logLevel
    self.postback = postback
    self.locales = locales
    self.appSessionTimeout = appSessionTimeout
    self.featureFlags = featureFlags
    self.preloadingDisabled = preloadingDisabled
  }
}

// MARK: - Stubbable
extension Config: Stubbable {
  static func stub() -> Config {
    return Config(
      triggers: [.stub()],
      paywallResponses: [.stub()],
      logLevel: 0,
      postback: .stub(),
      locales: [],
      appSessionTimeout: 3600000,
      featureFlags: .stub(),
      preloadingDisabled: .stub()
    )
  }
}
