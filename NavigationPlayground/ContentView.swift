//
//  ContentView.swift
//  NavigationPlayground
//
//  Created by Phil Dukhov on 6/12/24.
//

import SwiftUI
import Transmission

class VM: ObservableObject {
    @Published var items = [1,2,3]
}

struct ContentView: View {
    var body: some View {
        NavigationContainer {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject var vm = VM()
    @State var flag = false

    var body: some View {
        VStack {
            ForEach(vm.items, id: \.self) {
                Text($0.description)
            }
            DestinationLink {
                ItemsList(items: $vm.items)
            } label: {
                Text("Transmission push")
            }
            NavigationContainerLink {
                ItemsList(items: $vm.items)
            } label: {
                Text("Luma push")
            }
        }
    }
}

struct ItemsList: View {
    @Binding var items: [Int]

    var body: some View {
        VStack {
            ForEach(items, id: \.self) {
                Text($0.description)
            }
            Button("reverse") {
                items = items.reversed()
            }
        }
    }
}
