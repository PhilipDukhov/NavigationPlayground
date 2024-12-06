import SwiftUI

func getAdditionalSafeAreaInsets(
    for viewController: UIViewController,
    safeAreaInsets: UIEdgeInsets
) -> UIEdgeInsets {
    guard let base = (viewController.parent?.view.safeAreaInsets ?? viewController.view.window?.safeAreaInsets)
    else {
        return .zero
    }
    var insets = safeAreaInsets
    insets.top = max(0, insets.top - base.top)
    insets.left = max(0, insets.left - base.left)
    insets.bottom = max(0, insets.bottom - base.bottom)
    insets.right = max(0, insets.right - base.right)
    return insets
}

extension UIEdgeInsets {
    init(_ edgeInsets: EdgeInsets, layoutDirection: LayoutDirection) {
        self = UIEdgeInsets(
            top: edgeInsets.top,
            left: layoutDirection == .leftToRight ? edgeInsets.leading : edgeInsets.trailing,
            bottom: edgeInsets.bottom,
            right: layoutDirection == .leftToRight ? edgeInsets.trailing : edgeInsets.leading
        )
    }
}

struct IsElevatedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// This is `true` if the view is displayed as a sheet or other elevated presentation style. In dark mode, we use a lighter background for elevated views to indicate that they are closer to a light source.
    var isElevated: Bool {
        get { self[IsElevatedKey.self] }
        set { self[IsElevatedKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<T: View, F: View>(
        _ condition: Bool,
        transform trueTransform: (Self) -> T,
        else elseTransform: (Self) -> F
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            elseTransform(self)
        }
    }

    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

private struct IsDetailKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// This is `true` for non-root view on the `NavigationContainer`. This indicates the view can navigate _back_ to the root view.
    var isDetail: Bool {
        get { self[IsDetailKey.self] }
        set { self[IsDetailKey.self] = newValue }
    }
}
