//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/07/2022.
//

import Foundation

enum ExpressionEvaluatorLogic {
  static func shouldFire(
    basedOn occurrence: TriggerRuleOccurrence?,
    ruleMatched: Bool,
    storage: Storage
  ) -> Bool {
    if ruleMatched {
      guard let occurrence = occurrence else {
        return true
      }
      let count = storage
        .coreDataManager
        .countTriggerRuleOccurrences(
          for: occurrence
        ) + 1
      print("*** counted", count, "maxCount", occurrence.maxCount, "Returning: \(count < occurrence.maxCount)")
      storage.coreDataManager.save(triggerRuleOccurrence: occurrence)

      return count <= occurrence.maxCount
    }
    if let occurrence = occurrence  {
      storage.coreDataManager.save(triggerRuleOccurrence: occurrence)
    }
    return false
  }
}
