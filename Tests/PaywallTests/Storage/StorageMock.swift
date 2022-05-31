//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import Foundation
@testable import Paywall

final class StorageMock: Storage {
  var internalCachedTriggerSessions: [TriggerSession]
  var internalCachedTransactions: [TransactionModel]
  var didClearCachedSessionEvents = false

  init(
    internalCachedTriggerSessions: [TriggerSession] = [],
    internalCachedTransactions: [TransactionModel] = [],
    configRequestId: String = "abc"
  ) {
    self.internalCachedTriggerSessions = internalCachedTriggerSessions
    self.internalCachedTransactions = internalCachedTransactions
    super.init()
    self.configRequestId = configRequestId
  }

  override func getCachedTriggerSessions() -> [TriggerSession] {
    return internalCachedTriggerSessions
  }

  override func getCachedTransactions() -> [TransactionModel] {
    return internalCachedTransactions
  }

  override func clearCachedSessionEvents() {
    didClearCachedSessionEvents = true
  }
}
