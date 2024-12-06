import SwiftUI
import UIKit

import Turbocharger
import Transmission

/// This allows us to control the navigation - pop screens, push screens, pop to root, etc.
/// Every SwiftUI screen should have access to `NavigationState` via the `@Environment.`
final class NavigationState: NSObject, ObservableObject {
    @Published var isRootVisible: Bool = true

    /// We increment this to indicate that to `NavigationController` that we should pop to root.
    /// Note: we don't have to defend against overflow since `UInt` is huge.
    @Published var isRootVisibleSeed: UInt = 0
    @Published var scrollToTopSeed: UInt = 0

    var transitionStyle: NavigationTransitionStyle
    var backgroundColor: Color?
    var backgroundMaterial: Material?

    weak var navigationController: CustomUINavigationController?

    init(transitionStyle: NavigationTransitionStyle = .push, backgroundColor: Color? = nil, backgroundMaterial: Material? = nil) {
        self.transitionStyle = transitionStyle
        self.backgroundColor = backgroundColor
        self.backgroundMaterial = backgroundMaterial
    }

    /// Pushes a SwiftUI view onto the UIKit navigation stack.
    private func push<V: View>(@ViewBuilder view: () -> V) {
        let hostingController = DestinationHostingController(
            content: view()
                .modifier(NavigationScreenModifier(state: self, isDetail: true))
        )
        navigationController?.pushViewController(hostingController, animated: true)
    }

    func pushScreen<V: View>(
        transitionStyle: NavigationTransitionStyle = .push,
        isElevated: Bool = false,
        @ViewBuilder destination: () -> V
    ) {
        let backgroundColor = Color(getScreenBackgroundColor(isTransparent: transitionStyle == .slide, isElevated: isElevated))
        push {
            destination()
                .background(backgroundColor)
        }
    }

    /// Pops the top view controller from the navigation stack.
    func pop() {
        navigationController?.popViewController(animated: true)
    }

    /// Pops `count` screens from the stack. This is useful when we know that we have pushed a flow that is `count` screens long and we want to return to the root of the flow. For example, when you add a registration question you choose the type (screen 1) and then fill out the qeustion (screen 2). So we can pop both of those screens once you save the question.
    /// `pop(1)` is equivalent to `pop()`
    func pop(_ count: Int) {
        guard let navigationController,
              count > 0,
              count < navigationController.viewControllers.count else {
            return
        }

        let destinationIndex = navigationController.viewControllers.count - 1 - count
        let destinationViewController = navigationController.viewControllers[destinationIndex]
        navigationController.popToViewController(destinationViewController, animated: true)
    }

    /// This is used when you tap on a tab bar button. We take you back to the root and if you are already on the root, we'll scroll you to the top of the view.
    func popOrScrollToTop() {
        if !isRootVisible {
            isRootVisibleSeed += 1
        } else {
            scrollToTopSeed += 1
        }
    }

    /// This clears all of the stack and pushes the screen above the root view.
    ///
    /// This is useful when opening a screen from a notification. For example, when opening a chat message notification, we want to open the correct chat conversation but we don't want to push it on to the end of whatever is on the current chat tab stack.
    func resetAndPush<V: View>(animated: Bool = false, @ViewBuilder view: () -> V) {
        guard
            let navigationController = self.navigationController,
            let rootViewController = navigationController.viewControllers.first
        else {
            return
        }

        let hostingController = UIHostingController(
            rootView:
                view()
                    .modifier(NavigationScreenModifier(state: self, isDetail: true))
        )

        // Set the new stack to root + new controller
        navigationController.setViewControllers([rootViewController, hostingController], animated: animated)
    }
}

/// We use `UIKit` for managing navigation but we use `Transmission` so we are able to use declarative navigation like `NavigationContainerLink` and `.navigationContainerLink` in SwiftUI.
///
/// We don't use the native SwiftUI `NavigationStack` or `NavigationContainer` because:
///
/// 1. when we implemented this we wanted to be able to pop to root and that was hard at the time
/// 2. we want to be able to do custom navigation transitions like the Spotlight-style slide transition
///
/// The `NavigationContainer` will set the background of the pushed view controller by looking at `transitionStyle` and `isElevated`. In the future, we may want to allow the pushed view controller to manage it's own background.
struct NavigationContainer<Content: View>: UIViewControllerRepresentable {
    @StateObject var state: NavigationState = NavigationState()
    var content: Content
    var safeAreaInsets: EdgeInsets?

    @Environment(\.isElevated) var isElevated

    var transitionStyle: NavigationTransitionStyle { state.transitionStyle }

    init(state: NavigationState, @ViewBuilder content: () -> Content) {
        self._state = StateObject(wrappedValue: state)
        self.content = content()
    }

    init(
        transitionStyle: NavigationTransitionStyle = .push,
        backgroundColor: Color? = nil,
        backgroundMaterial: Material? = nil,
        safeAreaInsets: EdgeInsets? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._state = StateObject(wrappedValue: NavigationState(transitionStyle: transitionStyle, backgroundColor: backgroundColor, backgroundMaterial: backgroundMaterial))
        self.safeAreaInsets = safeAreaInsets
        self.content = content()
    }

    func makeUIViewController(context: Context) -> CustomUINavigationController {
        let navigationController = CustomUINavigationController(
            state: state,
            isElevated: context.environment.isElevated,
            destination: {
                AnyView(
                    content
                        .modifier(NavigationScreenModifier(state: state, isDetail: false))
                )
            }
        )

        state.navigationController = navigationController

        if let safeAreaInsets {
            navigationController.safeAreaInsets = UIEdgeInsets(safeAreaInsets, layoutDirection: .leftToRight)
        }

        return navigationController
    }

    func updateUIViewController(_ navigationController: CustomUINavigationController, context: Context) {
        navigationController.transitionStyle = transitionStyle
        if let safeAreaInsets {
            navigationController.safeAreaInsets = UIEdgeInsets(safeAreaInsets, layoutDirection: .leftToRight)
        }

        if state.isRootVisibleSeed != navigationController.isRootVisibleSeed {
            navigationController.isRootVisibleSeed = state.isRootVisibleSeed
            navigationController.isTransitioning = true
            navigationController.navigationController?.isTransitioning = true
            navigationController.popToRootViewController(animated: true)
            withCATransaction {
                navigationController.isTransitioning = false
                navigationController.navigationController?.isTransitioning = false
            }
        }
    }
}

fileprivate struct NavigationScreenModifier: ViewModifier {
    @Environment(\.isElevated) var isElevated

    var state: NavigationState
    var isDetail: Bool

    func body(content: Content) -> some View {
        content
            .ifLet(state.backgroundColor, transform: { view, color in view.background(color) })
            .ifLet(state.backgroundMaterial, transform: { view, material in view.background(material) })
            .environment(\.isDetail, isDetail)
            .environment(\.transitionStyle, state.transitionStyle)
            .environment(\.navigationState, state)
    }
}
