import SwiftUI

enum NavigationTransitionStyle: Equatable, Hashable {
    /// Standard, most common iOS transition.
    case push
    /// Spotlight-style transition. Useful for when the background doesn't have content because during a slide transition the new view does not overlap with the previous view.
    case slide
}

/// This is the style of transition in the `NavigationContainer`.
struct TransitionStyleKey: EnvironmentKey {
    static let defaultValue: NavigationTransitionStyle = .push
}

extension EnvironmentValues {
    var transitionStyle: NavigationTransitionStyle {
        get { self[TransitionStyleKey.self] }
        set { self[TransitionStyleKey.self] = newValue }
    }
}

/// This environment key, specific to this file, aids the `DestinationLink` in determining the background color of the controller.
struct NavigationStateKey: EnvironmentKey {
    static let defaultValue: NavigationState? = nil
}

extension EnvironmentValues {
    var navigationState: NavigationState? {
        get { self[NavigationStateKey.self] }
        set { self[NavigationStateKey.self] = newValue }
    }
}

extension UINavigationController {
    static var isTransitioningKey: UInt = 0
    var isTransitioning: Bool {
        get {
            let value = objc_getAssociatedObject(self, &UINavigationController.isTransitioningKey) as? NSNumber
            return value?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self, &UINavigationController.isTransitioningKey, NSNumber(booleanLiteral: newValue), .OBJC_ASSOCIATION_COPY)
        }
    }
}
