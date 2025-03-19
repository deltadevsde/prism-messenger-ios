//
//  LoadingView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading prism...")
                .padding(.top)
        }
    }
}

#Preview {
    LoadingView()
}
