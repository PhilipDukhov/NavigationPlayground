import UIKit
import SwiftUI

import Turbocharger

final class CustomUINavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    let isElevated: Bool
    var transitionStyle: NavigationTransitionStyle {
        didSet {
            let isSlide = transitionStyle == .slide
            interactivePopGestureRecognizer?.isEnabled = !isSlide
            leftEdgeSwipeRecognizer.isEnabled = isSlide
        }
    }
    let host: HostingController<AnyView>
    let state: NavigationState
    var customBackgroundColor: Color? { state.backgroundColor }

    /// We store this to see if we are in sync with the `state.isRootVisibleSeed`
    var isRootVisibleSeed: UInt = 0

    private let leftEdgeSwipeRecognizer = UIScreenEdgePanGestureRecognizer()
    private var interactiveTransition: UIPercentDrivenInteractiveTransition?

    var safeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            if oldValue != safeAreaInsets {
                additionalSafeAreaInsets = getAdditionalSafeAreaInsets(for: self, safeAreaInsets: safeAreaInsets)
            }
        }
    }

    override var childForStatusBarStyle: UIViewController? {
        // Don't use `visibleViewController` as that passes responsibility to the modally presented controller
        topViewController
    }

    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    /// Initializes the custom navigation controller with the specified parameters.
    /// - Parameters:
    ///   - state: The `NavigationState` which is passed as an environment variable in SwiftUI.
    ///   - isElevated: A boolean indicating whether the controller is elevated.
    ///   - transitionStyle: The style of transition to use.
    ///   - destination: The root SwiftUI view.
    init(state: NavigationState, isElevated: Bool, @ViewBuilder destination: () -> AnyView) {
        let host = HostingController(content: destination())
        self.state = state
        self.host = host
        self.transitionStyle = state.transitionStyle
        self.isElevated = isElevated
        super.init(rootViewController: host)

        leftEdgeSwipeRecognizer.addTarget(self, action: #selector(swipedLeftEdge(recognizer:)))
        leftEdgeSwipeRecognizer.delegate = self
        leftEdgeSwipeRecognizer.edges = .left
        view.addGestureRecognizer(leftEdgeSwipeRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let color = customBackgroundColor?.toUIColor() {
            view.backgroundColor = color
        } else {
            view.backgroundColor = nil
        }

        navigationBar.isHidden = true
        delegate = self
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        additionalSafeAreaInsets = getAdditionalSafeAreaInsets(for: self, safeAreaInsets: safeAreaInsets)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard !isTransitioning else {
            return
        }

        viewController.view.backgroundColor = customBackgroundColor?.toUIColor() ?? getScreenBackgroundColor(isTransparent: transitionStyle == .slide, isElevated: isElevated)

        super.pushViewController(viewController, animated: animated)
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        if navigationController.viewControllers.count > 1 {
            state.isRootVisible = false
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        state.isRootVisible = navigationController.viewControllers.count <= 1
    }

    // MARK: - Slide Transition Handling

    /// When the `navigationController(_:animationControllerFor:from:to:)` method is implemented in a `UINavigationControllerDelegate`, the default interactive pop gesture (swipe to go back) is disabled by the navigation controller, even if result is null. This occurs because the navigation controller's standard handling of the gesture is overridden by the custom animation logic.
    ///
    /// In our implementation, we re-enable and define custom behavior for the back gesture when our custom animator is used.
    ///
    /// However, when the default animation is needed (i.e., when our custom animator is not applicable), we preserve the navigation controller's default back gesture. This is achieved by effectively indicating that our custom animation method is not implemented in cases where the default behavior is preferred. As a result, the navigation controller falls back to its inherent handling of the interactive pop gesture.
    override func responds(to aSelector: Selector!) -> Bool {
        guard aSelector == #selector(Self.navigationController(_:animationControllerFor:from:to:)) else {
            return super.responds(to: aSelector)
        }
        return transitionStyle == .slide
    }

    /// Provide the custom animation for the slide transition.
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        guard transitionStyle == .slide else { return nil }
        return SlideAnimatedTransitioning(operation: operation)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        interactiveTransition
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if viewControllers.count > 1 {
            return true
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func swipedLeftEdge(recognizer: UIScreenEdgePanGestureRecognizer) {
        let progress = max(recognizer.translation(in: view).x / view.frame.size.width, 0)
        let velocity = recognizer.velocity(in: view)

        switch recognizer.state {
        case .began:
            interactiveTransition = UIPercentDrivenInteractiveTransition()
            popViewController(animated: true)
        case .changed:
            interactiveTransition?.update(progress)
        case .cancelled, .ended:
            let expectedFinalProgress = calculateExpectedProgress(currentProgress: progress, velocity: velocity)

            let completionThreshold: CGFloat = 0.5
            if expectedFinalProgress >= completionThreshold {
                interactiveTransition?.finish()
            } else {
                interactiveTransition?.cancel()
            }
            interactiveTransition = nil
        default:
            break
        }
    }

    private func calculateExpectedProgress(currentProgress: CGFloat, velocity: CGPoint) -> CGFloat {
        // Implement logic to calculate expected final progress based on velocity
        // This can be a simple heuristic or a more complex physics-based calculation
        // For example:
        let velocityThreshold: CGFloat = 1000 // Adjust this threshold as needed
        let additionalProgressDueToVelocity = velocity.x / velocityThreshold
        return min(max(currentProgress + additionalProgressDueToVelocity, 0), 1)
    }
}

func getScreenBackgroundColor(isTransparent: Bool, isElevated: Bool) -> UIColor {
    if isTransparent { return .clear }
    if isElevated {
        return .white
    }
    return .white
}
