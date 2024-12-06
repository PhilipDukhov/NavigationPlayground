import SwiftUI

struct NavigationContainerLink<Destination: View, Label: View>: View {
    var destination: () -> Destination
    var label: Label

    @Environment(\.transitionStyle) private var transitionStyle
    @Environment(\.isElevated) private var isElevated
    @Environment(\.navigationState) var navigationState: NavigationState?

    init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
    }

    var body: some View {
        Button {
            navigationState?.pushScreen(
                transitionStyle: transitionStyle,
                isElevated: isElevated,
                destination: destination
            )
        } label: {
            label
                .contentShape(Rectangle())
        }
    }
}

extension View {
    /// The `.navigationContainerLink` allows pushing but *does not allow popping* of a view. If you set `isActive` to `true` and then set it to `false`, the view will be pushed, but it will not be popped. Additionally the view will only be rendered once, at the time of the push. If you want to pass in live date, you should likely pass in an `ObservableObject` like a view model.
    @ViewBuilder
    func navigationContainerLink<Destination: View>(
        isActive: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        modifier(NavigationContainerLinkModifier(
            isActive: isActive,
            destination: destination
        ))
    }

    func navigationContainerLink<Destination: View, Item>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        navigationContainerLink(isActive: item.isNotNil()) {
            if let item = item.wrappedValue {
                destination(item)
            }
        }
    }
}

private struct NavigationContainerLinkModifier<Destination: View>: ViewModifier {
    @Binding var isActive: Bool
    @ViewBuilder let destination: () -> Destination

    @Environment(\.transitionStyle) private var transitionStyle
    @Environment(\.isElevated) private var isElevated
    @Environment(\.navigationState) var navigationState: NavigationState?

    private var backgroundColor: Color {
        Color(getScreenBackgroundColor(isTransparent: transitionStyle == .slide, isElevated: isElevated))
    }

    func pushDestination() {
        navigationState?.pushScreen(
            transitionStyle: transitionStyle,
            isElevated: isElevated,
            destination: destination
        )
        isActive = false
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { newValue in
                if newValue {
                    pushDestination()
                }
            }
            .onAppear {
                if isActive {
                    pushDestination()
                }
            }
    }
}
