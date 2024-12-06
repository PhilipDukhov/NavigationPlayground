import UIKit

final class SlideAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    private let operation: UINavigationController.Operation
    private var animator: UIViewPropertyAnimator?

    init(operation: UINavigationController.Operation) {
        self.operation = operation
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.35
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        setupAnimator(for: transitionContext)
            .startAnimation()
    }

    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        setupAnimator(for: transitionContext)
    }

    private func setupAnimator(for transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let animator {
            return animator
        }
        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            timingParameters: UISpringTimingParameters()
        )

        guard
            let from = transitionContext.viewController(forKey: .from),
            let to = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            animator.stopAnimation(false)
            return animator
        }

        let width = transitionContext.containerView.frame.width

        to.view.frame.origin.x = width * (operation == .push ? 1 : -1)
        from.view.frame = transitionContext.initialFrame(for: from)

        transitionContext.containerView.addSubview(to.view)

        animator.addAnimations { [operation] in
            to.view.frame = transitionContext.finalFrame(for: to)
            from.view.frame.origin.x = width * (operation == .push ? -1 : 1)
        }
        animator.addCompletion { position in
            let canceled = transitionContext.transitionWasCancelled || position != .end
            if canceled {
                to.view.removeFromSuperview()

                /// After canceling the back navigation gesture in a `UINavigationController`, the current view becomes unresponsive to touch inputs.
                /// This issue seems specific to views managed by SwiftUI, as it does not occur with `UIHostingController` instances that are manually added.
                /// As a workaround, removing the view from its superview and then re-adding it restores touch responsiveness.
                from.view.removeFromSuperview()
                transitionContext.containerView.addSubview(from.view)
            }
            transitionContext.completeTransition(!canceled)
        }
        self.animator = animator

        return animator
    }
}
