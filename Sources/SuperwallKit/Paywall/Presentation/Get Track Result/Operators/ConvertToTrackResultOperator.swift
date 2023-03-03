//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/03/2023.
//

import Foundation
import Combine

extension AnyPublisher where Output == TriggerResult, Failure == Error {
  /// Checks whether the trigger result indicates that a paywall should show.
  func convertToTrackResult() -> AnyPublisher<TrackResult, Error> {
    map { input in
      return GetTrackResultLogic.convertTriggerResult(input)
    }
    .eraseToAnyPublisher()
  }
}
