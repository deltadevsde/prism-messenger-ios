//
//  ScenePhaseRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

// Repository that only stores the current ScenePhase
class ScenePhaseRepository: ObservableObject {

    @Published var currentPhase: ScenePhase = .inactive

}
