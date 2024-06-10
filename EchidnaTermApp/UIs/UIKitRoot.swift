//
//  UIKitRoot.swift: UIKit APIs to deal with root windows, and root view controllers
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/9/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// getCurrentKeyWindow: returns the current key window from the application
@MainActor
func getCurrentKeyWindow () -> UIWindow? {
    func tryGetWindow (desiredState: UIScene.ActivationState) -> UIWindow? {
        return UIApplication.shared.connectedScenes
              .filter { $0.activationState == desiredState }
              .compactMap { $0 as? UIWindowScene }
              .first?.windows
              .filter { $0.isKeyWindow }
              .first
    }
    let states: [UIScene.ActivationState] = [.foregroundActive, .foregroundInactive, .background, .unattached]
    for x in states {
        if let window = tryGetWindow(desiredState: x) {
            return window
        }
    }
    return nil
}

@MainActor
func getParentViewController (hint: UIResponder? = nil) -> UIViewController? {
    var parentResponder = hint
    while parentResponder != nil {
        parentResponder = parentResponder?.next
        if let viewController = parentResponder as? UIViewController {
            return viewController
        }
    }
    
    // playing with fire here
    return getCurrentKeyWindow()?.rootViewController
}



