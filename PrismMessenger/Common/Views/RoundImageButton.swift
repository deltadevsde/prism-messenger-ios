//
//  RoundImageButton.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct RoundImageButton: View {
    private let uiImage: UIImage?
    private let size: CGFloat
    private let action: () -> Void

    init(uiImage: UIImage?, size: CGFloat = 40, action: @escaping () -> Void) {
        self.uiImage = uiImage
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }
}
