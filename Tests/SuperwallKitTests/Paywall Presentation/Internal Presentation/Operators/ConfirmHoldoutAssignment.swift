//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class ConfirmHoldoutAssignmentOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_confirmHoldoutAssignment_notHoldout() async {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let configManager = ConfigManagerMock(
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )
    let request = PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        configManager: configManager,
        storage: dependencyContainer.storage,
        sessionEventsManager: dependencyContainer.sessionEventsManager,
        paywallManager: dependencyContainer.paywallManager,
        storeKitManager: dependencyContainer.storeKitManager,
        network: dependencyContainer.network,
        debugManager: dependencyContainer.debugManager,
        identityManager: dependencyContainer.identityManager,
        deviceHelper: dependencyContainer.deviceHelper,
        isDebuggerLaunched: false,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )
    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmHoldoutAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          pipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [pipelineExpectation], timeout: 0.1)
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  func test_confirmHoldoutAssignment_holdout_noConfirmableAssignments() async {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let configManager = ConfigManagerMock(
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )
    let request = PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        configManager: configManager,
        storage: dependencyContainer.storage,
        sessionEventsManager: dependencyContainer.sessionEventsManager,
        paywallManager: dependencyContainer.paywallManager,
        storeKitManager: dependencyContainer.storeKitManager,
        network: dependencyContainer.network,
        debugManager: dependencyContainer.debugManager,
        identityManager: dependencyContainer.identityManager,
        deviceHelper: dependencyContainer.deviceHelper,
        isDebuggerLaunched: false,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )
    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      confirmableAssignment: nil,
      debugInfo: [:]
    )

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmHoldoutAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          pipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [pipelineExpectation], timeout: 0.1)
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  func test_confirmHoldoutAssignment_holdout_hasConfirmableAssignments() async {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let configManager = ConfigManagerMock(
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )
    let request = PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        configManager: configManager,
        storage: dependencyContainer.storage,
        sessionEventsManager: dependencyContainer.sessionEventsManager,
        paywallManager: dependencyContainer.paywallManager,
        storeKitManager: dependencyContainer.storeKitManager,
        network: dependencyContainer.network,
        debugManager: dependencyContainer.debugManager,
        identityManager: dependencyContainer.identityManager,
        deviceHelper: dependencyContainer.deviceHelper,
        isDebuggerLaunched: false,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )
    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      confirmableAssignment: .init(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: "")),
      debugInfo: [:]
    )

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmHoldoutAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          pipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [pipelineExpectation], timeout: 0.1)
    XCTAssertTrue(configManager.confirmedAssignment)
  }
}